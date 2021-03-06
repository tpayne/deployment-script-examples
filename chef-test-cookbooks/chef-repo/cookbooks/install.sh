#!/bin/sh
# WARNING: REQUIRES /bin/sh
#
# - must run on /bin/sh on solaris 9
# - must run on /bin/sh on AIX 6.x
# - if you think you are a bash wizard, you probably do not understand
#   this programming language.  do not touch.
# - if you are under 40, get peer review from your elders.
#
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

prerelease="false"

nightlies="false"

project="chef"

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

report_bug() {
  echo "Please file a bug report at http://tickets.opscode.com"
  echo "Project: Chef"
  echo "Component: Packages"
  echo "Label: Omnibus"
  echo "Version: $version"
  echo " "
  echo "Please detail your operating system type, version and any other relevant details"
}

# Get command line arguments
while getopts pnv:f:d:P: opt
do
  case "$opt" in

    v)  version="$OPTARG";;
    p)  prerelease="true";;
    n)  nightlies="true";;
    f)  cmdline_filename="$OPTARG";;
    P)  project="$OPTARG";;
    d)  cmdline_dl_dir="$OPTARG";;
    \?)   # unknown flag
      echo >&2 \
      "usage: $0 [-p] [-v version] [-f filename | -d download_dir]"
      exit 1;;
  esac
done
shift `expr $OPTIND - 1`

machine=`uname -m`
os=`uname -s`

#
# Platform and Platform Version detection
#
# NOTE: This should now match ohai platform and platform_version matching.
# do not invented new platform and platform_version schemas, just make this behave
# like what ohai returns as platform and platform_version for the server.
#
# ALSO NOTE: Do not mangle platform or platform_version here.  It is less error
# prone and more future-proof to do that in the server, and then all omnitruck clients
# will 'inherit' the changes (install.sh is not the only client of the omnitruck
# endpoint out there).
#

if test -f "/etc/lsb-release" && grep -q DISTRIB_ID /etc/lsb-release; then
  platform=`grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[A-Z]' '[a-z]'`
  platform_version=`grep DISTRIB_RELEASE /etc/lsb-release | cut -d "=" -f 2`
elif test -f "/etc/debian_version"; then
  platform="debian"
  platform_version=`cat /etc/debian_version`
elif test -f "/etc/redhat-release"; then
  platform=`sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release`

  # If /etc/redhat-release exists, we act like RHEL by default
  if test "$platform" = "fedora"; then
    # FIXME: stop remapping fedora to el
    # FIXME: remove client side platform_version mangling and hard coded yolo
    # Change platform version for use below.
    platform_version="6.0"
  fi

  if test "$platform" = "xenserver"; then
    # Current XenServer 6.2 is based on CentOS 5, platform is not reset to "el" server should hanlde response
    platform="xenserver"
  else
    # FIXME: use "redhat"
    platform="el"
  fi

elif test -f "/etc/system-release"; then
  platform=`sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  # amazon is built off of fedora, so act like RHEL
  if test "$platform" = "amazon linux ami"; then
    # FIXME: remove client side platform_version mangling and hard coded yolo, and remapping to deprecated "el"
    platform="el"
    platform_version="6.0"
  fi
# Apple OS X
elif test -f "/usr/bin/sw_vers"; then
  platform="mac_os_x"
  # Matching the tab-space with sed is error-prone
  platform_version=`sw_vers | awk '/^ProductVersion:/ { print $2 }' | cut -d. -f1,2`

  # x86_64 Apple hardware often runs 32-bit kernels (see OHAI-63)
  x86_64=`sysctl -n hw.optional.x86_64`
  if test $x86_64 -eq 1; then
    machine="x86_64"
  fi
elif test -f "/etc/release"; then
  machine=`/usr/bin/uname -p`
  if grep -q SmartOS /etc/release; then
    platform="smartos"
    platform_version=`grep ^Image /etc/product | awk '{ print $3 }'`
  else
    platform="solaris2"
    platform_version=`/usr/bin/uname -r`
  fi
elif test -f "/etc/SuSE-release"; then
  if grep -q 'Enterprise' /etc/SuSE-release;
  then
      platform="sles"
      platform_version=`awk '/^VERSION/ {V = $3}; /^PATCHLEVEL/ {P = $3}; END {print V "." P}' /etc/SuSE-release`
  else
      platform="suse"
      platform_version=`awk '/^VERSION =/ { print $3 }' /etc/SuSE-release`
  fi
elif test "x$os" = "xFreeBSD"; then
  platform="freebsd"
  platform_version=`uname -r | sed 's/-.*//'`
elif test "x$os" = "xAIX"; then
  platform="aix"
  platform_version=`uname -v`
  machine="ppc"
fi

if test "x$platform" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

#
# NOTE: platform manging in the install.sh is DEPRECATED
#
# - install.sh should be true to ohai and should not remap
#   platform or platform versions.
#
# - remapping platform and mangling platform version numbers is
#   now the complete responsibility of the server-side endpoints
#

major_version=`echo $platform_version | cut -d. -f1`
case $platform in
  # FIXME: should remove this case statement completely
  "el")
    # FIXME:  "el" is deprecated, should use "redhat"
    platform_version=$major_version
    ;;
  "debian")
    # FIXME: remove client-side yolo here
    case $major_version in
      "5") platform_version="6";;  # FIXME: need to port this "reverse-yolo" into platform.rb
      "6") platform_version="6";;
      "7") platform_version="6";;
    esac
    ;;
  "freebsd")
    platform_version=$major_version
    ;;
  "sles")
    platform_version=$major_version
    ;;
  "suse")
    platform_version=$major_version
    ;;
esac

if test "x$platform_version" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

if test "x$platform" = "xsolaris2"; then
  # hack up the path on Solaris to find wget
  PATH=/usr/sfw/bin:$PATH
  export PATH
fi

checksum_mismatch() {
  echo "Package checksum mismatch!"
  report_bug
  exit 1
}

unable_to_retrieve_package() {
  echo "Unable to retrieve a valid package!"
  report_bug
  echo "Metadata URL: $metadata_url"
  if test "x$download_url" != "x"; then
    echo "Download URL: $download_url"
  fi
  if test "x$stderr_results" != "x"; then
    echo "\nDEBUG OUTPUT FOLLOWS:\n$stderr_results"
  fi
  exit 1
}

capture_tmp_stderr() {
  # spool up /tmp/stderr from all the commands we called
  if test -f "/tmp/stderr"; then
    output=`cat /tmp/stderr`
    stderr_results="${stderr_results}\nSTDERR from $1:\n\n$output\n"
    rm /tmp/stderr
  fi
}

# do_wget URL FILENAME
do_wget() {
  echo "trying wget..."
  wget -O "$2" "$1" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "ERROR 404" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "wget"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_curl() {
  echo "trying curl..."
  curl -sL -D /tmp/stderr "$1" > "$2"
  rc=$?
  # check for 404
  grep "404 Not Found" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "curl"
    return 1
  fi

  return 0
}

# do_fetch URL FILENAME
do_fetch() {
  echo "trying fetch..."
  fetch -o "$2" "$1" 2>/tmp/stderr
  # check for bad return status
  test $? -ne 0 && return 1
  return 0
}

# do_curl URL FILENAME
do_perl() {
  echo "trying perl..."
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "$1" > "$2" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "404 Not Found" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "perl"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_python() {
  echo "trying python..."
  python -c "import sys,urllib2 ; sys.stdout.write(urllib2.urlopen(sys.argv[1]).read())" "$1" > "$2" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "HTTP Error 404" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "python"
    return 1
  fi
  return 0
}

# returns 0 if checksums match
do_checksum() {
  if exists sha256sum; then
    echo "Comparing checksum with sha256sum..."
    checksum=`sha256sum $1 | awk '{ print $1 }'`
    return `test "x$checksum" = "x$2"`
  elif exists shasum; then
    echo "Comparing checksum with shasum..."
    checksum=`shasum -a 256 $1 | awk '{ print $1 }'`
    return `test "x$checksum" = "x$2"`
  elif exists md5sum; then
    echo "Comparing checksum with md5sum..."
    checksum=`md5sum $1 | awk '{ print $1 }'`
    return `test "x$checksum" = "x$3"`
  elif exists md5; then
    echo "Comparing checksum with md5..."
    # this is for md5 utility on MacOSX (OSX 10.6-10.10) and $4 is the correct field
    checksum=`md5 $1 | awk '{ print $4 }'`
    return `test "x$checksum" = "x$3"`
  else
    echo "WARNING: could not find a valid checksum program, pre-install shasum, md5sum or md5 in your O/S image to get valdation..."
    return 0
  fi
}

# do_download URL FILENAME
do_download() {
  echo "downloading $1"
  echo "  to file $2"

  # we try all of these until we get success.
  # perl, in particular may be present but LWP::Simple may not be installed

  if exists wget; then
    do_wget $1 $2 && return 0
  fi

  if exists curl; then
    do_curl $1 $2 && return 0
  fi

  if exists fetch; then
    do_fetch $1 $2 && return 0
  fi

  if exists perl; then
    do_perl $1 $2 && return 0
  fi

  if exists python; then
    do_python $1 $2 && return 0
  fi

  unable_to_retrieve_package
}

# install_file TYPE FILENAME
# TYPE is "rpm", "deb", "solaris", or "sh"
install_file() {
  echo "Installing Chef $version"
  case "$1" in
    "rpm")
      echo "installing with rpm..."
      rpm -Uvh --oldpackage --replacepkgs "$2"
      ;;
    "deb")
      echo "installing with dpkg..."
      dpkg -i "$2"
      ;;
    "solaris")
      echo "installing with pkgadd..."
      echo "conflict=nocheck" > /tmp/nocheck
      echo "action=nocheck" >> /tmp/nocheck
      echo "mail=" >> /tmp/nocheck
      pkgrm -a /tmp/nocheck -n chef >/dev/null 2>&1 || true
      pkgadd -n -d "$2" -a /tmp/nocheck chef
      ;;
    "pkg")
      echo "installing with installer..."
      cd / && /usr/sbin/installer -pkg "$2" -target /
      ;;
    "dmg")
      echo "installing dmg file..."
      hdiutil detach "/Volumes/chef_software" >/dev/null 2>&1 || true
      hdiutil attach "$2" -mountpoint "/Volumes/chef_software"
      cd / && /usr/sbin/installer -pkg `find "/Volumes/chef_software" -name \*.pkg` -target /
      hdiutil detach "/Volumes/chef_software"
      ;;
    "sh" )
      echo "installing with sh..."
      sh "$2"
      ;;
    *)
      echo "Unknown filetype: $1"
      report_bug
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi
}

echo "Downloading Chef $version for ${platform}..."

if test "x$TMPDIR" = "x"; then
  tmp="/tmp"
else
  tmp=$TMPDIR
fi
# secure-ish temp dir creation without having mktemp available (DDoS-able but not expliotable)
tmp_dir="$tmp/install.sh.$$"
(umask 077 && mkdir $tmp_dir) || exit 1

metadata_filename="$tmp_dir/metadata.txt"

case "$project" in
  "chef")
    metadata_url="https://www.opscode.com/chef/metadata?v=${version}&prerelease=${prerelease}&nightlies=${nightlies}&p=${platform}&pv=${platform_version}&m=${machine}"
    ;;
  "angrychef")
    metadata_url="https://www.opscode.com/chef/metadata-angrychef?v=${version}&prerelease=${prerelease}&nightlies=${nightlies}&p=${platform}&pv=${platform_version}&m=${machine}"
    ;;
  "server")
    metadata_url="https://www.opscode.com/chef/metadata-server?v=${version}&prerelease=${prerelease}&nightlies=${nightlies}&p=${platform}&pv=${platform_version}&m=${machine}"
    ;;
  "chefdk")
    metadata_url="https://www.opscode.com/chef/metadata-chefdk?v=${version}&prerelease=${prerelease}&nightlies=${nightlies}&p=${platform}&pv=${platform_version}&m=${machine}"
    ;;
  "container")
    metadata_url="https://www.opscode.com/chef/metadata-container?v=${version}&prerelease=${prerelease}&nightlies=${nightlies}&p=${platform}&pv=${platform_version}&m=${machine}"
    ;;
    *)
esac

if test "x$platform" = "xsolaris2"; then
  if test "x$platform_version" = "x5.9" -o "x$platform_version" = "x5.10"; then
    # solaris 9 lacks openssl, solaris 10 lacks recent enough credentials - your base O/S is completely insecure, please upgrade
    metadata_url=`echo $metadata_url | sed -e 's/https/http/'`
  fi
fi

do_download "$metadata_url"  "$metadata_filename"

cat "$metadata_filename"

# check that all the mandatory fields in the downloaded metadata are there
if grep '^url' $metadata_filename > /dev/null && grep '^sha256' $metadata_filename > /dev/null && grep '^md5' $metadata_filename > /dev/null; then
  echo "downloaded metadata file looks valid..."
else
  echo "downloaded metadata file is corrupted or an uncaught error was encountered in downloading the file..."
  # this generally means one of the download methods downloaded a 404 or something like that and then reported a successful exit code,
  # and this should be fixed in the function that was doing the download.
  report_bug
  exit 1
fi

download_url=`awk '$1 == "url" { print $2 }' "$metadata_filename"`

if test "x$platform" = "xsolaris2"; then
  if test "x$platform_version" = "x5.9" -o "x$platform_version" = "x5.10"; then
    # solaris 9 lacks openssl, solaris 10 lacks recent enough credentials - your base O/S is completely insecure, please upgrade
    download_url=`echo $download_url | sed -e 's/https/http/'`
  fi
fi

filename=`echo $download_url | sed -e 's/^.*\///'`
filetype=`echo $filename | sed -e 's/^.*\.//'`

# use either $tmp_dir, the provided directory (-d) or the provided filename (-f)
if test "x$cmdline_filename" != "x"; then
  download_filename="$cmdline_filename"
elif test "x$cmdline_dl_dir" != "x"; then
  download_filename="$cmdline_dl_dir/$filename"
else
  download_filename="$tmp_dir/$filename"
fi

# ensure the parent directory where to download the installer always exists
download_dir=`dirname $download_filename`
(umask 077 && mkdir -p $download_dir) || exit 1

sha256=`awk '$1 == "sha256" { print $2 }' "$metadata_filename"`
md5=`awk '$1 == "md5" { print $2 }' "$metadata_filename"`

# check if we have that file locally available and if so verify the checksum
cached_file_available="false"
if test -f $download_filename; then
  echo "$download_filename already exists, verifiying checksum..."
  if do_checksum "$download_filename" "$sha256" "$md5"; then
    echo "checksum compare succeeded, using existing file!"
    cached_file_available="true"
  else
    echo "checksum mismatch, downloading latest version of the file"
  fi
fi

# download if no local version of the file available
if test "x$cached_file_available" != "xtrue"; then
  do_download "$download_url"  "$download_filename"
  do_checksum "$download_filename" "$sha256" "$md5" || checksum_mismatch
fi

if grep yolo "$metadata_filename" >/dev/null; then
  echo
  echo "WARNING: Chef-Client has not been regression tested on this O/S Distribution"
  echo "WARNING: Do not use this configuration for Production Applications.  Use at your own risk."
  echo
fi

install_file $filetype "$download_filename"

if test "x$tmp_dir" != "x"; then
  rm -r "$tmp_dir"
fi
