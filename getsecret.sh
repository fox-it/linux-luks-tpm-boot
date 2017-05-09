#!/bin/sh 
# The index in which we stored the secret. This needs to be the same as in /sbin/seal-nvram.sh
INDEX=1 

# Set the size of the keyfile statically to 256
SIZE=256

# read the content of NVRAM, and cut off success-message at the end
tpm_nvread -i $INDEX -f /dev/stdout | head -c $SIZE

# read the content again with size 0, to disable reading until reboot
# For some reason, tcsd stops after the first command, so we have to start it again first and wait 1s for it to be ready
tcsd && sleep 1
tpm_nvread -i $INDEX -s 0 >> /dev/null
