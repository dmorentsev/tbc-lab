#!/bin/bash

LOG_FILE="/home/ec2-user/check_instances.log"
PRIMARY_INSTANCE_ID="i-08dead363e7f180ff"
SECONDARY_INSTANCE_ID="i-01821f5f17a7b4cf2"
ALLOCATION_ID="eipalloc-06098b6a09f2968c5"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Check if the primary instance is running
log "Checking the state of the primary instance: $PRIMARY_INSTANCE_ID"
PRIMARY_STATE=$(aws ec2 describe-instances --instance-id $PRIMARY_INSTANCE_ID --query "Reservations[0].Instances[0].State.Name" --output text)

# Function to get the current instance associated with the Elastic IP
get_current_instance_associated() {
    aws ec2 describe-addresses --allocation-ids $ALLOCATION_ID --query "Addresses[0].InstanceId" --output text
}

# Get the current instance associated with the Elastic IP
CURRENT_INSTANCE_ID=$(get_current_instance_associated)

if [ "$PRIMARY_STATE" != "running" ]; then
    if [ "$CURRENT_INSTANCE_ID" != "$SECONDARY_INSTANCE_ID" ]; then
        log "Primary instance is not running (state: $PRIMARY_STATE). Reassociating Elastic IP to the secondary instance: $SECONDARY_INSTANCE_ID"
        # Reassociate Elastic IP to the secondary instance
        ASSOCIATION_OUTPUT=$(aws ec2 associate-address --instance-id $SECONDARY_INSTANCE_ID --allocation-id $ALLOCATION_ID 2>&1)
        if [ $? -eq 0 ]; then
            log "Successfully reassociated Elastic IP ($ALLOCATION_ID) to secondary instance ($SECONDARY_INSTANCE_ID)."
        else
            log "Failed to reassign Elastic IP: $ASSOCIATION_OUTPUT"
        fi
    else
        log "Elastic IP is already associated with the secondary instance ($SECONDARY_INSTANCE_ID). No action needed."
    fi
else
    if [ "$CURRENT_INSTANCE_ID" != "$PRIMARY_INSTANCE_ID" ]; then
        log "Primary instance is running (state: $PRIMARY_STATE). Reassociating Elastic IP back to the primary instance: $PRIMARY_INSTANCE_ID"
        # Reassociate Elastic IP to the primary instance
        ASSOCIATION_OUTPUT=$(aws ec2 associate-address --instance-id $PRIMARY_INSTANCE_ID --allocation-id $ALLOCATION_ID 2>&1)
        if [ $? -eq 0 ]; then
            log "Successfully reassociated Elastic IP ($ALLOCATION_ID) to primary instance ($PRIMARY_INSTANCE_ID)."
        else
            log "Failed to reassign Elastic IP: $ASSOCIATION_OUTPUT"
        fi
    else
        log "Elastic IP is already associated with the primary instance ($PRIMARY_INSTANCE_ID). No action needed."
    fi
fi
