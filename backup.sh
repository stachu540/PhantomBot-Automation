#!/bin/bash 

date=`date +%d-%m-%y`

filelist=("botlogin.txt" "phantombot.db" "logs/")

if [ $(find $INSTANCES -maxdepth 0 -type d -name "*" -print 2>/dev/null | wc -l) > 0 ]; then
	INSTANCE_LIST=(`find $INSTANCES/* -maxdepth 0 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null`)
else 
	echo "There is no instances here."
	exit 1
fi

if [ ! -d $BACKUP ]; then
	mkdir $BACKUP
fi

for INSTANCE in $INSTANCE_LIST; do
	
	find $BACKUP/$INSTANCE/ -maxdepth 1 -mtime 30 -type d -exec rm -rv {} \;

	if [ ! -d $BACKUP/$INSTANCE ]; then
		mkdir $BACKUP/$INSTANCE
	fi
	if [ ! -d $BACKUP/$INSTANCE/$date ]; then
		mkdir $BACKUP/$INSTANCE/$date
	fi
	cp -r $COMMON_PATH/$INSTANCE_NAME/{botlogin.txt,phantombot.db,logs} $BACKUP_DIR/$INSTANCE_NAME/$date/
	zip -rq $BACKUP_DIR/$INSTANCE_NAME/${date}.zip $BACKUP_DIR/$INSTANCE_NAME/$date/*
	rm -rf $BACKUP_DIR/$INSTANCE_NAME/$date
	
done

