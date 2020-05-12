#!/bin/bash
## Compile if needed and upload the script to the TARGET
##

TARGET=$1
SCRIPT=$2
USERNAME=$3
UPLOAD_LOCATION=/etc/ppp/ip-up.d/$SCRIPT

echo "Uploading $SCRIPT to $TARGET:$UPLOAD_LOCATION as $USERNAME"
scp $SCRIPT $USERNAME@$TARGET:~

#Change permissions on that file
ssh $USERNAME@$TARGET "sudo chmod +x $UPLOAD_LOCATION"; 

#Run it once
ssh $USERNAME@$TARGET "echo $UPLOAD_LOCATION"; 