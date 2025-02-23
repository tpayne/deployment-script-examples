#!/bin/sh
#
command=`basename $0`
direct=`dirname $0`
trap 'stty echo; echo "${command} aborted"; exit_error; exit' 1 2 3 15
#
CWD=`pwd`

logfile=
verbose=0
svnExe=svn
runCm=0
force=0

baseURI="http://localhost:8080/testrepo/"
user=
passwd=

productId=MINAKO
projectId=SVNTEST

isWindows=`(uname -a | grep Cygwin | wc -l)`
if [ ${isWindows} -gt 0 ]; then
	tmpDir=c:\\temp\\
else
	tmpDir="/tmp"
fi

tid="`date +'%Y%m%d%H%M%S'`"

cmServer=`hostname`:671
cmDb=

testFile=svnTestSuite.tar
testDir="${tmpDir}/svnTests${tid}/"

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
while [ $# -ne 0 ] ; do
        case $1 in
             -l) logfile=$2
                 shift 2;;
	     --debug) set -xv ; shift;;
	     --cm-server) cmServer=$2
	     	 shift 2;;
	     --cm-db) cmDb=$2
	         shift 2;;
	     --run-cm-setup) runCm=1; shift;;
	     --user) user=$2
	         shift 2;;
	     --passwd) passwd=$2
	         shift 2;;
	     --base-url) baseURI=$2
	         shift 2;;
	     --product-id) productId=$2
	         shift 2;;
	     --project-id) projectId=$2
	         shift 2;;
	     --test-file) testFile=$2
	     	 shift 2;;
             -v) verbose=1
                 shift;;
             -f) force=1
                 shift;;                 
             -?*) show_usage ; break;;
             --) shift ; break;;
             -|*) break;;
        esac
done

return 0
}

show_usage()
{
echo "Usage: ${direct}/${command} [-l <logFile>]"
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
debug_mess "- Checking $1 exists..."
if [ ! -d "$1" ]; then
   return 1
else
   return 0
fi
}
#
#Check file
#
check_file()
{
debug_mess "- Checking $1 exists..."
if [ ! -f "$1" ]; then
   return 1
else
   return 0
fi
}
#
# Create dirs
#
create_dir()
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

####################
# Test suite utilities
####################
expandTestFiles()
{
check_file "${testFile}"
fileSpec="`readlink -f ${testFile}`"

if [ $? -gt 0 ]; then
	echo_mess "File ${testFile} does not exist" 
	return 1
fi

tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

create_dir "${testDir}"

echo_mess "- Expanding test files..."
(cd "${testDir}"; tar xvf ${fileSpec}) > "${tmpFile}" 2>&1
if [ $? -gt 0 ]; then
	catdebug ${tmpFile}
	remove_dir "${testDir}"
	return 1
fi

return 0
}

#
# Check SVN exe
#
svnCheck()
{
echo_mess "- Checking SVN client..."
(${svnExe} --version) > /dev/null 2>&1
if [ $? -gt 0 ]; then
	return 1
fi
return 0
}

#
# Check test results
#
testResult()
{
noLines="`cat ${1} | wc -l`"
if [ ${noLines} -ne ${2} ]; then
	echo_mess "-- Test failed - found ${noLines}, expected ${2} (${3})"
	return 1
fi

return 0
}

#
# Setup data in CM
#
runCmSetup()
{
echo_mess "- Setting up CM data..."

(dmcli -help) > /dev/null 2>&1
if [ $? -gt 0 ]; then
	return 1
fi

tmpFile="${tmpDir}/res$$.log"
tmpCmdFile="${tmpDir}/cmFile$$.xcmd"
tmpLibDir="${tmpDir}/svnLib${tid}/"

remove_file "${tmpCmdFile}"
remove_file "${tmpFile}"
remove_dir "${tmpLibDir}"

userName=$1
passWord=$2
server=$3
dbName=$4

product=$5
project=$6${tid}

projectId=${project}

libNode=`echo "${server}" | gawk -F: '{print $1;}'`

cat << EOF > "${tmpCmdFile}"
dwp "${product}"
dnp "${product}" /desc=Test /var=a /pcs=1 /product="${userName}"
auth /user="${userName}" /pass="${passWord}" /net="${libNode}"
dpl "${product}" /lib="${tmpLibDir}" /net="${libNode}" /item=*
cs "${product}":"${project}" /desc=Test
priv item_create /prod="${product}" /user="${userName}" /rule=user_enable
priv item_browse /prod="${product}" /user="${userName}" /rule=user_enable
EOF

(cat "${tmpCmdFile}" | \
 dmcli -user "${userName}" -pass "${passWord}" \
	-host "${server}" \
	-dbname "${dbName}") > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	catdebug "${tmpFile}"
	remove_file "${tmpCmdFile}"
	remove_file "${tmpFile}"
	return 1
fi

grep -i Error "${tmpFile}" >/dev/null 2>&1

if [ $? -eq 0 ]; then
	remove_file "${tmpCmdFile}"
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpCmdFile}"
remove_file "${tmpFile}"
return 0
}

#
# Import files
#
importTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

failure=0

echo_mess "- Running Import tests..."

#cmd="${svnExe} import ServerSuites -m Test ${baseURI}/${productId}/${projectId} --username ${user} --password ${passwd}"
cmd="dm import ServerSuites -m Test --stream ${productId}:${projectId} --area . --user ${user} --password ${passwd} --server ${server}"
(cd "${testDir}"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1
	
if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 120 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Initial checkout test failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Checkout files
#
checkOutTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"
remove_dir "${checkOutDir}"
create_dir "${checkOutDir}"
failure=0

echo_mess "- Running checkout tests..."
cmd="${svnExe} co ${baseURI}/${productId}/${projectId} . --username ${user} --password ${passwd}"
(cd "${checkOutDir}"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 120 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Initial checkout test failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"

noFiles=`/bin/find "${checkOutDir}" -type f | wc -l`
noDirs=`/bin/find "${checkOutDir}" -type d | wc -l`

if [ ${noFiles} -ne 149 ]; then
	echo_mess "The files and directories checked out were not as expected"
	return 1
fi

if [ ${noDirs} -ne 110 ]; then
	echo_mess "The files and directories checked out were not as expected"
	return 1
fi

return 0
}

#
# Commit files
#
commitTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} add file1.txt file2.txt file3.txt file4.txt dimensionsServerSuite/file5.txt --username ${user} --password ${passwd}"
echo_mess "- Running commit tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 touch file1.txt file2.txt file3.txt file4.txt; \
 touch dimensionsServerSuite/file5.txt; \
 ${cmd}) \
 	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 5 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Commit command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ci -m Commit_Test file1.txt file2.txt file3.txt file4.txt dimensionsServerSuite/file5.txt --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 7 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Commit command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Log tests
#
logTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} log --username ${user} --password ${passwd}"
echo_mess "- Running log tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 5 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Log command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} log -v --username ${user} --password ${passwd}"
(cd "${checkOutDir}"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1


if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 125 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Log command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} log dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 5 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Log command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} log ${baseURI}/${productId}/${projectId}/ServerSuites/dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 5 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "Log command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# LS tests
#
lsTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} ls --username ${user} --password ${passwd}"
echo_mess "- Running ls tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 2 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -v --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 3 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -v dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -R -v ${baseURI}/${productId}/${projectId}/ServerSuites/dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -R -v ${baseURI}/${productId}/${projectId}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 120 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -R -v ${baseURI}/${productId}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 121 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} ls -R -v ${baseURI}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "LS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Info tests
#
infoTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} info --username ${user} --password ${passwd}"
echo_mess "- Running info tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 13 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 16 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi


cmd="${svnExe} info ${baseURI}/${productId}/${projectId}/ServerSuites/dimensionsServerSuite/src/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 11 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info dimensionsServerSuite/src/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 13 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info ${baseURI}/${productId}/${projectId}/ServerSuites/dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 12 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info ${baseURI}/${productId}/${projectId}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 11 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info -R ${baseURI}/${productId}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1406 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} info -R ${baseURI}/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "INFO command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Stat tests
#
statTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} stat -u --username ${user} --password ${passwd}"
echo_mess "- Running status tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} stat -u dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi


cmd="${svnExe} status -u dimensionsServerSuite/src/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Cat tests
#
catTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

echo_mess "- Running cat tests..."

cmd="${svnExe} cat dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 538 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "CAT command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} cat ${baseURI}/${productId}/${projectId}/ServerSuites/dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 538 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "CAT command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Stat tests
#
statTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} stat -u --username ${user} --password ${passwd}"
echo_mess "- Running status tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} stat -u dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi


cmd="${svnExe} status -u dimensionsServerSuite/src/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "STATUS command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Update tests
#
updateTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

echo_mess "- Running update tests..."

cmd="${svnExe} up dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 2 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "UPDATE command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_dir "${checkOutDir}/ServerSuites/dimensionsServerSuite/src/"

cmd="${svnExe} up dimensionsServerSuite/src/ --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 92 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "UPDATE command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Diff tests
#
diffTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0

cmd="${svnExe} diff --username ${user} --password ${passwd}"
echo_mess "- Running diff tests..."
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) > "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 0 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "DIFF command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

cmd="${svnExe} diff dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 0 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "DIFF command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

(cd "${checkOutDir}/ServerSuites/"; \
 echo "xxcxcc" >> dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java) > /dev/null 2>&1
 
cmd="${svnExe} diff dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 9 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "DIFF command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Revert tests
#
revertTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"

failure=0
echo_mess "- Running revert tests..."

cmd="${svnExe} revert dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "REVERT command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

(cd "${checkOutDir}/ServerSuites/"; \
 echo "xxcxcc" >> dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java) > /dev/null 2>&1
 
cmd="${svnExe} revert dimensionsServerSuite/src/main/java/hudson/plugins/dimensionsServerSuite/Tasks/GenericCmdTask.java --username ${user} --password ${passwd}"
(cd "${checkOutDir}/ServerSuites/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 1 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "REVERT command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"
return 0
}

#
# Export tests
#
exportTest()
{
tmpFile="${tmpDir}/res$$.log"
remove_file "${tmpFile}"

checkOutDir="${testDir}/checkOut"
remove_dir "${checkOutDir}"
create_dir "${checkOutDir}"

echo_mess "- Running export tests..."

cmd="${svnExe} export ${baseURI}/${productId}/${projectId} --username ${user} --password ${passwd}"
(cd "${checkOutDir}/"; \
 ${cmd}) \
	> "${tmpFile}" 2>&1

if [ $? -gt 0 ]; then
	failure=1
fi

testResult "${tmpFile}" 121 ${LINENO}
if [ $? -gt 0 ]; then
	failure=1
fi

if [ ${failure} -gt 0 ]; then
	echo_mess "EXPORT command failed"
	echo_mess "Command was ${cmd}"
	catdebug ${tmpFile}
	remove_file "${tmpFile}"
	return 1
fi

remove_file "${tmpFile}"

noFiles=`/bin/find "${checkOutDir}" -type f | wc -l`
noDirs=`/bin/find "${checkOutDir}" -type d | wc -l`

if [ ${noFiles} -ne 75 ]; then
	echo_mess "The files and directories exported were not as expected"
	echo_mess "- Found ${noFiles} files"
	return 1
fi

if [ ${noDirs} -ne 46 ]; then
	echo_mess "The files and directories exported were not as expected"
	echo_mess "- Found ${noDirs} dirs"
	return 1
fi

return 0
}

###################################################################
# Run the test suite
#
runSuite()
{
cleanup

svnCheck
if [ $? -gt 0 ]; then
	echo_mess "Valid SVN client could not be found" 
	return 1
fi

expandTestFiles
if [ $? -gt 0 ]; then
	echo_mess "Error: Expanding the test file tar ${testFile} failed"
	return 1
fi

if [ ${runCm} -gt 0 ]; then
	runCmSetup "${user}" "${passwd}" "${cmServer}" "${cmDb}" "${productId}" "${projectId}"
	if [ $? -gt 0 ]; then
		echo_mess "Error: Unable to setup CM data"
		return 1
	fi
fi

importTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: Import test failed"
	return 1
fi

checkOutTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: Checkout test failed"
	return 1
fi

logTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: Log test failed"
	return 1
fi

lsTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: LS test failed"
	return 1
fi

catTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: CAT test failed"
	return 1
fi

diffTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: DIFF test failed"
	return 1
fi

revertTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: REVERT test failed"
	return 1
fi

infoTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: INFO test failed"
	return 1
fi

statTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: STATUS test failed"
	return 1
fi

exportTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: EXPORT test failed"
	return 1
fi

checkOutTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: Checkout test failed"
	return 1
fi

updateTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: UPDATE test failed"
	return 1
fi

commitTest
if [ $? -gt 0 -a ${force} -eq 0 ]; then
	echo_mess "Error: Commit test failed"
	return 1
fi

return 0
}

#
# Cleanup
#
cleanup()
{
echo_mess "- Cleaning up directories..."
remove_dir "${testDir}"

return 0
}


###################################################################

usage $*

echo "======================================"
echo "=== Tests started at `date`"
echo "======================================"

runSuite
cleanup

echo "======================================"
echo "=== Tests finished at `date`"
echo "======================================"

exit 0
#
