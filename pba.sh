#!/bin/bash 

source .env
PROC=$1
INSTANCE_GLOBAL=$2
if [ $PROC != install ]; then
	if [ $(find $INSTANCES -maxdepth 0 -type d -name "*" -print 2>/dev/null | wc -l) > 0 ]; then
		INSTANCE_LIST=(`find $INSTANCES/* -maxdepth 0 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null`)
	fi

	if [ -z $INSTANCE_LIST ] ; then
		echo "There is no instances here."
		echo "Write: \"$0 install\" to install somethign instance"
		exit 0
	fi
fi
get_instance(){
	if [[ -z $INSTANCE_GLOBAL && $PROC != "install" && ! -z $PROC && $PROC != "help" ]]; then
		echo "To continue interaction please make your choice"
		for (( i=0; i < ${#INSTANCE_LIST[@]}; i++ )); do
			if [ $i == 0 ]; then
				echo "[$((i + 1))] ${INSTANCE_LIST[$i]} *"			
			else
				echo "[$((i + 1))] ${INSTANCE_LIST[$i]}"
			fi		
		done		
		read -e -p "Pick your choice [Default: 1]: " -i "1" j
		INSTANCE_GLOBAL=${INSTANCE_LIST[$((j - 1))]}
	fi
}

user_exists(){
	if [ `curl -so /dev/null -H "Accept: application/vnd.twitchtv.v3+json" -H "Client-ID: ${TWITCH_Client_ID}" -w "%{http_code}\n" ${TWITCH_Url}/chat/$1` == 404 ]; then
		return 1
	else
		return 0
	fi
}

get_display_name() {
	INSTANCE=$1
	Twitch_Display=$(curl -H "Accept: application/vnd.twitchtv.v3+json" -H "Client-ID: ${TWITCH_Client_ID}" ${TWITCH_Url}/channels/${INSTANCE} 2>/dev/null | jq -r '.display_name')
	echo ${Twitch_Display}
}

install(){
	INSTANCE=$(get_display_name $1)

	echo "!!!Very important!!!"
	echo "Do not skip some configurations or bot wouldn't worked"
	read -p "Press ENTER to continue"

	echo "Reciving configuration"
	read -p "Port [25000]: " -i 25000 port
	read -p "Bot name: " botname
	read -p "Bot authkey (with oauth:) (log in to http://www.twitchapps.com/tmi/ as bot account): "  botauth
	read -p "User authkey (with oauth:) (log in to https://phantombot.tv/oauth/ as streamer): " userauth
	INSTANCE_PWD=$(date +%s | sha256sum | base64 | head -c 12 ; echo)
	botname=$(curl -H "Accept: application/vnd.twitchtv.v3+json" -H "Client-ID: ${TWITCH_Client_ID}" ${TWITCH_Url}/channels/${botname} 2>/dev/null | jq -r '.display_name')

	mkdir $INSTANCES/$INSTANCE
		
	cp -rf $SKEL/latest/* $INSTANCES/$INSTANCE
	
	http_port=`[ ! -z $port ] && echo $((port + 5)) || echo $((25000 + 5))`
	port=`[ ! -z $port ] && echo ${port} || echo 25000`
	
	touch $INSTANCES/$INSTANCE/botlogin.txt
	echo "baseport=${port}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "user=${botname}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "oauth=${botauth}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "channel=${INSTANCE}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "owner=${INSTANCE}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "apioauth=${userauth}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "paneluser=${INSTANCE}" >> $INSTANCES/$INSTANCE/botlogin.txt
	echo "panelpassword=${INSTANCE_PWD}" >> $INSTANCES/$INSTANCE/botlogin.txt
	
	cd ${INSTANCES}/${INSTANCE} && \
	`which pm2` start java \
	--name "PhantomBot@${INSTANCE}" \
	--error "${INSTANCES}/${INSTANCE}/stacktrace.txt" \
	--cron "0 5 * * *" \
	--kill-timeout 15000 \
	--write \
	-- -Dfile.encoding=UTF-8 -jar PhantomBot.jar
	`which pm2` stop PhantomBot@${INSTANCE}
	cd ${PBA_DIR}
	
	echo "User added."
	echo "Log in to http://$(hostname --fqdn):${http_port}/ as:"
	echo "Username: $INSTANCE"
	echo "Password: $INSTANCE_PWD"
	
	echo "Log in to http://$(hostname --fqdn):${http_port}/ as:" >> $INSTANCES/$INSTANCE.txt
	echo "Username: $INSTANCE" >> $INSTANCES/$INSTANCE.txt
	echo "Password: $INSTANCE_PWD" >> $INSTANCES/$INSTANCE.txt
	
	exit 0
}

fix_pm2(){
	INSTANCE=$(get_display_name $1)
	if [ -z $INSTANCE ]; then
		echo "Type instance first"
		exit 1
	fi
	
	echo $botname, $INSTANCE
	`which pm2` describe PhantomBot@${INSTANCE} > /dev/null
	RUNNING=$?
	if [ ${RUNNING} == 0 ]; then
		`which pm2` delete PhantomBot@${INSTANCE}
	fi
	cd ${INSTANCES}/${INSTANCE} && \
	`which pm2` start java \
	--name "PhantomBot@${INSTANCE}" \
	--error "${INSTANCES}/${INSTANCE}/stacktrace.txt" \
	--cron "0 5 * * *" \
	--kill-timeout 15000 \
	--write \
	-- -Dfile.encoding=UTF-8 -jar PhantomBot.jar
	`which pm2` stop PhantomBot@${INSTANCE}
	cd ${PBA_DIR}
}

uninstall(){
	INSTANCE=$(get_display_name $1)
	if [ -d $INSTANCES/$INSTANCE ]; then
		read -p "Are you sure, do you wanna removing this instance [$INSTANCE] [Yes*/No]:" -i "Yes" bool
		case $bool in
			y|yes|Y|Yes|YES|*)
				`which pm2` stop PhantomBot@${INSTANCE}
				rm -rf $INSTANCES/$INSTANCE
				`which pm2` delete PhantomBot@${INSTANCE}
				echo "The instance [$INSTANCE] has been removed BibleThump"
				;;
			n|N|No|NO|no)
				echo "Operation aboted! Maybe next time. WutFace"
				exit 0
				;;
		esac
	else
		echo "This instance doesn't exists [$INSTANCE]"
		exit 0
	fi
}

get_instance

case $PROC in
	install)
		if [ -z $INSTANCE_GLOBAL ]; then
			read -p "Please write Twitch.tv Username: " INSTANCE_GLOBAL
		fi
		
		if [ ! -z $INSTANCE_GLOBAL ] && [ ! $(user_exists $INSTANCE_GLOBAL) ]; then
			install $INSTANCE_GLOBAL
		else
			$0 install
		fi
		;;
	uninstall)
		uninstall $INSTANCE_GLOBAL
		;;
	reload)
		fix_pm2 $INSTANCE_GLOBAL
		;;
	help|*)
		echo "Usage $0 (install|uninstall|reload|help)"
		;;
esac
