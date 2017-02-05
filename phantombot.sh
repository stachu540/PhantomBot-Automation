#!/bin/sh
TWITCH_CID="" # Generate your own client id at: https://www.twitch.tv/kraken/oauth2/clients/new

# Do Not Edit at this line
PBA_DIR=$(dirname $(realpath ${0}))
COMMAND=${1}
ARGUMENT=${2}
INSTANCES=${PBA_DIR}/instances
INSTANCE_LIST=(`find ${INSTANCES}/* -maxdepth 0 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null | tr "\n" " "`)
CORE=${PBA_DIR}/.core
SKEL=${PBA_DIR}/.skel
TEMP=${PBA_DIR}/.temp
BACKUP=${PBA_DIR}/backups
GITHUB="https://api.github.com/repos/phantombot/phantombot/releases/latest"
TWITCH="https://api.twitch.tv/kraken"
JAVA_PACKAGE_NAME="jre-8u121-linux-x64"
JAVA_DEB_PACKAGE="oracle-java8-jre_8u121_amd64.deb"
JAVA_DOWNLOAD="http://download.oracle.com/otn-pub/java/jdk/8u121-b13/${JAVA_PACKAGE_NAME}"

if [[ -z ${TWITCH_CID} || ${TWITCH_CID} -eq "" ]]; then
    echo "Please edit this file before you continue."
    exit 0
fi

if [[ ! -e ${CORE}/latest/PhantomBot.jar && ${COMMAND} -eq "init" ]]; then
  core
else
  current_version=$(curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2)
  local_version=$(unzip -q -c ${CORE}/latest/PhantomBot.jar 2>/dev/null | grep 'Implementation-Version' | cut -d ':' -f2 | cut -d ' ' -f2)
fi

PKG_INSTALL() {
  if [ -f /etc/os-release ] ; then
    yum install -y $@
  elif [ -f /etc/lsb-release ] ; then
    apt-get install -y $@
  fi
}

core() {
  USEROWN=`stat -c "%U" ${PBA_DIR}/phantombot`
  USERGRP=`stat -c "%G" ${PBA_DIR}/phantombot`

  if [ ! -d $TEMP ]; then
    mkdir $TEMP
  fi

  if [ ! -d $BACKUP ]; then
    mkdir $BACKUP
  fi

  if [ ! -d $INSTANCES ]; then
    mkdir $INSTANCES
  fi

  if [ ! -d $CORE ]; then
    mkdir $CORE
  fi

  if [ ${UID} -eq 0 ]; then
    if [ ! -e $(which jq) ]; then
      PKG_INSTALL jq
    fi

    if [ ! -e $(which curl) ]; then
      PKG_INSTALL curl
    fi

    if [ ! -e $(which java) ]; then
      if [ -f /etc/os-release ]; then
        curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${JAVA_DOWNLOAD}.rpm > ${TEMP}/${JAVA_PACKAGE_NAME}.rpm
        cd ${TEMP} 
        yum localinstall -y ${JAVA_PACKAGE_NAME}.rpm
      elif [ -f /etc/lsb-release ]; then
        DISTRO=$(echo `lsb_release -i` | cut -d ':' -f2 | cut -d ' ' -f2)
        VERSION=$(echo `lsb_release -r` | cut -d ':' -f2 | cut -d ' ' -f2)
        if [[ ${DISTRO} -eq "Debian" ]]; then
          echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | tee /etc/apt/sources.list.d/webupd8team-java.list
          echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list
          apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
          apt-get update
          echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
          PKG_INSTALL oracle-java8-installer oracle-java8-set-default
        elif  [[ ${DISTRO} -eq "Ubuntu" ]]; then
          if compare_version VERSION 13.10; then
            PKG_INSTALL software-properties-common
          else
            PKG_INSTALL python-software-properties
          fi
          add-apt-repository -y ppa:webupd8team/java
          apt-get update
          echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
          PKG_INSTALL oracle-java8-installer oracle-java8-set-default
        else
          # Using for other Debian's distribution https://wiki.debian.org/JavaPackage
          echo "deb http://httpredir.debian.org/debian/ jessie main contrib" > /etc/apt/sources.list.d/debian-contrib.list
          apt-get update && apt-get install -y java-package
          apt-get install -y libgl1-mesa-glx libfontconfig1 libxslt1.1 libxtst6 libxxf86vm1 libgtk2.0-0
          curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${JAVA_DOWNLOAD}.tar.gz > ${TEMP}/${JAVA_PACKAGE_NAME}.tar.gz
          cd ${TEMP}
          make-jpkg ${JAVA_PACKAGE_NAME}.tar.gz
          dpkg -i ${JAVA_DEB_PACKAGE}
          update-alternatives --auto java
        fi
      fi
    fi
    current_version=$(curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2)
    
    mkdir ${TEMP}/${current_version}
    url=`curl ${GITHUB} 2>/dev/null | jq -r '.assets[0].browser_download_url'`
    curl -o ${TEMP}/PhantomBot.zip -L $url 2>/dev/null
    unzip -qq ${TEMP}/PhantomBot.zip -d ${TEMP}/${current_version}
    mv ${TEMP}/${current_version} ${CORE}
    rm ${CORE}/latest
    ln -s ${CORE}/${current_version} ${CORE}/latest

    if [ ! -d ${SKEL} ]; then
      mkdir ${SKEL}
    fi
    mkdir ${SKEL}/${current_version}
    rsync -q -av --progress ${CORE}/${current_version}/* --exclude=lib/ --exclude=*.jar --exclude=*.sh --exclude=*.bat ${SKEL}/${current_version}
    ln -s ${CORE}/${current_version}/lib ${SKEL}/${current_version}
    ln -s ${CORE}/${current_version}/PhantomBot.jar ${SKEL}/${current_version}/PhantomBot.jar
    if [ -L ${SKEL}/latest ]; then
      rm ${SKEL}/latest
    fi
    ln -s ${SKEL}/${current_version} ${SKEL}/latest
    chown -R ${USEROWN}:${USERGRP} ${PBA_DIR}
    echo -ne "\\r"
    echo -e "INSTALLATION \033[0;32m COMPLETE \033[0m"
    exit 0
  else
    echo "Instalation cannot be continue."
    echo "Try running again as Root."
    exit 1
  fi
}

compare_version() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

version_check() {
  if compare_version ${current_version} ${local_version}; then
    echo "There is a newer version of PhantomBot!!!"
    echo "New Version: ${current_version}"
    echo "Current Version: ${local_version}"
    echo "Please write \"${0} update\" to updating all instances"
  fi
}

instance_pick() {
  echo "Choose instance to continue your action"
  for(( i = 0; i < ${#INSTANCE_LIST[@]}; i++ )); do
    if [ $i == 0 ]; then
      echo "[$((i + 1))] ${INSTANCE_LIST[$i]} *"			
    else
      echo "[$((i + 1))] ${INSTANCE_LIST[$i]}"
    fi
  done
  read -e -p "Pick your choice [Default: 1]: " -i "1" j
  ARGUMENT=${INSTANCE_LIST[$((j - 1))]}
}

getDisplayName() {
  echo $(curl -h "Accept: application/vnd.twitchtv.v5+json" -H "Client-ID: ${TWITCH_CID}" ${TWITCH}/search/channels?query=${1} 2>/dev/null | jq -r '.channels[0].display_name')
}

instance_update() {
  DISPLAY=$(getDisplayName ${1})

  if [ -d ${TEMP}/${DISPLAY} ]; then
    rm -rf ${TEMP}/${DISPLAY}
  fi

  mkdir ${TEMP}/${DISPLAY}
  cp -rf ${INSTANCES}/${DISPLAY}/{botlogin.txt,phantombot.db,logs} ${TEMP}/${DISPLAY}
  rm -rf ${INSTANCES}/${DISPLAY}/*
  cp -rf ${SKEL}/latest/* ${INSTANCES}/${DISPLAY}
  cp -rf ${TEMP}/${DISPLAY}/* ${INSTANCES}/${DISPLAY}
}

update() {
  if [ ! -z ${1} ]; then
    if [ ${1} -eq "all"]; then
      ALL=1
    fi
  fi

  if [[ -d ${CORE}/${current_version} && ${current_version} == ${local_version} ]]; then
    echo "There is no need to updating"
    exit 0
  fi
  mkdir ${TEMP}/${current_version}
  url=`curl ${GITHUB} 2>/dev/null | jq -r '.assets[0].browser_download_url'`
  curl -o ${TEMP}/PhantomBot.zip -L $url 2>/dev/null
  unzip -qq ${TEMP}/PhantomBot.zip -d ${TEMP}/${current_version}
  mv ${TEMP}/${current_version} ${CORE}
  rm ${CORE}/latest
  ln -s ${CORE}/${current_version} ${CORE}/latest

  if [ ! -d ${SKEL} ]; then
    mkdir ${SKEL}
  fi
  mkdir ${SKEL}/${current_version}
  rsync -q -av --progress ${CORE}/${current_version}/* --exclude=lib/ --exclude=*.jar --exclude=*.sh --exclude=*.bat ${SKEL}/${current_version}
  ln -s ${CORE}/${current_version}/lib ${SKEL}/${current_version}
  ln -s ${CORE}/${current_version}/PhantomBot.jar ${SKEL}/${current_version}/PhantomBot.jar
  if [ -L ${SKEL}/latest ]; then
    rm ${SKEL}/latest
  fi
  ln -s ${SKEL}/${current_version} ${SKEL}/latest

  if [ ALL -eq 1 ]; then
    for INST in ${INSTANCE_LIST[@]}; do
      instance_update ${INST}
    done
  fi
}

backup() {
  if [ -z ${1} ]; then
    cd ${PBA_DIR}

    date=`date +%d-%m-%y`
    if [ ! -d ${BACKUP} ]; then
      mkdir ${BACKUP}
    fi

    for INST in ${INSTANCE_LIST[@]}; do
      backup ${INST}
    done
  else
    DISPLAY=$(getDisplayName ${1})
    if [ ! -d ${BACKUP}/${DISPLAY} ]; then
      mkdir ${BACKUP}/${DISPLAY}
    else
      find ${BACKUP}/${DISPLAY}/ -maxdepth 1 -mtime 90 -type d -exec rm -rv {} \;
    fi

    if [ ! -d ${BACKUP}/${DISPLAY}/${date} ]; then
      mkdir ${BACKUP}/${DISPLAY}/${date}
    fi

    cp -r ${INSTANCES}/${DISPLAY}/{botlogin.txt,phantombot.db,logs} ${BACKUP}/${DISPLAY}/${date}/
    rm ${BACKUP}/${DISPLAY}/${date}.zip
    cd ${BACKUP}/${DISPLAY}/${date}
    zip -r -q ${BACKUP}/${DISPLAY}/${date}.zip *
    cd ${BACKUP}
    rm -rf ${BACKUP}/${DISPLAY}/${date}
    echo "Instance from @${DISPLAY} [ DONE ]"
  fi

}

restore() {
  INST=$(getDisplayName ${1})
  day=${2}
  if [[ -z ${day} || ${day} -eq "" ]]; then
    echo "Write backup date"
    read -e -p "Write backup date [Default: Today]: " -i "Today" day
  fi
  date=$(date -d ${day} +%d-%m-%y)
  if [ ! -e ${BACKUP}/${INST}/${date}.zip ]; then
    echo "Backup for ${date} is not exists."
    echo "Getting backup day after"
    date=$(date -d 'Day after ${date}' +%d-%m-%y)
    restore ${INST} ${date}
  else
    echo "Backup exists: ${date}. Proceeding to restore."
  fi
  echo "WARNING!!! This process ovewritting backuping files."
  read -p "Do you wanna continue? [Yes/No]:" -i "Yes" bool
  case ${bool} in
  y|Y|yes|Yes|YES|*)
    unzip -o -qq ${BACKUP}/${INST}/${date}.zip -d ${INSTANCES}/${INST}/*
    echo "Backup restoration complete!"
    exit 0
    ;;
  n|N|no|No|NO)
    echo "Aborting...+"
    exit 0
    ;;
  esac
}

initialize() {
  DISPLAY=$(getDisplayName ${1})

  echo "!!!Very important!!!"
  echo "Do not skip some configurations or bot wouldn't worked"
  read -p "Press ENTER to continue"

  echo "Reciving configuration"
  read -p "Port [25000]: " -i 25000 port
  read -p "Bot name: " botname
  if [ -z ${botname} || ${botname} == "" ]; then
    echo "Please dont leave this empty"
    read -p "Bot name: " botname
  fi
  read -p "Bot authkey (with oauth:) (log in to http://www.twitchapps.com/tmi/ as bot account): " botauth
  if [ -z ${botauth} || ${botauth} == "" ]; then
    echo "Please dont leave this empty"
  read -p "Bot authkey (with oauth:) (log in to http://www.twitchapps.com/tmi/ as bot account): " botauth
  fi
  read -p "User authkey (with oauth:) (log in to https://phantombot.tv/oauth/ as streamer): " userauth
  if [ -z ${userauth} || ${userauth} == "" ]; then
    echo "Please dont leave this empty"
  read -p "User authkey (with oauth:) (log in to https://phantombot.tv/oauth/ as streamer): " userauth
  fi
  password=$(date +%s | sha256sum | base64 | head -c 12 ; echo)

  botname=$(getDisplayName ${botname})
  if [ ! -d ${INSTANCES}/${DISPLAY} ]; then
    mkdir ${INSTANCES}/${DISPLAY}
  fi
  cp -rf ${SKEL}/latest/* ${INSTANCES}/${DISPLAY}

  http_port=`[ ! -z $port ] && echo $((port + 5)) || echo $((25000 + 5))`
  port=`[ ! -z $port ] && echo ${port} || echo 25000`
  cat > ${INSTANCES}/${DISPLAY}/botlogin.txt <<EOT
baseport=${port}
user=${botname}
oauth=${botauth}
channel=${DISPLAY}
owner=${DISPLAY}
apioauth=${userauth}
paneluser=${DISPLAY}
panelpassword=${password}
EOT

  process_init ${DISPLAY}

  cat > ${INSTANCES}/${DISPLAY}.txt <<EOT
Log in to http://$(hostname --fqdn):${http_port}/ as:
Username: ${INSTANCE}
Password: ${password}
EOT

  echo "User has been added."
  cat ${INSTANCES}/${DISPLAY}.txt
}

reinitialize() {
  process_init $(getDisplayName $1)
}

process_init() {
  if [ $UID -ne 0 ]; then
    if [ -d $HOME/.config/systemd/user ]; then
      mkdir -p $HOME/.config/systemd/user
    fi
    PROCESS = $HOME/.config/systemd/user/phantombot@${1}.service
  else
    PROCESS = /etc/systemd/user/phantombot@${1}.service
  fi

  if [ $2 -eq "delete" ]; then
    rm ${PROCESS}
  else
    cat > ${PROCESS} <<EOT 
[Unit]
Description=PhantomBot for ${1}
After=network.target

[Service]
WorkingDirectory=${INSTANCES}/${1}
User=stachu
Group=stachu
ExecStart=/usr/bin/java -Dfile.encoding=UTF-8 -jar ${INSTANCES}/${1}/PhantomBot.jar &
TimeoutSec=300
RestartSec=15
Restart=always
 
[Install]
WantedBy=multi-user.target

EOT
  fi
}

delete() {
  DISPLAY=$(getDisplayName ${1})
  if [ -d ${INSTANCES}/${DISPLAY} ]; then
    read -p "Are you sure, do you wanna removing this instance? [${DISPLAY}] [Yes/No]:" -i "Yes" bool
    case ${bool} in
      y|Y|yes|Yes|YES|*)
        systemctl --user stop phantombot@${DISPLAY}
        process_init ${DISPLAY} delete
        rm -rf ${INSTANCES}/${DISPLAY}
        rm ${INSTANCES}/${DISPLAY}.txt
        if [ ! -z ${2} && ${2} -eq "with-backups"]; then
          rm -rf ${BACKUPS}/${DISPLAY}
        fi
        echo "The instance [${DISPLAY}] has been removed BibleThump"
        exit 0
        ;;
      n|N|no|No|NO)
        echo "Operation aboted! Maybe next time. WutFace"
        exit 0
        ;;
      esac
  else
    echo "This instance dosen't exists [${DISPLAY}]"
    exit 0;
  fi
}


if [[ ${COMMAND} -ne "install" ]]; then
  if [ -z ${INSTANCE_LIST} ] ; then
    echo "There is no instances here."
    echo "Write: \"${0} install\" to install somethign instance"
    exit 0
  elif [[ -z ${ARGUMENT} && -z ${COMMAND} && ${COMMAND} -ne "help" && ${COMMAND} -ne "install" && ${COMMAND} -ne "update" ]]; then
    instance_pick
  fi
fi

case ${COMMAND} in
  install)
    initialize ${ARGUMENT}
    ;;
  uninstall)
    delete ${ARGUMENT} ${3}
    ;;
  update)
    if [ -z ${ARGUMENT} ]; then
      update
    else
      if [ ${ARGUMENT} -eq "all" ]; then
        update ${ARGUMENT}
      else
        instance_update ${ARGUMENT}
      fi
    fi
    ;;
  reload)
    reinitalize ${ARGUMENT}
    ;;
  start)
    run ${ARGUMENT}
    ;;
  stop)
    shutdown ${ARGUMENT}
    ;;
  restart) 
    reload ${ARGUMENT}
    ;;
  backup)
    backup ${ARGUMENT}
    ;;
  restore)
    restore ${ARGUMENT}
    ;;
  help|*)
    echo "Usage: ${0} [install|uninstall|update|reload|help|start|stop|backup|restore]"
    ;;
esac
