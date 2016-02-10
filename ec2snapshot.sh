#!/bin/bash
#
# Amazon EC2 Instance Snapshot Script
# http://www.allette.com.au
# Copyright (c) 2016 Allette Systems, Australia
#
# More details can be found at the Amazon EC2 Developer site
# http://aws.amazon.com/documentation/ec2/
#=====================================================================
#
#=====================================================================
# Change Log
#=====================================================================
# VER 1.0 - (2012-01-01)
#   Initial Release
# VER 1.1 - (2012-01-02)
#   Fix Cron Bugs
# VER 1.2 - (2012-01-03)
#   Add Email Function
# VER 1.3 - (2012-01-07)
#   Add Multiple Amazon Account Support
# VER 1.4 - (2012-11-05)
#   Add Region support
# VER 1.5 - (2013-02-14)
#   Add Volume Include support
# VER 1.6 - (2015-11-27)
#   Change Volume Include source to a tag:value pair, removed volume exclude support.
# VER 2.0 - (2015-12-02)
#   Move properties to global.properties file, all in one script for all backup intervals.
#   Snapshots to keep now counted per instance, taking into account multiple volumes.
# VER 2.1 - (2016-02-10)
#   Minor spelling corrections, move environment variable path definitions to global.properties.

# Current version of this script
VER=2.1

# Set working folder to script directory
script=$(readlink -f "$0")
scriptPath=$(dirname "$script")
cd $scriptPath

# Read properties file
if [ -f "./config/global.properties" ]
  then
    . ./config/global.properties
  else
    echo "$scriptPath/config/global.properties file not found! Exiting."
    exit 1
fi


# Check for interval argument
if [ "$1" = "-q" ]; then
    interval="Quarter-hourly"
    accounts="$qhourlyAccounts"
    logFile="$qhourlyLogFile"
    logErr="$qhourlyLogErr" 
elif [ "$1" = "-h" ]; then
    interval="Hourly"
    accounts="$hourlyAccounts"
    logFile="$hourlyLogFile"
    logErr="$hourlyLogErr"
elif [ "$1" = "-d" ]; then
    interval="Daily"
    accounts="$dailyAccounts"
    logFile="$dailyLogFile"
    logErr="$dailyLogErr"
elif [ "$1" = "-m" ]; then
    interval="Monthly"
    accounts="$monthlyAccounts"
    logFile="$monthlyLogFile"
    logErr="$monthlyLogErr"
elif [ -z "$1"]; then
    echo "You must specify a switch for the desired interval: -q, -h, -d, -m."
    exit 1
fi

# System wide variables
export EC2_HOME=$EC2_HOME
export JAVA_HOME=$JAVA_HOME
export PATH=$PATH:$EC2_HOME/bin


# IO redirection for logging.
if [ ! -d "./logs" ]; then
  mkdir ./logs
fi
touch $logFile
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > $logFile     # stdout replaced with file $logFile.
touch $logErr
exec 7>&2           # Link file descriptor #7 with stderr.
                    # Saves stderr.
exec 2> $logErr     # stderr replaced with file $logErr.
        

# Print details
echo ======================================================================
echo Auto Amazon EC2 Snapshots Backup ver. $VER
echo http://www.allette.com.au
echo
echo The script will initiate Amazon snapshots for volumes attached to
echo tagged instances. The actual snapshot process is run by Amazon EC2.
echo To verify the snapshot process, login to the Amazon EC2 Console.
echo
echo ======================================================================
echo
echo $interval Backup Start Time `date`
echo ======================================================================

# Loop through all Amazon accounts (tags)
for ac in $accounts
do

        # Parse account/region strings
        OLDIFS=$IFS
        IFS=';'; read -ra AC <<< "$ac"
        IFS=$OLDIFS
        
        echo
        echo Processing Amazon Account: ${AC[0]} for Region: ${AC[1]}
        echo --------------------------------------------------------------
        counter=0

        # Read and set parameters for account and selected interval
        . $scriptPath/config/${AC[0]}/${AC[0]}.properties

        if [ "$interval" = "Quarter-hourly" ]; then
            backupTag="$qhourlyBackupTag"
            tagValue="$hourlyTagValue"
            snapshotsKept="$qhourlySnapshotsKept"
            description="$qhourlyDescription"
        elif [ "$interval" = "Hourly" ]; then
            backupTag="$hourlyBackupTag"
            tagValue="$hourlyTagValue"
            snapshotsKept="$hourlySnapshotsKept"
            description="$hourlyDescription"
        elif [ "$interval" = "Daily" ]; then
            backupTag="$dailyBackupTag"
            tagValue="$dailyTagValue"
            snapshotsKept="$dailySnapshotsKept"
            description="$dailyDescription"
        elif [ "$interval" = "Monthly" ]; then
            backupTag="$monthlyBackupTag"
            tagValue="$monthlyTagValue"
            snapshotsKept="$monthlySnapshotsKept"
            description="$monthlyDescription"
        fi

        export AWS_ACCESS_KEY=$AWS_ACCESS_KEY
        export AWS_SECRET_KEY=$AWS_SECRET_KEY
        export EC2_URL=https://ec2.${AC[1]}.amazonaws.com
        
        # Get list of volumes attached to instances with the specified tag
        VOLINCLUDE=($(ec2-describe-instances --filter "tag:$backupTag=$tagValue" | grep "BLOCKDEVICE" | cut -f3))

        # Get list of all volumes
        for s in $(ec2-describe-volumes | grep "VOLUME" | cut -f2 | sort -u);
        do
                # I was too lazy to rewrite this function, so it checks again
                if [[ $VOLINCLUDE == *$s* ]]
                then
                  for ((i=0; i<${#VOLINCLUDE[@]}; i++)) do
                    echo Initiating snapshot for volume: ${VOLINCLUDE[i]} ;
                    ec2-create-snapshot ${VOLINCLUDE[i]} -d $description
                    counter=`expr $counter + 1`
                  done                  
            	else
                        echo "$s is excluded!";
                fi
        done;
        echo $counter Snapshots initiated for $ac Amazon Servers.
        echo
        echo Cleaning up old snapshots...
        # Count the volumes attached to instances with the specified tag (allows for instances with multiple volumes)
        countVolumes=$(ec2-describe-instances --filter "tag:backup.daily=yes" | grep "BLOCKDEVICE" | cut -f3 | wc -l)
        # Calculates the number of snapshots to remove to maintain the number of snapshots kept per instance
        snapshotsToRemove=$(($snapshotsKept * $countVolumes))
        ec2-describe-snapshots | sort -r -k 5 | grep "$description" | sed 1,"$snapshotsToRemove"d | awk '{print "Deleting snapshot: " $2}; system("ec2-delete-snapshot " $2)'
        echo Clean up done.
done

echo
echo $interval Backup End `date`
echo ======================================================================

#Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 1>&7 7>&-      # Restore stdout and close file descriptor #7.

if   [ "$mailContent" = "log" ]
then
        cat "$logFile" | mail -s "Amazon EC2 Snapshot $interval Backup Log - $dateFormat" $mailAddress
        if [ -s "$logErr" ]
                then
                        cat "$logErr" | mail -s "ERRORS REPORTED: Amazon EC2 Snapshot $interval Backup Error Log - $dateFormat" $mailAddress
        fi
elif [ "$mailContent" = "quiet" ]
then
        if [ -s "$logErr" ]
                then
                        cat "$logErr" | mail -s "ERRORS REPORTED: Amazon EC2 Snapshot $interval Backup Error Log - $dateFormat" $mailAddress
                        cat "$logFile" | mail -s "Amazon EC2 Snapshot $interval Backup Log - $dateFormat" $mailAddress
        fi
elif [ "$mailContent" = "loginone" ]
then
        cat "$logFile" "$logErr" | mail -s "Amazon EC2 Snapshot $interval Backup Log - $dateFormat" $mailAddress
else
        if [ -s "$logErr" ]
                then
                        cat "$logFile"
                        echo
                        echo "###### WARNING ######"
                        echo "Errors reported during Amazon EC2 Snapshot execution.. Backup failed"
                        echo "Error log below.."
                        cat "$logErr"
        else
                cat "$logFile"
        fi
fi

if [ -s "$logErr" ]
        then
                STATUS=1
        else
                STATUS=0
fi

# Clean up Logfile
#eval rm -f "$dailyLogFile"
#eval rm -f "$dailyLogErr"


exit $STATUS
