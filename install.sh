#!/bin/bash  

# enviorments
source .env
# script

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
version=`curl ${PB_GITHUB} 2>/dev/null | jq -r '.tag_name' | cut -d 'v' -f2`
mkdir $CORE/$version
url=`curl ${PB_GITHUB} 2>/dev/null | jq -r '.assets[0].browser_download_url'`
fname=${url##*/}
name="PhantomBot-$version"
curl -o $TEMP/$fname -L $url 2>/dev/null
unzip -qq $TEMP/$fname -d $TEMP
rsync -q -av --progress $TEMP/${name}/* --exclude=*.sh --exclude=*.bat $CORE/$version
rm -rf $TEMP/${name}
ln -s $CORE/$version $CORE/latest

if [ ! -d $SKEL ]; then
	mkdir $SKEL
fi
mkdir $SKEL/$version
rsync -q -av --progress $CORE/$version/* --exclude=lib/ --exclude=*.jar --exclude=*.sh --exclude=*.bat $SKEL/$version
ln -s $CORE/$version/lib $SKEL/$version
ln -s $CORE/$version/PhantomBot.jar $SKEL/$version/PhantomBot.jar
ln -s $SKEL/$version $SKEL/latest

echo -ne "\\r"
echo -e "INSTALLATION \033[0;32m COMPLETE \033[0m"
rm $0
