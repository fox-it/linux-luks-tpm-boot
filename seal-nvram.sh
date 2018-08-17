#!/bin/bash 

if [ $(whoami) != "root" ]
then 
  echo "$0 must be run as root!"
  exit -1
fi

# The NVRAM index in which we will store our secret
INDEX=1 
# The secret keyfile we will use to put into the NVRAM 
KEYFILE="/secret.bin" 
# The permissions we will require to read/write the NVRAM index
PERMISSIONS="OWNERWRITE|READ_STCLEAR" 

if [ "$1" != "-z" ] 
then 
  echo "sealing to PCRS 0-13... " 
  PCRS="-r0 -r1 -r2 -r3 -r4 -r5 -r6 -r7 -r8 -r9 -r10 -r11 -r12 -r13" 
fi 

read -s -p "Owner password: " OWNERPW

# Check if the NVRAM index already exists
tpm_nvinfo | grep \($INDEX\) > /dev/null
if [ $? -eq 0 ]
then
  tpm_nvrelease -i $INDEX -o"$OWNERPW"
fi

# Create a new NVRAM index
tpm_nvdefine -i $INDEX -s $(wc -c $KEYFILE) -p $PERMISSIONS -o "$OWNERPW" -z $PCRS

# Write the index if creating the index succeeded
if [ $? -eq 0 ]
then
  tpm_nvwrite -i $INDEX -f $KEYFILE -z --password="$OWNERPW"
fi
