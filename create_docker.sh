#!/bin/sh
#

command=`basename $0`
direct=`dirname $0`
trap 'stty echo; echo "${command} aborted"; exit_error; exit' 1 2 3 15
#
CWD=`pwd`

logfile=
dockerCmd="`which docker`"
imageName=
outputName=
rmImage=0
tmpdir="/tmp/"
verbose=0
containerId=
cmdFile=
dateStr="`date +'%Y%m%d%H%M%S'`"

#
# Echo messages
#
echo_mess()
{
if [ "x${logfile}" = "x" ]; then 
   echo "${command}:" $*
else
   echo "${command}:" $* >> ${logfile} 2>&1
fi
}

debug_mess()
{
if [ ${verbose} -eq 0 ]; then
   :
else
   echo_mess $*
fi
return 
}

catdebug()
{
if [ ${verbose} -eq 0 ]; then
   :
else 
   cat $*
fi
return
}
#
# Exit error
#
exit_error()
{
exit 1
}

#
# Usage 
#
usage()
{
#
if [ $# -eq 0 ]; then
	show_usage
fi

while [ $# -ne 0 ] ; do
        case $1 in
             -l) logfile=$2
                 shift 2;;
             --base) imageName=$2
                 shift 2;;
             --image) outputName=$2
                 shift 2;;
             -f) cmdFile=$2
                 shift 2;;
	         --debug) set -xv ; shift;;
			 --rmi) rmImage=y; shift;;
             -v) verbose=1
                 shift;;
             -?*) show_usage ; break;;
             --) shift ; break;;
             -|*) break;;
        esac
done

if [ "x${imageName}" = "x" ]; then
	show_usage
fi

if [ "x${outputName}" = "x" ]; then
	outputName="${imageName}_${dateStr}"
fi

if [ "x${cmdFile}" != "x" -a ! -r "${cmdFile}" -a ! -s "${cmdFile}" ]; then
	echo_mess "Error: Script file cannot be read"
	exit_error
fi
return 0
}


show_usage()
{
echo "Usage: ${direct}/${command} --base <baseImage> [-v] [-l <logfile>] [--image <imageName>]"
exit 1
}

####################
# Common utilities
####################
#
#Check directory
#
check_dir()
{
debug_mess "Checking $1 exists..."
if [ ! -d "$1" ]; then
   return 1
else
   return 0
fi
}
#
# Create dirs
#
crdir()
{
if [ ! -d "$1" ]; then
   mkdir "$1"
fi
}
#
# Blat files
#
remove_file()
{
if [ -f "$1" ]; then
   rm -fr "$1" > /dev/null 2>&1
fi
}

remove_dir()
{
if [ -d "$1" ]; then
   rm -fr "$1" > /dev/null 2>&1
fi
}

#
# Get Machine & OS levels
#
get_machine()
{
(uname -m) > /dev/null 2>&1
if [ $? -ne 0 ]; then
        echo_mess "command uname not found"
        echo_mess "Please ensure that this command is in the search path"
        echo_mess "then restart the installation"
        exit 1
fi
machine_os="`uname -m`"
case "$machine_os" in
        sun4*)
                machine_os="`uname -s`""`uname -r`"
                break;;
        *i386* | *i486*)
                # Need more info
                machine_os="`uname -a`"
                break;;
        *9000*)
                machine_os="`uname -s`""`uname -r`"
                break;;
esac
return 0
}

#
# Pull docker image
#
pullDocker()
{
tmpfile="${tmpdir}/mig$$.log"
echo_mess "- Pulling docker image $1 from repo (if needed)..."
(${dockerCmd} images $1 | grep $1) > ${tmpfile} 2>&1
if [ $? -eq 0 ]; then
	debug_mess "- Image already present..."
	remove_file ${tmpfile}
	return 0
fi

(${dockerCmd} pull $1) > ${tmpfile} 2>&1
if [ $? -eq 0 ]; then
	remove_file ${tmpfile}
	return 0
else
	catdebug ${tmpfile}
	remove_file ${tmpfile}
	return 1
fi 
}

#
# Install Dev packs into image
#
installDevPacks()
{
tmpfile="${tmpdir}/mig$$.log"

echo_mess "- Installing development packs into image $1..."

cat << EOF | ${dockerCmd} run -i $1 > ${tmpfile} 2>&1
yum list -y
yum groupinstall 'Development Tools' -y 
yum install java-1.8.0-openjdk-devel -y
yum update -y
EOF

containerId="`docker ps -a | grep ${1} | awk '{ print $1; exit}'`"

if [ $? -eq 0 ]; then
	remove_file ${tmpfile}
	return 0
else
	catdebug ${tmpfile}
	remove_file ${tmpfile}
	return 1
fi 
}

#
# Install script into image
#
installScript()
{
tmpfile="${tmpdir}/output_${dateStr}.log"

echo_mess "- Installing script into image $1..."
echo_mess "-- The output will be logged ${tmpfile}..."

${dockerCmd} start ${containerId} > ${tmpfile} 2>&1

if [ $? -gt 0 ]; then
	catdebug ${tmpfile}
	return 1
fi 

${dockerCmd} exec -i ${containerId} /bin/sh < $2 > ${tmpfile} 2>&1
stat=$?

${dockerCmd} stop ${containerId} >> ${tmpfile} 2>&1
if [ $? -gt 0 ]; then
	catdebug ${tmpfile}
	return 1
fi 

if [ $stat -eq 0 ]; then
	return 0
else
	catdebug ${tmpfile}
	return 1
fi 
}

#
# Create new base image
#
createnewImage()
{
tmpfile="${tmpdir}/mig$$.log"

echo_mess "- Creating new image $2 from ${containerId}..."

${dockerCmd} commit ${containerId} $2:latest > ${tmpfile} 2>&1
if [ $? -eq 0 ]; then
	remove_file ${tmpfile}
	return 0
else
	catdebug ${tmpfile}
	remove_file ${tmpfile}
	return 1
fi 
}

#
# Delete container
#
deleteContainer()
{
tmpfile="${tmpdir}/mig$$.log"

echo_mess "- Deleting container $1..."

${dockerCmd} container rm $1 > ${tmpfile} 2>&1
if [ $? -eq 0 ]; then
	remove_file ${tmpfile}
	return 0
else
	catdebug ${tmpfile}
	remove_file ${tmpfile}
	return 1
fi 
}


###################################
###################################
##
## Main Docker
##

usage $*

echo_mess "Started `date`..."

pullDocker ${imageName}
if [ $? -gt 0 ]; then
   echo_mess "Error: Unable to pull image ${imageName}"
   exit_error
fi

installDevPacks ${imageName}
if [ $? -gt 0 ]; then
   echo_mess "Error: Unable to install dev packs into image ${imageName}"
   exit_error
fi

if [ "x${cmdFile}" != "x" ]; then
	installScript ${imageName} ${cmdFile}
	if [ $? -gt 0 ]; then
	   echo_mess "Error: Unable to run script file into image ${imageName}"
	   exit_error
	fi
fi

createnewImage ${imageName} ${outputName}
if [ $? -gt 0 ]; then
   echo_mess "Error: Unable to create new image ${outputName}"
   exit_error
fi

deleteContainer ${containerId} 
if [ $? -gt 0 ]; then
   echo_mess "Error: Unable to delete container ${containerId}"
   exit_error
fi

echo_mess "Done `date`."

cd $CWD
exit 0
