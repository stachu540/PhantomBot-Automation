#!/bin/bash 

source .env

version=$(curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2)

local=$(readlink -f $CORE/latest | xargs -n1 basename)
echo "Local version: ${local}"
echo "Current Version: ${version}"
sleep 1s
if [[ -d $CORE/$version && ${local} == ${version} ]]; then
	echo "There is no need to update"
	exit 0
fi
mkdir $CORE/$version
url=`curl ${PB_GITHUB} 2>/dev/null | jq -r '.assets[0].browser_download_url'`
fname=${url##*/}
name="PhantomBot-$version"
curl -o $TEMP/$fname -L $url 2>/dev/null
unzip -qq $TEMP/$fname -d $TEMP
mv $TEMP/${name}/* $CORE/$version
rm $CORE/latest
ln -s $CORE/$version $CORE/latest

if [ ! -d $SKEL ]; then
	mkdir $SKEL
fi
mkdir $SKEL/$version
rsync -q -av --progress $CORE/$version/* --exclude=lib/ --exclude=*.jar --exclude=*.sh --exclude=*.bat $SKEL/$version
ln -s $CORE/$version/lib $SKEL/$version
ln -s $CORE/$version/PhantomBot.jar $SKEL/$version/PhantomBot.jar
rm $SKEL/latest
ln -s $SKEL/$version $SKEL/latest

for INSTANCE in INSTANCE_LIST; do
	`which pm2` stop $INSTANCE
	cp $INSTANCES/$INSTANCE/{botlogin.txt,logs} $TEMP/$INSTANCE
	storage=`egrep -lir --include=botlogin.txt "(datastore)" | cut -d '=' -f2`
	if [ -z $storage ] || [ $storage == "sqlite" ]; then
		cp $INSTANCES/$INSTANCE/phantombot.db $TEMP/$INSTANCE/phantombot.db
	fi
	rm -rf $INSTANCES/$INSTANCE/*
	cp $SKEL/latest/* $INSTANCES/$INSTANCE
	mv $TEMP/$INSTANCE/* $INSTANCES/$INSTANCE
	rm -rf $TEMP/$INSTANCE
	`which pm2` start $INSTANCE
done
