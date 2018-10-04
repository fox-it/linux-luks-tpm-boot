# linux-luks-tpm-boot

## Moved
This repository is maintained by the original author at https://github.com/morbitzer/linux-luks-tpm-boot
Please open any new issues/PRs here. The original guide is below for reference.

## Introduction
In my two and a half years as penetration tester, I had to learn the lesson that nowadays, physical access to a system doesn't necessarily mean access to all its secret data. I'm not much of a Windows guy, but I have to admit that Microsoft’s Bitlocker does a nice job with encrypting the harddisk and decrypting it at boot time without the user even noticing. If something in the boot-process is changed by an attacker, the system won't start up without having received the correct Bitlocker recovery key. This makes it more difficult ([I'm not saying impossible](https://events.ccc.de/camp/2007/Fahrplan/attachments/1300-Cryptokey_forensics_A.pdf)) for an attacker to gain access to a system for which he doesn't know the password, even though the system isn't asking for anything during boot time.

All this is achieved with the help of a little chip on the mainboard, the Trusted Platform Module ([TPM](http://www.howtogeek.com/237232/what-is-a-tpm-and-why-does-windows-need-one-for-disk-encryption/)). Being a Linux guy myself, I wanted to achieve with my favorite OS what Windows was already capable of. I was not able to find a full guide how to use [LUKS](https://gitlab.com/cryptsetup/cryptsetup/blob/master/README.md) or any other disk-encryption in combination with the TPM under Linux, thus motivating me to investigate and describe this process. Everything that is needed already exists, but it took me quite a while to have everything set up correctly. I hope that with this guide I can save some people that work. So, let's get started.

## Make sure you are using BIOS, not UEFI
Unfortunately, the [TrustedGRUB2](https://github.com/Rohde-Schwarz-Cybersecurity/TrustedGRUB2) bootloader we will be using doesn't yet support UEFI, so make sure you are using the classical BIOS. You can follow updates on the UEFI support of TrustedGRUB2 [here](https://github.com/Sirrix-AG/TrustedGRUB2/issues/15)

## Install the distro of your choice

Personally, I prefer Debian. The installer allows you to encrypt everything except the /boot partition with LUKS (`set up LVM with encryption`). So that's one easy way to do it. However, any other distro is fine too of course. Bare in mind though that some distros make use of [dracut instead of initramfs](https://lwn.net/Articles/317793/), so you might have to change some things if you want to use for example RedHat or Fedora. 


## Configuring your TPM

You'll have to take ownership of your TPM in case you haven't done so yet. You might be required to clear your TPM before you do this. Unfortunately, there is no defined way of how to do this, it depends on the hardware you are using. You'll probably be able to reset the TPM in your BIOS – for the systems I have seen so far, you can find the TPM settings under `Security` or `Onboard devices`. If not, you might want to look up a guide on how to reset the TPM on your hardware.  

First, install `TrouSers` and `tpm-tools`. Using Debian, this can be done with

`sudo aptitude install tpm-tools trousers`

Afterwards, you can take ownership of the TPM:

`sudo tpm_takeownership -z`

The `-z` parameter sets the Storage Root Key ([SRK](https://technet.microsoft.com/en-us/library/cc753560%28v=ws.11%29.aspx)) to its default value (all 0s). Choose a secure value for the owner password. You'll need this one only during updates, so you could also store it in a password manager. Only be careful with using special characters such as `\`. Since the bash-scripts we are about to use will hand the password as parameter to some commands, this could cause problems. 

## Install TrustedGRUB2

Installing TrustedGRUB2 can be done by simply following the readme:

```bash
git clone https://github.com/Rohde-Schwarz-Cybersecurity/TrustedGRUB2
cd TrustedGRUB2
sudo aptitude install autogen autoconf automake gcc bison flex
./autogen.sh
./configure --prefix=INSTALLDIR --target=i386 -with-platform=pc
make
sudo make install
sudo ./sbin/grub-install --directory=INSTALLDIR/lib/grub/i386-pc /dev/sda
```

Where `INSTALLDIR` is the directory in which TrustedGRUB2 is located.

During the install, you might get a warning that the directory /share/locale is missing. You can solve this issue by copying the folder from `/boot/grub/`:

``sudo cp -r /boot/grub/locale/ share/``

Now you can reboot to see if everything works. In your GRUB-selection screen, the title should now say `TrustedGRUB2`. After the reboot, you can check if TrustedGRUB measured itself, the kernel, initrd, etc by checking out the PCRs of the TPM. By looking at `/sys/class/tpm/tpm0/device/pcrs` (or `/sys/class/misc/tpm0/device/pcrs` for kernel versions < 4.x), you should see something like that:  

```
cat /sys/class/tpm/tpm0/device/pcrs
PCR-00: 73 5E 54 2B 1B 06 4C EA 91 DA 68 E7 33 18 62 CE 4A 5A 0B 1D
PCR-01: 3A 3F 78 0F 11 A4 B4 99 69 FC AA 80 CD 6E 39 57 C3 3B 22 75
PCR-02: 3A 3F 78 0F 11 A4 B4 99 69 FC AA 80 CD 6E 39 57 C3 3B 22 75
PCR-03: 3A 3F 78 0F 11 A4 B4 99 69 FC AA 80 CD 6E 39 57 C3 3B 22 75
PCR-04: B3 B6 C3 4A 7A 83 48 E4 A6 75 11 B8 E6 42 00 0C 10 E7 FF 13
PCR-05: 02 82 AA 3F CA 2D 1B E0 66 AE 8F EC 97 9D 66 2B 42 1D EE 8B
PCR-06: 3A 3F 78 0F 11 A4 B4 99 69 FC AA 80 CD 6E 39 57 C3 3B 22 75
PCR-07: 3A 3F 78 0F 11 A4 B4 99 69 FC AA 80 CD 6E 39 57 C3 3B 22 75
PCR-08: D3 F6 C9 85 14 27 D4 09 F4 77 F9 F4 98 DD C3 5B 3C 7A 84 E4
PCR-09: A3 85 26 69 72 FB C4 72 0D E1 DA 6D 20 5F DC CE 1B C2 7F 83
PCR-10: 22 FC 6C 27 48 77 17 94 52 1A 2D D1 29 DA 10 06 6C A0 47 76
PCR-11: A2 26 98 D8 E8 8F 3A E9 A3 2D D3 A7 5A 36 30 26 DF 92 0C 62
PCR-12: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
PCR-13: 06 85 EE 20 A9 48 E1 65 84 22 8E 20 85 80 67 B7 8E C4 ED 62
[..]
```

If TrustedGRUB2 works, you'll see that besides PCRs 0-7, which have been measured by the BIOS, also PCRs 8-13 contain measurements. The exception here is PCR-12, which normally contains the measurement of the LUKS header. However, since there is no decryption being done in the bootloader, this register stays empty.

For the curious, this is what measurements the single PCRs contain (taken from the [TrustedGRUB2 readme](https://github.com/Rohde-Schwarz-Cybersecurity/TrustedGRUB2/blob/master/README.md)):

* PCR 0-7 Measured by BIOS
* PCR 8 First sector of TrustedGRUB2 kernel (diskboot.img)
* PCR 9 TrustedGRUB2 kernel (core.img)
* PCR 10 Loader measurements - currently linux-kernel, initrd, ntldr, chainloader, multiboot, module
* PCR 11 Contains all commandline arguments from scripts (e.g. grub.cfg) and those entered in the shell
* PCR 12 LUKS-header
* PCR 13 Parts of GRUB2 that are loaded from disk like GRUB2-modules // TODO: fonts, themes, local

## Add key file to LUKS

Next, we are going to create a key file, which we will be add to our keys for the LUKS-encryption partition. Afterwards, we will store this key file in the TPMs NVRAM to use for decryption during boot time.

First, create a key file. I am using `/dev/random` for this [^note on /dev/random]. 

`sudo dd bs=1 count=256 if=/dev/random of=/secret.bin`

Make sure it's not readable for users:

`sudo chmod 700 /secret.bin`

Then, add the keyfile to LUKS:

`sudo cryptsetup luksAddKey /dev/sda<x> /secret.bin`

NOTE: Some people might not like the idea of the keyfile being (temporary) stored on the harddisk. Personally,
I don't really see a problem with that, since it is stored on an encrypted harddisk. If an attacker is able
to read the keyfile from your encrypted harddisk, you are in much bigger trouble anyway. Also, what's the
purpose of the whole disk-encryption idea? Stopping an attacker with physical access to your machine from reading
your files. So, in case somebody can read your /secret.bin, he or she has defeated or bypassed your disk encryption
anyway. (And also has root access to your machine... ) 

Further, if we do not store or wipe the keyfile, we would be required to create a new LUKS key and remove the
old one each time there was for example a kernel update. 

For all those reasons, I currently don't see a reason for not storing the keyfile on your harddisk. However,
I might still add this functionality at some point in time for the sake of it. 

In case I forgot to consider something important in this decision, please let me know!

[^note on /dev/random]: Compared to /dev/random, /dev/urandom [will block if the entropy pool is exhausted](http://www.onkarjoshi.com/blog/191/device-dev-random-vs-urandom/), so creation of your keyfile will probably take longer by using /dev/random. However, you could also use your [TPM to increase the speed of your /dev/random](https://wiki.archlinux.org/index.php/Rng-tools)

## Install necessary scripts

We will store the secret directly in the TPM - in its NVRAM. There's a tool for that called [tpm-luks](https://github.com/shpedoikal/tpm-luks), but it seemed to be a bit too much for what I needed (and only works with dracut), so I created my own bash scripts. First, to make things easier, I've created `/sbin/seal-nvram.sh`, a script that puts the content of your file in NVRAM and seals it to PCRs 0-13 if the parameter `-z` is NOT used. (I have to admit that checking for the `-z` parameter is quite hacky, but it did the job for me.) So, download seal-nvram.sh, move it to /sbin, and don't forget to make it executable:

```bash
sudo mv seal-nvram.sh /sbin/
sudo chmod +x /sbin/seal-nvram.sh
```

```text
Note: I have chosen to set the permission of the NVRAM I am creating to OWNERWRITE|READ_STCLEAR. Using READ_STCLEAR will allow us to block reading the secret from NVRAM once we decrypted our harddisk. Depending on your situation, others might suit better. The full list of possibilities is here 
(taken from the tpm_nvdefine manpage):

AUTHREAD : reading requires NVRAM area authorization
AUTHWRITE : writing requires NVRAM area authorization
OWNERREAD : writing requires owner authorization
OWNERWRITE : reading requires owner authorization
PPREAD : writing requires physical presence
PPWRITE : reading requires physical presence
GLOBALLOCK : write to index 0 locks the NVRAM area until TPM_STARTUP(ST_CLEAR)
READ_STCLEAR : a read with size 0 to the same index prevents further reading until ST_STARTUP(ST_CLEAR)
WRITE_STCLEAR : a write with size 0 to the same index prevents further writing until ST_STARTUP(ST_CLEAR)
WRITEDEFINE : a write with size 0 to the same index locks the NVRAM area permanently
WRITEALL : the value must be written in a single operation
```

Further, I have created a script that gets the content out of the NVRAM. This script will only be able to read the secret from NVRAM once, since it afterwards blocks further reads by reading 0 bits from the NVRAM area (see READ_STCLEAR). Again, it's a bit hacky, but it does its job:

```bash
sudo mv getsecret.sh /sbin/
sudo chmod +x /sbin/getsecret.sh
```

Now you can use `/sbin/seal-nvram.sh` to write a key file to the TPM's NVRAM, and `/sbin/getsecret.sh` to get it out again. Using the `-z` parameter for `/sbin/seal-nvram.sh` will ensure that the NVRAM index can only be read if the PCRs 0-13 are in exactly the same state as when the secret was written to NVRAM.
You can already test if the scripts are working by writing the content of the key file to the NVRAM (no need to seal just yet, so you can use the `-z` parameter) and reading it back out again:

```bash
sudo /sbin/seal-nvram.sh -z
sudo /sbin/getsecret.sh | hexdump -C
sudo hexdump -C /secret.bin
```

The last two commands should produce the same output. While `getsecret.sh` gets the content out of NVRAM, the other command read the keyfile directly. I use `hexdump` here to avoid the mess that might be created by simply outputting a file to stdout that contains random values.

## Changing /etc/crypttab

When this all works, you can adapt your `/etc/crypttab` to make use of the `/sbin/getsecret.sh` script. At the moment, the file will probably look something like this:

`sda<x>_crypt UUID=<UUID> none luks`

Add the keyscript parameter, so that your system will know to get the key file from the standard output of `/sbin/getsecret.sh` during boottime:

`sda<x>_crypt UUID=<UUID> none luks,keyscript=/sbin/getsecret.sh` 

## Configuring the initramfs

We are nearly done. The only thing left is to add some things to the initrd, so that we are able to communicate with the TPM while in the initrd. But before we mess around with our initrd, let's make a backup of the one we have:

`sudo cp /boot/initrd.img-$(uname -r) /boot/initrd.img-$(uname -r).orig`

Afterwards, we create a hook for the initramfs-tools. This is a script that adds the additional files to the initrd that we will need to talk to the TPM within the initrd. So download `tpm-hook` and move it in the directory for the initramfs-hooks:

```bash
sudo mv tpm-hook /etc/initramfs-tools/hooks/
sudo chmod +x /etc/initramfs-tools/hooks/tpm-hook
```

We also need a second script that starts up the tcsd daemon that communicates with the TPM in the initrd, `tpm-script`:

```bash
sudo mv tpm-script /etc/initramfs-tools/scripts/init-premount/
sudo chmod +x /etc/initramfs-tools/scripts/init-premount/tpm-script
```


NOTE: To write those scripts, I did take a massive amount of inspiration from [this](https://sourceforge.net/p/trousers/mailman/message/30218871/) and [that](https://sourceforge.net/p/trousers/mailman/message/5096163/) post on the
TrouSers mailing list as well as from [this script](https://github.com/simonschiele/initramfs-hooks/blob/master/network.sh).

Also, we need to tell the initrd to load the TPM modules. For this, add these two lines to `/etc/initramfs-tools/modules`:

```
tpm
tpm_tis
```

Now you are ready to create a new initrd:

`sudo update-initramfs -u`

Finally, you are ready to reboot your system. If everything went well, you should not be asked for a password during boottime.

In case something went wrong, press E in the TrustedGRUB2 boot menu. Then, append `.orig` to the name of the initrd. Now press `F10` to boot. This should allow you to boot up and provide a passphrase to decrypt the filesystem, just as before.

## Sealing the NVRAM

Now that you rebooted, your PCRs contain the up to date values from your new configuration that reads the keyfile from NVRAM during boottime. This means that you are now able to seal the NVRAM, meaning the NVRAM index can't be read if something is changed in the boot process (kernel, initrd, grub-modules, grub-arguments, etc… )

`sudo /sbin/seal-nvram.sh`

## Checking if it works

If you now reboot again, your system shouldn't boot up when you edit for example the boot menu entries. Just give it a try, press E in the TrustedGRUB2 boot menu. Then edit for example one of the `echo` lines, to output something different. Then press F10 to boot. This should be enough for your TPM to refuse to give out the key!  
It works? Perfect, you are ready to go!  Enjoy having to type one password less during boot time! :)

The system still boots up, although it shouldn't? Have a look at the next step…

## Setting the nvLocked bit

On one of my test systems, I had the problem that the secret stored in the NVRAM could be read even when the PCRs it was sealed to had changed. It took me quite a long time to figure out what went wrong: Apparently, the TPM manufacturer didn't set the `nvLocked` bit, which means that reading the NVRAM was always possible, no matter if you sealed it to some PCRs or assigned a password to it. Thanks to [this discussion](https://sourceforge.net/p/trousers/mailman/message/32332373/) at the TrouSers mailing list, I was finally able to figure out what to do:

You'll have to define an area the size 0 at position `0xFFFFFFF` in the NVRAM. This will equal setting the nvLocked bit. You can do so with the following command:

`sudo tpm_nvdefine -i 0xFFFFFFFF –size=0`

This solved the problem for me. Afterwards, my sealed NVRAM areas couldn't be read anymore if the PCRs it was sealed to had changed, and my system was finally save again. As Ken Goldman correctly pointed out:

> If your production platform is delivered that way, I consider that a security bug.

Thanks a lot to Frank Grötzner and Ken Goldman!

## Booting if something went wrong (or if there was a kernel update)

As described earlier, in case something went wrong within this process, or if there was a kernel update and your system won't read the contents of the NVRAM because the kernel-checksum has changed, press E in the TrustedGRUB2 boot menu. Then, append an ".orig" on the line were the initrd is specified. Now press F10 to boot. This allows you to boot the “normal” way, by providing a passphrase.

NOTE: This is why I recommend not to remove the passphrase from your LUKS  partition!

## Kernel update

The section above explains you how to be able to boot your system after a kernel update. Once you booted up, you can run `sudo /sbin/seal-nvram.sh -z` so that the secret in the NVRAM is not sealed to the PCRs anymore. After you have done this, you should be able to reboot and get the secret from the TPM again, just as before the update. Once you did this reboot, the PCRs will contain the correct values from your new kernel, the correct grub command line arguments (since before you had to add a `.orig` to be able to boot up again, PCR 11 changed). Now you can run `sudo /sbin/seal-nvram.sh` once more, this time without the `-z`, and now you should be ready to go again. 

## TODO: Encrypting /boot

Since version 2.02, the default installation of GRUB2 can also handle an encrypted /boot partition . Therefore, you would also  be able to encrypt your /boot partition, as show for example by Pavel Kogan [here](http://www.pavelkogan.com/2014/05/23/luks-full-disk-encryption/) and [here](http://www.pavelkogan.com/2015/01/25/linux-mint-encryption/)

TrustedGRUB2 can be installed if `/boot` is encrypted, as long as `/boot/grub` is not. This means you could use the partition that you use for `/boot` only for `/boot/grub`, and move everything else on `/boot` , and therefore to the encrypted partition that contains the rest of the OS.  If setup like this, one can still have things such as the kernel-image and the initrd encrypted and decrypt the OS partition at bootloader-time with GRUB's cryptomount command, which TrustedGRUB extends with options for providing a keyfile and the possibility to unseal the keyfile.

However, I did have issues using shpedoikal's [tpm-sealdata-raw-branch of tpm-tools](https://github.com/shpedoikal/tpm-tools) which would provide the `-r (--raw)` option to tpm_sealdata that is needed in order for TrustedGRUB2 to unseal the keyfile at bootloader time. I only got it working on one system, but not on 3 others, and I can't explain why.

If you would like to read further on this topic, follow these links:
[issue 5](https://github.com/Sirrix-AG/TrustedGRUB2/issues/), [issue 22] (https://github.com/Sirrix-AG/TrustedGRUB2/issues/22)
