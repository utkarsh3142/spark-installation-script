#!/bin/bash
####################################################################################################################
# Title           :spark_install.sh
# Description     :This script was created for the IU course I535 Management, Access and Use of Big and Complext Data.
# Author	  :Utkarsh Kumar, INFO-I 535
# Date            :09/26/2019
# Version         :0.1    
# License	  :The script is distributed under the GPL 3.0 license (http://www.gnu.org/licenses/gpl-3.0.html)
#		   You are free to run, study, share and modify this script. 
###################################################################################################################

###################################################################################################################
############################################## CONFGIURATIONS #####################################################
###################################################################################################################

####### Configuration variables ##########
# Username who should be the owner of spark and run spark
USERNAME=<username>

# Spark tarball url
SPARK_TARBALL_URL="http://mirror.olnevhost.net/pub/apache/spark/spark-2.4.4/spark-2.4.4-bin-hadoop2.7.tgz"

# Set the location of spark installation directory
SPARK_HOME_DIR="/opt/spark"

# Specify the java to be installed using yum install
JAVA_TYPE="java-1.8.0-openjdk"

# Derived Variables
USER_HOME="/home/$USERNAME"
BASH_PROFILE="$USER_HOME/.bashrc"
# Outfile
OUT_FILE="$USER_HOME/spark_install.out" 


####### Flags #########
# To start all spark daemons (start-all.sh), set the flag to 1. This flag should only be set if ssh less 
# login has been setup for localhost. Otherwise the start will fail.
RUN_SPARK_DAEMONS=0

# Other script flags. Not to be changed. 
SPARK_DOWNLOAD_FLAG=0
JAVA_INSTALL_FLAG=0
SPARK_INSTALL_FLAG=0

########################################### END OF CONFGIURATIONS #################################################

###################################################################################################################
################################################ FUNCTIONS ########################################################
###################################################################################################################

# Formatted output
function out() 
{
    echo "[${USER}][`date`] - ${*}"
}


# Help function 
function helpFunction()
{
   echo ""
   echo "Usage: $0 -d <dirname>"
   echo -e "\t-d Directory where spark will be installed - SPARK_HOME. Default is /opt"
   exit 1 
}

# Function to initialize SPARK_HOME by default
function defaultInit()
{
   out "INFO - Spark Home directory not defined. Using default directory /opt/spark to install Spark."
   SPARK_HOME_DIR="/opt/spark"
}

# Function to install java
function install_java()
{
	out "INFO - Installing java version 1.8. JAVA TYPE - $JAVA_TYPE"
	command="yum install -y $JAVA_TYPE"
	if $command >> $OUT_FILE; then
		JAVA_VERSION=$(java -version 2>&1 | awk -F '"' 'NR==1 {print $2}')
		JAVA_INSTALL_FLAG=1
		out "INFO - Installed java 1.8 successfully. JAVA VERSION $JAVA_VERSION"
	else
		out "ERROR - Failed to install Java. Please install java manually and then rerun the script."
		exit 9
	fi
}

# Function to check if directory exists, if not then create
function check_dir()
{
	if [ ! -d "$1" ]
	then
		out "INFO - Creating directory $1"
		mkdir $1
	else
		out "INFO - $1 already exists."
	fi
}

############################################## END OF FUNCTIONS ####################################################

####################################################################################################################
############################################## MAIN SCRIPT #########################################################
####################################################################################################################

out "INFO - Starting Spark Installation Script"
out "INFO - Spark URL - $SPARK_TARBALL_URL"
out "INFO - Java Type - $JAVA_TYPE"
out "INFO - Bash profile file - $BASH_PROFILE"
out "INFO - Using spark directory - $SPARK_HOME_DIR"

# Check if the user running the script is root or not. Use sudo script to run this script.
out "INFO - Checking if you are a root user."
if [ "$UID" -ne "0" ]; then
    out "WARN - You must be root to run $0. Try - sudo $0"
	out "ERROR - Exiting script."
    exit 9
fi

# Check if java is installed or not. If not, install java using install java function.
if type -p java >> $OUT_FILE; then
	JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1"."$2}')
	if [[ "$JAVA_VERSION" == "1.8" ]]; then
		out "INFO - Java version 1.8 is already installed. JAVA VERSION $JAVA_VERSION"
		JAVA_INSTALL_FLAG=1
	elif [[ "$JAVA_VERSION" == "" ]]; then
		install_java
	else
		out "WARN - Java version is not 1.8. JAVA VERSION $JAVA_VERSION"
		install_java
	fi
else
	install_java
fi

# Download Spark tarball and extract to SPARK_HOME
if [[ $JAVA_INSTALL_FLAG -eq 1 ]]; then
	out "INFO - Downloding spark tarball from - $SPARK_TARBALL_URL"
	command="wget -O /tmp/spark.tgz $SPARK_TARBALL_URL"
	if $command >> $OUT_FILE; then
		out "INFO - Spark tarball download complete"
		SPARK_DOWNLOAD_FLAG=1
		if check_dir "$SPARK_HOME_DIR"; then 
			out "INFO - Extracting spark tarball to $SPARK_HOME_DIR"
			command="tar -zxf /tmp/spark.tgz --directory $SPARK_HOME_DIR --strip-components=1"
			if $command >> $OUT_FILE; then
				SPARK_INSTALL_FLAG=1
				out "INFO - Spark tarball successfully downloaded and extracted."
				rm /tmp/spark.tgz
				out "INFO - Changing ownership of $SPARK_HOME_DIR"
				chown -R $USERNAME:$USERNAME $SPARK_HOME_DIR
			else
				out "ERROR - Failed to extract spark tarball"
				exit 9
			fi
		else
			out "ERROR - Failed to create spark home directory."
			exit 9
		fi
	else
		out "ERROR - Failed to download spark."
		exit 9
	fi
else
	out "ERROR - Java is not installed. Exiting script."
	exit 9
fi


#******************** BELOW COMMANDS ARE ONLY RELEVANT TO THE PROJECT VM **********************
# Change configuration to add "127.0.0.1" to spark-env.sh file. This is required to start spark daemons.
out "INFO - Adding SPARK_LOCAL_IP as 127.0.0.1 to spark-env.sh"
echo 'export SPARK_LOCAL_IP="127.0.0.1"' >> $SPARK_HOME_DIR/conf/spark-env.sh
#**********************************************************************************************


# Start spark daemons if flag is set.
if [ $RUN_SPARK_DAEMONS -eq 1 ]; then 
	out "INFO - Starting spark daemons."
	command="su - $USERNAME $SPARK_HOME_DIR/sbin/start-all.sh"
	if $command >> $OUT_FILE; then
		out "INFO - Spark daemons started."
	else
		out "WARN - Error starting spark daemons. Please check the logs in $SPARK_HOME_DIR/logs"
	fi
fi

# Add SPARK_HOME to bash profile
out "INFO - Adding SPARK_HOME to bash profile - $BASH_PROFILE"
if ! grep -Fxq "export SPARK_HOME=$SPARK_HOME_DIR" $BASH_PROFILE; then
	echo "export SPARK_HOME=$SPARK_HOME_DIR" >> $BASH_PROFILE
fi
if ! grep -Fxq 'export PATH=$SPARK_HOME/bin:$PATH' $BASH_PROFILE; then
	echo 'export PATH=$SPARK_HOME/bin:$PATH' >> $BASH_PROFILE
fi

out "INFO - End of spark installation script."
	
############################################## END OF MAIN SCRIPT ###################################################
