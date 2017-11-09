#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "This script requires 2 arguments: Path where you want the SDK Installed and the "
    echo "the number of build threads to use when building. For example if you pass "
    echo "'Build_SDK.sh /opt/EMsoft_SDK 8' then /opt/EMsoft_SDK will be the folder"
    echo "that has all the dependent library folders in it."
    exit 
fi

SDK_INSTALL=${1}
PARALLEL_BUILD=${2}
HOST_SYSTEM=`uname`
echo "SDK_INSTALL=$SDK_INSTALL"
echo "PARALLEL_BUILD=$PARALLEL_BUILD"
echo "Host System: $HOST_SYSTEM"

#------------------------------------------------------------------------------
# Read the configuration file for the SDK Build. All important variables are 
# stored in the .conf file. DO NOT CHANGE variables in this file.
shopt -s extglob
configfile="SDK_Configuration.conf" # set the actual path name of your (DOS or Unix) config file
tr -d '\r' < $configfile > $configfile.unix
while IFS='= ' read lhs rhs
do
    if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
        rhs="${rhs%%\#*}"    # Del in line right comments
        rhs="${rhs%%*( )}"   # Del trailing spaces
        rhs="${rhs%\"*}"     # Del opening string quotes 
        rhs="${rhs#\"*}"     # Del closing string quotes 
        declare $lhs="$rhs"
    fi
done < $configfile.unix
rm $configfile.unix
#------------------------------------------------------------------------------

cd $SDK_INSTALL
echo ${SDK_INSTALL}

HOST_SYSTEM=`uname`
echo "Host System: $HOST_SYSTEM"


CMAKE=`type -P cmake`
if [[ $CMAKE == "" ]];
  then
  echo "CMake is needed for this script. Please install it on your system and be sure it is on your path."
  exit 1
fi


if [ ! -e "$SDK_INSTALL/${JSONFORTRAN_ARCHIVE_NAME}.tar.gz" ];
then
  echo "-------------------------------------------"
  echo " Downloading jsonfortran Version ${version}"
  echo "-------------------------------------------"
  $DOWNLOAD_PROG "${JSONFORTRAN_DOWNLOAD_SITE}/json-fortran" -o ${JSONFORTRAN_ARCHIVE_NAME}.tar.gz
fi

if [ ! -e "$SDK_INSTALL/${JSONFORTRAN_ARCHIVE_NAME}" ];
then
  tar -xvzf ${JSONFORTRAN_ARCHIVE_NAME}.tar.gz
# mv jsonfortran-1.8.15 jsonfortran-1.8.15_source
fi

# We assume we already have downloaded the source for json-fortran and have it in a folder
# called json-fortran
chmod 0777 ${JSONFORTRAN_ARCHIVE_NAME}
cd ${JSONFORTRAN_ARCHIVE_NAME}
mkdir Build
cd Build
$SDK_INSTALL/$CMAKE_FOLDER_NAME/${CMAKE_EXE_PATH}/bin/cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DSKIP_DOC_GEN=TRUE -DCMAKE_INSTALL_PREFIX=${SDK_INSTALL} ../
make -j${PARALLEL_BUILD}
make install
cd ../

#------------------------------------------------------------------------------
# This next bit of code sets the install name of the dylib to the full absolute
# path of the library. This will come in handy when packagin EMSoft with CMake
# by allowing CMake to more easily find the library and adjust its internal paths
cd ${SDK_INSTALL}/jsonfortran-${JSONFORTRAN_FC_VENDOR}-${JSONFORTRAN_VERSION}/lib
install_name_tool -id ${SDK_INSTALL}/jsonfortran-${JSONFORTRAN_FC_VENDOR}-${JSONFORTRAN_VERSION}/lib/libjsonfortran.${JSONFORTRAN_VERS_SHORT}.dylib ${SDK_INSTALL}/jsonfortran-${JSONFORTRAN_FC_VENDOR}-${JSONFORTRAN_VERSION}/lib/libjsonfortran.${JSONFORTRAN_VERS_SHORT}.dylib 

echo "#--------------------------------------------------------------------------------------------------" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "# jsonfortran Library" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "set(JSONFORTRAN_INSTALL \"\${EMsoft_SDK_ROOT}/jsonfortran-${JSONFORTRAN_FC_VENDOR}-${JSONFORTRAN_VERSION}\")" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "set(JSONFORTRAN_DIR \"\${JSONFORTRAN_INSTALL}/cmake\")" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "set(jsonfortran-${JSONFORTRAN_FC_VENDOR}_DIR \"\${JSONFORTRAN_DIR}\")" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "set(CMAKE_MODULE_PATH \${CMAKE_MODULE_PATH} \${JSONFORTRAN_DIR})" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
echo "" >> "$SDK_INSTALL/EMsoft_SDK.cmake"
