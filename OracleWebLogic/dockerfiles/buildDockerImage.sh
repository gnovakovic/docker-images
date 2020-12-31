#!/bin/bash
#
# Since: October, 2014
# Author: bruno.borges@oracle.com
# Description: script to build a Docker image for WebLogic
#
#Copyright (c) 2014, 2020, Oracle and/or its affiliates.
#
#Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#

usage() {
cat << EOF

Usage: buildDockerImage.sh -v [version] [-d | -g | -m ] [-j] [-s] [-c]
Builds a Docker Image for Oracle WebLogic.

Parameters:
   -v: version to build. Required.
       Choose one of: $(for i in $(ls -d */); do echo -n "${i%%/}  "; done)
   -d: creates image based on 'developer' distribution
   -g: creates image based on 'generic' distribution
   -m: creates image based on 'slim' distribution
   -j: choose '8' to create a 14.1.1.0 image with JDK 8 or '11' to create a 14.1.1.0 image with JDK 11. 
   -c: enables Docker image layer cache during build
   -s: skips the MD5 check of packages
   -u: use Ubuntu as base image

* select one distribution only: -d, -g, or -m

LICENSE UPL 1.0

Copyright (c) 2014, 2020, Oracle and/or its affiliates.

EOF
exit 0
}

# Validate packages
validateJDK() {
   if [ "$VERSION" == "14.1.1.0" ]; then
      if [ "$JDKVER" != 8 -a "$JDKVER" != 11 ]; then
         echo "WebLogic Server 14.1.1.0 supports JDK 8 and 11.  JDK version $JDKVER is not supported."
         exit 1
      fi
   fi
}

checksumPackages() {
  echo "Checking if required packages are present and valid..."
  md5sum -c Checksum.$DISTRIBUTION
  if [ "$?" -ne 0 ]; then
    echo "MD5 for required packages to build this image did not match!"
    echo "Make sure to download missing files in folder $VERSION. See *.download files for more information"
    exit $?
  fi
}

if [ "$#" -eq 0 ]; then usage; fi

# Parameters
DEVELOPER=0
GENERIC=0
SLIM=0
VERSION="12.2.1.4"
JDKVER=8
SKIPMD5=0
NOCACHE=true
while getopts "hsdgmucj:v:" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "s")
      SKIPMD5=1
      echo "Set- Skip md5sum"
      ;;
    "d")
      DEVELOPER=1
      echo "Set- Distribution:Developer"
      ;;
    "g")
      GENERIC=1
      echo "Set- Distribution:Generic"
      ;;
    "j")
      JDKVER="$OPTARG"
      echo "Set- JDK Version $JDKVER"
      ;;
    "m")
      SLIM=1
      echo "Set- Distribution:Slim"
      ;;
    "v")
      VERSION="$OPTARG"
      echo "Set- WebLogic's Version $VERSION"
      ;;
    "c")
      NOCACHE=false
      echo "Set- NOCACHE to false"
      ;;
    "u")
      UBUNTU=".ubuntu"
      echo "Set- UBUNTU to true"
      ;;
    *)
    # Should not occur
      echo "Unknown error while processing options inside buildDockerImage.sh"
      ;;
  esac
done

# Which distribution to use?
if [ $((DEVELOPER + GENERIC + SLIM)) -gt 1 ]; then
  usage
elif [ $DEVELOPER -eq 1 ]; then
  DISTRIBUTION="developer"
elif [ $GENERIC -eq 1 ]; then
  DISTRIBUTION="generic"
elif [ $SLIM -eq 1 ]; then
  DISTRIBUTION="slim"
else
  echo "Invalid distribution, please elect one distribution only: -d, -m, or -g"
  exit 1
fi

# For WLS 14.1.1.0 Validate JDK is 8 or 11
validateJDK

# Which JDK FOR VERSION 14.1.1.0
if [ "$VERSION" == "14.1.1.0" ]; then
   DIST="$DISTRIBUTION-$JDKVER"
   echo "Version= $VERSION Distribution= $DIST"
else
   DIST="$DISTRIBUTION"
   echo "Version= $VERSION Distribution= $DIST"
fi


# WebLogic Image Name
IMAGE_NAME="oracle/weblogic:$VERSION-$DIST"

if [ "${UBUNTU}" != "" ]; then
  IMAGE_NAME="oracle/weblogic:$VERSION-$DIST-ubuntu"  
fi

# Go into version folder
cd $VERSION

if [ ! "$SKIPMD5" -eq 1 ]; then
  checksumPackages
else
  echo "Skipped MD5 checksum."
fi

echo "====================="

# Proxy settings
PROXY_SETTINGS=""
if [ "${http_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg http_proxy=${http_proxy}"
fi

if [ "${https_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg https_proxy=${https_proxy}"
fi

if [ "${ftp_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg ftp_proxy=${ftp_proxy}"
fi

if [ "${no_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg no_proxy=${no_proxy}"
fi

if [ "$PROXY_SETTINGS" != "" ]; then
  echo "Proxy settings were found and will be used during build."
fi

# ################## #
# BUILDING THE IMAGE #
# ################## #
echo "Building image '$IMAGE_NAME' ..."
echo "Building image using Dockerfile.'$DIST$UBUNTU'"

# BUILD THE IMAGE (replace all environment variables)
BUILD_START=$(date '+%s')
  docker build --force-rm=$NOCACHE --no-cache=$NOCACHE $PROXY_SETTINGS -t $IMAGE_NAME -f Dockerfile.$DIST$UBUNTU . || {
  echo "There was an error building the image."
  exit 1
}
BUILD_END=$(date '+%s')
BUILD_ELAPSED=`expr $BUILD_END - $BUILD_START`

echo ""

if [ $? -eq 0 ]; then
cat << EOF
  WebLogic Docker Image for '$DIST' version $VERSION is ready to be extended:

    --> $IMAGE_NAME

  Build completed in $BUILD_ELAPSED seconds.

EOF
else
  echo "WebLogic Docker Image was NOT successfully created. Check the output and correct any reported problems with the docker build operation."
fi
