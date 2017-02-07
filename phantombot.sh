#!/bin/sh

# Editable zone

TWITCH_CID="" # Generate your own client id at: https://www.twitch.tv/kraken/oauth2/clients/new

# Do Not Edit at this line
PBA_DIR=$(dirname $(realpath ${0}))
COMMAND=${1}
ARGUMENT=${2}
INSTANCES=${PBA_DIR}/instances
if INST_LIST=`find ${INSTANCES}/* -maxdepth 0 -type d 2>/dev/null` || [ ! -z ${INST_LIST} ]; then
  cnt=0
  for INSTANCED in `${INST_LIST} | xargs -n1 basename 2>/dev/null | tr "\n" " "`; do
    INSTANCE_LIST[$((cnt++))]=${INSTANCED}
  done
fi
CORE=${PBA_DIR}/.core
SKEL=${PBA_DIR}/.skel
TEMP=${PBA_DIR}/.temp
BACKUP=${PBA_DIR}/backups

GITHUB="https://api.github.com/repos/phantombot/phantombot/releases/latest"
TWITCH="https://api.twitch.tv/kraken"

# skip download licence http://stackoverflow.com/questions/10268583/downloading-java-jdk-on-linux-via-wget-is-shown-license-page-instead
JAVA_PACKAGE_NAME="jre-8u121-linux-x64"
JAVA_DEB_PACKAGE="oracle-java8-jre_8u121_amd64.deb"
JAVA_DOWNLOAD="http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/${JAVA_PACKAGE_NAME}"

PKG() {
  if [ -f /etc/os-release ] ; then
    yum -q $@
  elif [ -f /etc/lsb-release ] ; then
    apt-get -qq $@
  fi
}

PKG_UPDATE() {
  if [ -f /etc/os-release ] ; then
    PKG -y update
  elif [ -f /etc/lsb-release ] ; then
    PKG update
    PKG -y upgrade
  fi
}

APP_INSTALL() {
  if ! app="$(type -p "${1}")" || [ -z "${app}" ]; then
    echo -ne "installing \033[38;5;12m${app} \033[0m"
    PKG install -y ${1}
    if [$? -ne 0]; then
      EXCEPTION=1
      echo -e "[ \033[38;5;9mERROR\033[0m ]"
    else
      echo -e "[ \033[38;5;10mDONE\033[0m ]"
    fi
  else
    echo -e "\033[38;5;12m${app} \033[0mhas been detected. There is not necessary installing him."
  fi
}

if [ ! -f ${CORE}/latest/PhantomBot.jar ] && [ "${COMMAND}" = "init" ]; then
  cd ${PBA_DIR}
  USEROWN=`stat -c "%U" ${PBA_DIR}/phantombot.sh`
  USERGRP=`stat -c "%G" ${PBA_DIR}/phantombot.sh`
  
  EXCEPTION=0

  if [ "$(whoami)" = "root" ]; then
    echo "Checking for installed dependencies:"
    # installing jq and curl
    for app in "jq" "curl"; do
      APP_INSTALL ${app}
    done
    
    # Installing Java Runtime Enviorment    
    if ! app="$(type -p "java")" || [ -z "${app}" ]; then
      echo -e "Prepare to install \033[38;5;11mJava Runtime Enviorment\033[0m"
      TEMPDIR=$(mkdtemp /tmp/pba.XXXXXXXXXX)
      if [ -f /etc/os-release ]; then
        # RedHat Distro
        echo -e "Detected OS: \033[38;5;12m$(cat /etc/os-release)\033[0m"
        curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${JAVA_DOWNLOAD}.rpm 2>/dev/null > ${TEMPDIR}/${JAVA_PACKAGE_NAME}.rpm
        echo -ne "Installing \033[38;5;12mJRE \033[0m"
        PKG localinstall -y ${TEMPDIR}/${JAVA_PACKAGE_NAME}.rpm
        if [$? -ne 0]; then
          EXCEPTION=1
          echo -e "[ \033[38;5;9mERROR\033[0m ]"
        else
          echo -e "[ \033[38;5;10mDONE\033[0m ]"
        fi
      elif [ -f /etc/lsb-release ]; then
        # Debian Distro
        DISTRO=$(echo `lsb_release -i` | cut -d ':' -f2 | cut -d ' ' -f2)
        VERSION=$(echo `lsb_release -r` | cut -d ':' -f2 | cut -d ' ' -f2)
        echo -e "Detected OS: \033[38;5;12m${DISTRO} ${VERSION}\033[0m"
        if [[ ${DISTRO} -eq "Debian" ]]; then
          if compare_version ${VERSION} 8.0; then
            echo "deb http://httpredir.debian.org/debian/ jessie main contrib" >> /etc/apt/sources.list
            PKG_UPDATE && PKG install -y java-package fakeroot
          elif compare_version ${VERSION} 7.0; then
            PKG install -t wheezy-backports -y java-package fakeroot
          fi
        elif [[ ${DISTRO} -eq "Ubuntu" ]]; then
          if compare_version ${VERSION} 12.04; then
            PKG install -t precise-backports -y java-package fakeroot
          elif compare_version ${VERSION} 14.04 || compare_version ${VERSION} 16.04; then
            PKG install -y java-package fakeroot
          else
            PKG install -y python-software-properties
            add-apt-repository -y ppa:webupd8team/java
          fi
        else
          echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" >> /etc/apt/sources.list.d/webupd8team-java.list
          echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" >> /etc/apt/sources.list.d/webupd8team-java.list
          apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
        fi

        if [ app="$(type -p "make-jpkg")" || [ ! -z "${app}" ]] && [ app="$(type -p "fakeroot")" || [ ! -z "${app}" ]]; then
          curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" ${JAVA_DOWNLOAD}.tar.gz 2>/dev/null > ${TEMPDIR}/${JAVA_PACKAGE_NAME}.tar.gz
          su - ${USEROWN} -c "fakeroot make-jpkg ${TEMPDIR}/${JAVA_PACKAGE_NAME}.tar.gz"
          echo -ne "Installing \033[38;5;12mJRE \033[0m"
          dpkg -i $(find ${TEMPDIR} -name '*.deb') &>/dev/null
          if [$? -ne 0]; then
            EXCEPTION=1
            echo -e "[ \033[38;5;9mERROR\033[0m ]"
          else
            echo -e "[ \033[38;5;10mDONE\033[0m ]"
          fi
        fi

        if ! app="$(type -p "java")" || [ -z "${app}" ]; then
          echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | /usr/bin/debconf-set-selections
          PKG_UPDATE
          echo -ne "Installing \033[38;5;12mJRE \033[0m"
          PKG install -y oracle-java8-installer oracle-java8-set-default
          if [$? -ne 0]; then
            EXCEPTION=1
            echo -e "[ \033[38;5;9mERROR\033[0m ]"
          else
            echo -e "[ \033[38;5;10mDONE\033[0m ]"
          fi
        fi
      fi  
    fi
    if [ EXCEPTION -eq 1 ];then
      echo -e "Instalation [ \033[38;5;9mFailed \033[0m]"
      echo "Check exceptions of the install"
      exit 1
    fi

    current_version=$(curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2)

    echo "Initializing default directories"

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

    sleep 1s
    echo "Installing PhantomBot Automation"
      
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
else
  echo "You don't neeed instalation. Right? Cause you have all."
  exit 0
fi

current_version=$(curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2)
local_version=$(unzip -q -c ${CORE}/latest/PhantomBot.jar 2>/dev/null | grep 'Implementation-Version' | cut -d ':' -f2 | cut -d ' ' -f2)

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
  echo $(curl -H "Accept: application/vnd.twitchtv.v5+json" -H "Client-ID: ${TWITCH_CID}" ${TWITCH}/search/channels?query=${1} 2>/dev/null | jq -r '.channels[0].display_name')
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

read_init_port(){
  read -p "Port [${1}]: " -i ${1} data
  echo data
}

read_init(){
  if [[ ! -z ${2} && ${2} -eq "yes" ]]; then
    read -rep "Please, do not leave this empty. ${1}" data
    sleep 1s
  else
    read -p "${1}" data
  fi
  if [ -z ${data} ]; then
    read_init "${1}" "yes"
  else
    echo data
  fi
}

initialize() {
  DISPLAY=$(getDisplayName ${1})
  
  echo "!!!Very important!!!"
  echo "Do not skip some configurations or bot wouldn't worked"
  read -p "Press ENTER to continue"
  
  echo "Reciving configuration"
  port=`read_init_port 25000`
  botname=$(getDisplayName `read_init "Bot name: "`)
  botauth=`read_init "Bot authkey (with oauth:) (log in to http://www.twitchapps.com/tmi/ as bot account): "`
  userauth=`read_init "User authkey (with oauth:) (log in to https://phantombot.tv/oauth/ as streamer): "`
  password=$(date +%s | sha256sum | base64 | head -c 12 ; echo)
  
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
    echo "Adding process as User"
    if [ ! -d $HOME/.config/systemd/user ]; then
      mkdir -p $HOME/.config/systemd/user
    fi
    PROCESS=$HOME/.config/systemd/user/phantombot@${1}.service
  else
    echo "Adding process as Root"
    PROCESS=/etc/systemd/user/phantombot@${1}.service
  fi
  
  if [[ ${2} == "delete" ]]; then
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

instance_set() {
  read -p "Please write Twitch Username. Not a link: " ARGUMENT
  if [ -z ${ARGUMENT} ]; then
    echo "I need Twitch Username to continue. Try again."
    instance_set
  fi
}

run() {
  DISPLAY=$(getDisplayName ${1})
  systemctl --user start phantombot@${DISPLAY}
}

shutdown() {
  DISPLAY=$(getDisplayName ${1})
  systemctl --user stop phantombot@${DISPLAY}
}

reload() {
  DISPLAY=$(getDisplayName ${1})
  shutdown ${DISPLAY}
  run ${DISPLAY}
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
    if [ -z ${ARGUMENT} ]; then
      instance_set
    fi
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
    reinitialize ${ARGUMENT}
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
