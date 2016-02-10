# ec2-snapshot-script
A script to create snapshot backups of all volumes attached to tagged EC2 instances, supporting multiple accounts with individual retention rules per snapshot interval.

## Overview
This script, in conjunction with a scheduler (e.g. cron) will create a snapshot for each volume attached to tagged EC2 instances. Multiple AWS accounts are supported; the script will recurse through all configured accounts. After snapshots are created, retention rules are applied, and the oldest snapshots are removed to maintain the configured number of snapshots per instance for that interval, regardless of the number of volumes attached to each instance.

The script supports quarter-hourly, hourly, daily and monthly snapshot intervals by default, however these can be easily modified. Instances can be tagged with any combination of intervals, allowing some instances to be backed up more frequently than others. The output of the script is redirected to a log file, and an email report can be configured if desired.

## Version history
### 2.1 - 2016-02-10
Minor spelling corrections, move environment variable path definitions to global.properties.
### 2.0 - 2015-12-02
Move properties to global.properties file, all in one script for all backup intervals.
Snapshots to keep now counted per instance, taking into account multiple volumes.
### 1.6 - 2015-11-27
Change Volume Include source to a tag:value pair, removed volume exclude support.
### 1.5 - 2013-02-14
Add Volume Include support
### 1.4 - 2012-11-05
Add Region support
### 1.3 - 2012-01-07
Add Multiple Amazon Account Support
### 1.2 - 2012-01-03
Add Email Function
### 1.1 - 2012-01-02
Fix Cron Bugs
### 1.0 - 2012-01-01
Initial Release

## Prerequisites
This script requires the Amazon EC2 API tools to be installed and configured, and an IAM user with permission to create snapshots. Instructions on installing the API tools can be found here: [Setting Up the Amazon EC2 Command Line Interface Tools on Linux/Unix and Mac OS X](http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ec2-cli-linux.html).

## Installation
No specific installation is required, as this script can be run from any location. The config folder must be located in the same folder as the script.  

Tag the EC2 instances that are to have snapshots created with descriptive tags. By default, these tags are backup.quarterHourly, backup.hourly, backup.daily, backup.monthly. Assign a value to these tags (default value is "yes").

## Configuration

Configuration is split into global and account specific settings.  

### Global configuration
The global.properties file contains configuration options for logging and email reporting, as well as defining which accounts are to be included at which intervals. Global configuration options are documented in the *global.properties* file.

In addition to setting the EC2_HOME and JAVA_HOME environment variables as part of the EC2 API tools, they must also be specified in the *global.properties* file. For example:

    EC2_HOME=/usr/local/ec2/ec2-api-tools
    JAVA_HOME=/usr/lib/jvm/jre-1.8.0
    

Account intervals should be defined in the following format; for each account (e.g. example2), an account properties file named *example2.properties* in the config\\*example2* directory must exist.

    hourlyAccounts="
        example;ap-southeast-2
        example2;us-west-1
        "

### Account configuration
As outlined above, each account requires a separate configuration file named *account.properties* in the config\\*account* directory. An example account called *example* is included in the project.  

#### Options: 
`AWS_ACCESS_KEY=`*your AWS access key*  
`AWS_SECRET_KEY=`*your AWS secret key*  
`intervalBackupTag=""` *the tag for this interval, e.g. backup.hourly*  
`intervalTagValue=""` *the value of above tag to denote an instance to be backed up, e.g yes*  
`intervalSnapshotsKept=` *the number of snapshots to keep per instance for this interval, e.g. 96*  
`intervalDescription=""` *the description that will be used to identify the snapshot interval, for clean-up purposes, e.g. Snapshot-Hourly*  

## Running the script
    chmod +x ec2snapshot.sh
    ./ec2snapshot.sh -q|h|d|m
where the switch denotes the quarter-hourly, hourly, daily or monthly interval retention rules to be applied for this run.

### Sample crontab configuration:

First day of the month at 1am: `0 1 1 * * /etc/cron.allette/ec2-snapshot-script/ec2snapshot.sh -m`  
Daily at 2:05am: `5 2 * * * /etc/cron.allette/ec2-snapshot-script/ec2snapshot.sh -d`  
Hourly between 7am - 7pm: `5 7-19 * * * /etc/cron.allette/ec2-snapshot-script/ec2snapshot.sh -h`  
Quarter-hourly between 7am - 7pm: `*/15 7-19 * * * /etc/cron.allette/ec2-snapshot-script/ec2snapshot.sh -q`  

