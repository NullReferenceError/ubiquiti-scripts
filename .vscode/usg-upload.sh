#!/bin/bash
## Compile if needed and upload the script to the TARGET
##

TARGET=$1
SCRIPT=$2
USERNAME=$3
UPLOAD_LOCATION=/etc/ppp/ip-up.d/$SCRIPT
CFG_SCRIPT_D_LOCATION=/config/scripts/post-config.d/$SCRIPT

echo "Uploading $SCRIPT to $TARGET:$UPLOAD_LOCATION as $USERNAME"
scp $SCRIPT $USERNAME@$TARGET:$UPLOAD_LOCATION

#Change permissions on that file
ssh $USERNAME@$TARGET "sudo chmod +x $UPLOAD_LOCATION"; 

#Also copy it into script post-config.d
ssh $USERNAME@$TARGET "sudo cp $UPLOAD_LOCATION $CFG_SCRIPT_D_LOCATION"; 

#Run it once
ssh $USERNAME@$TARGET "sh $UPLOAD_LOCATION"; 