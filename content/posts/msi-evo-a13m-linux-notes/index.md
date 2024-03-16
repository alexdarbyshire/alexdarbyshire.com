---
title: "MSI Evo Prestige A13M Linux Mint 21.3 Installation Notes"
date: 2024-03-16T08:17:15+10:00
author: "Alex Darbyshire"
banner: "img/banners/penguin-with-mint-leaves.jpeg"
slug: "msi-evo-a13m-linux-notes"
toc: false
tags:
  - Linux
description: How to get Linux to recognise MSI Evo Presitge A13M's hard drive and Wifi. 
---

A brief set of notes on getting Debian-based Linux up and running on an MSI Evo Prestige A13M (028AU) Laptop. 

The two aspects documented in these notes are making the hard drive available to Linux and getting the WiFi working. These did not work out of the box on first setting up this machine. 

The overall approach:
 * Download Linux Mint ISO Xfce Edition 21.3
 * Download Etcher
 * Burn ISO to USB stick using Etcher
 * **Disable Volume Management Device (VMD) in BIOS through hidden menu** 
 * Boot to USB stick and install 
 * **Update Kernel version to one that supports the WiFi driver**
 * **Download and install WiFi driver**

**Bolded steps are documented.**

### Getting Linux to Recognise Hard Drive on MSI Evo A13M by Disabling VMD and RST

The device comes with VMD enabled by default. Debian-based distros do not play well with VMD and the associated Intel RST.

This particular BIOS displayed the VMD status as grey and unselectable, and had no options to alter use of RST. 

Enable the BIOS hidden settings by holding `Right Alt` + `Right Shift` + `Left Ctrl` + `F2`.

Select `Configure System Agent` within the `Advanced` tab of the BIOS settings.

Select `Disable Volume Management Device`.

Save settings and restart. Debian-based distros should now recognise the hard drive at startup.

Be aware that existing OS installations, e.g. Windows, will be affected by this. 

Single boot Linux was the aim and I did not explore how to not break Windows during the process.

### Getting Linux WiFi Drivers Working on MSI Evo A13M
The onboard WiFi required additional drivers to work on Linux Mint 21.3, which is Ubuntu 22.04.1 under the hood.

First, the default Kernel requires upgrading. This may cause instability. Yet to notice any instability, and worth it for working WiFi. "

According to the Intel documentation, the required driver should work with the Kernel that Linux Mint 21.3 comes with. This was not found to be the case with the A13M's Wifi chipset.

#### With alternate Internet connection available on machine
The Kernel may be updated within the GUI. Open `Update Manager`, click `View` menu on toolbar and select `Linux Kernels`.  

Choose a Kernel `6.5.0` or above and click `Install`. This kernel version was selected being the highest supported at the time of writing. The drivers may work with lower Kernel versions, it did not work with the default `5.15`.

To use the newly installed Kernel, reboot and hold `Shift` during boot to bring up the GRUB Menu, select `Linux Mint 21.3 Advanced Options` and then select `Kernel Version 6.5.0-25`.

Once successfully using the new Kernel, [download Linux drivers from Intel (direct link)](https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-ty-59.601f3a66.0.tgz). 

There is a [compatibility table for the generic Intel drivers here](https://www.intel.com/content/www/us/en/support/articles/000088040/wireless.html). It indicates the `Intel® Wi-Fi 6E AX210 160MHz` drivers are suitable for the Prestige's `Intel® Killer™ AX Wi-Fi 6E AX1675` card. The direct download link was sourced from [this Intel article](https://www.intel.com/content/www/us/en/support/articles/000005511/wireless.html).

This set of commands will download the driver, extract it to the distro's firmware directory, and reload the Intel WiFi driver to get the newly added driver working.
```bash
cd ~
curl -O https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-ty-59.601f3a66.0.tgz
sudo tar -xvf iwlwifi-ty-59.601fa66.0.tgz --strip-components=1 -C /lib/firmware
sudo modprobe -r iwlwifi
sudo modprobe iwlwifi 
```

The WiFi should now work as needed.

#### With no alternate internet connection on machine (not documented)

This was not explored. 

In my case it was easier to find an alternate method to get Internet (e.g. wired ethernet + ethernet adapter, mobile phone Internet passthrough, or 4G USB Stick modem).

Would approach this by downloading the Kernel packages and Wifi driver on a computer with Internet and transferrring then installing.


### Other Installs
A list of other software installed directly after getting Linux working.

* Slimbook Battery for battery management
* CopyQ for clipboard history
* Chromium for alternate browser option

### Other Tweaks
#### Disable startup splash screen
```bash
sudo vi /etc/default/grub
```
Comment out GRUB_CMDLINE_LINUX_DEFAULT key/value pair, and add key with no value
```conf
#GRUB_CMDLINE_LINUX_DEFAULT="quiet splash" #Splash screen image
GRUB_CMDLINE_LINUX_DEFAULT=""
```