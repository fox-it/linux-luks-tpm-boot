#!/bin/sh 
# The index in which we stored the secret. This needs to be the same as in /sbin/seal-nvram.sh
INDEX=1 

# read the content of NVRAM
if tpm_nvread -i $INDEX -f /tmp/key >/dev/null; then
    cat /tmp/key
    rm /tmp/key
    # read the content again with size 0, to disable reading until reboot
    # For some reason, tcsd stops after the first command, so we have to start it again first and wait 1s for it to be ready
    tcsd && sleep 1
    tpm_nvread -i $INDEX -s 0 >> /dev/null
else
    IN_FD="/proc/self/fd/2"
    echo >&2 "TPM failed, please enter fallback passphrase:"
    stty <$IN_FD -echo
    read <$IN_FD -rs -t 10 key
    stty <$IN_FD echo
    echo -n $key
fi
