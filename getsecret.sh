#!/bin/sh 
# The index in which we stored the secret. This needs to be the same as in /sbin/seal-nvram.sh
INDEX=1 

# Set the size of the keyfile statically to 256
SIZE=256

#read the content of NVRAM, and cut off success-message at the end
tpm_nvread -i $INDEX -f /dev/stdout | head -c $SIZE
