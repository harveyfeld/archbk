#!/usr/bin/env bash


# automated Arch Linux ARM install to target device
# target formatting, partitioning
# transfer rootfs, write kernel image
# optional - let's you keep arch tarball for later use
install_arch () {
  echo " "
  echo "enabling USB booting && booting of operating systems that aren't signed by google"
  crossystem dev_boot_usb=1 dev_boot_signed_only=0 2>/dev/null

  echo " "
  echo "1) unmounting target device"
  umount /dev/$media*
  
  fdisk /dev/$media <<EOF
  g
  w
EOF
  
  echo " "
  echo "2) creating GPT partition table with fdisk"
  cgpt create /dev/$media
  
  echo " "
  echo "3) creating kernel partition on target device"
  cgpt add -i 1 -t kernel -b 8192 -s 32768 -l Kernel -S 1 -T 5 -P 10 /dev/$media
  
  echo " "
  echo "4) calculating how big to make the root partition on target device, using information from cgpt show"
  sec="$(cgpt show /dev/$media | grep "Sec GPT table" | sed -r "s/\b[0-9]{1,3}\b[ a-Z]*//g" | sed "s/ //g")"
  
  sub=`expr $sec - 40960`
  
  echo " "
  echo "5) creating root partition on target device"
  c="$(echo "cgpt add -i 2 -t data -b 40960 -s XXXXX -l Root /dev/$media" | sed "s/XXXXX/$sub/")"
  
  eval $c
  
  echo " "
  echo "6) refreshing what the system knows about the partitions on target device"
  partx -a "/dev/$media"
  
  echo " "
  echo "7) formating target device root partition as ext4"
  mkfs.ext4 -F "/dev/$p2"
  
  echo " "
  echo "8) moving to /tmp directory"
  DIR="$(pwd)"
  cd /tmp
  
  if [ !$path ]; then
    path="/tmp/$ARCH"
    echo " "
    echo "9) downloading latest $ALARM tarball"
    rm -rf /tmp/*
    wget http://os.archlinuxarm.org/os/$ARCH
  fi
  
  echo " "
  echo "10) mounting root partition"
  mkdir root
  mount /dev/$p2 root/
  
  echo " "
  echo "11) extracting rootfs to target device root partition"
  tar -xf $path -C root/
  
  echo " "
  echo "12) writing kernel image to target device kernel partition"
  dd if=root/boot/vmlinux.kpart of=/dev/$p1
  
  echo " "
  echo "13) unmounting target device"
  umount root
  
  rm -rf root
  
  echo " "
  echo "syncing"
  sync
  
  echo " "
  echo "installation finished!"
  echo " "
  echo " "
  echo " "
  if [ -e "/tmp/$ARCH" ]; then
    read -p "would you like to keep $ARCH in your "Downloads" directory for future installs? [y/n] : " a
    if [ $a = 'y' ];
      then
        mv $ARCH $DIR/$ARCH
    fi
  fi
  cd $DIR
  echo " "
  echo " "
  echo " "
  echo " "
  if [ $media = "sda" ]; then
    echo "if you have your USB drive mounted in the blue USB 3.0 port,"
    echo "don't forget to plug the drive into the black USB 2.0 port before booting"
    echo "drives will not boot from the blue USB 3.0 port"
    echo " "
    echo " "
    read -p "poweroff the chromebook now? [y/n] : " b
    if [ $b = 'y' ]; then
      poweroff
    else
      echo " "
      echo "on boot, press ctrl+u to boot $ALARM."
      echo " "
      echo " "
    fi
  else
    read -p "reboot now? [y/n] : " c
    if [  $c = 'y' ]; then
      reboot
    fi
  fi
}

# confirms that only the install target device is connected
# stores appropriate device names, based on drive inserted (sda, mmcblk1, mmcblk1p2, ect)
init () {
  echo " " 1>&2
  echo "remove all devices (USB drives / SD cards / microSD cards), except for the device you want Arch Linux ARM installed on." 1>&2
  echo " " 1>&2
  echo "to safely remove a media storage device:" 1>&2
  echo "    1) go to files," 1>&2
  echo "    2) click the eject button next to the device you wish to remove," 1>&2
  echo "    3) unpug the device" 1>&2
  echo " " 1>&2
  echo " " 1>&2
  read -p "press any continue..." n
  
  count=0
  
  while [ $count -lt 1 ]
  do
    devices="$(lsblk -ldo NAME,SIZE 2> /dev/null | sed 's/^l.*$//g' | sed 's/^z.*$//g' |  sed 's/^mmcblk0.*$//g' | grep 'G' | sed "s/[ ]*[0-9]*\.[0-9]G$//g")"
    sizes="$(lsblk -ldo NAME,SIZE 2> /dev/null | sed 's/^l.*$//g' | sed 's/^z.*$//g' |  sed 's/^mmcblk0.*$//g' | grep "G" | sed "s/[a-z ]*//g")"
    
    for dev in $devices;
    do
      count=`expr "$count" + 1`
      media=$dev
    done
    
    if [ $count -gt 1 ];
      then
        echo "#############################################" 1>&2
        echo '# more than one install media was detected. #' 1>&2
        echo "#############################################" 1>&2
        echo " " 1>&2
        echo "Make sure that only one media storage device (USB drive / SD card / microSD card) is plugged into this device." 1>&2
        echo " " 1>&2
        echo " " 1>&2
        echo "to safely remove a media storage device:" 1>&2
        echo "    1) go to files," 1>&2
        echo "    2) click the eject button next to the device you wish to remove," 1>&2
        echo "    3) unpug the device" 1>&2
        echo " " 1>&2
        echo " " 1>&2
        read -p "press any key to continue..." n
        count=0
    elif [ $count -lt 1 ];
      then
        echo " " 1>&2
        echo "##################################" 1>&2
        echo '# no install media was detected. #' 1>&2
        echo "##################################" 1>&2
        echo " " 1>&2
        echo 'insert the media you want arch linux to be installed on,' 1>&2
        echo " " 1>&2
        echo " " 1>&2
        read -p "press any key to continue..." n
        count=0
    fi
  done

  echo " " 1>&2
  echo "****************" 1>&2
  echo "**            **" 1>&2
  echo "**  Warning!  **" 1>&2
  echo "**            **" 1>&2
  echo "****************" 1>&2
  echo " " 1>&2
  echo " " 1>&2
  echo "the device you entered will be formatted." 1>&2
  echo "all data on the device will be wiped," 1>&2
  echo "and Arch Linux ARM will be installed on this device." 1>&2
  echo " " 1>&2
  echo " " 1>&2
  read -p "do you want to continue with this install? [y/n] : " a
  if [ $a ]; then
    if [ $a = 'n' ]; then
      exit 1
    fi
  else
    continue
  fi
  
  if [ ${#media} -gt 3 ];
    then
      p1=$media"p1"
      p2=$media"p2"
  else
    p1=$media"1"
    p2=$media"2"
  fi
}

# gives user the option to skip download, if arch linux arm tarball is detected
have_arch () {
  # if Arch Linux tarball is found
  if [ -e $ARCH ]; then
    # ask user if they want to skip download of new tarball
    echo " "                                              1>&2
    echo "\"$ARCH\" was found"                            1>&2
    echo " "                                              1>&2
    read -p "install $ALARM without re-downloading? [y/n] : " a
    echo " "
    if [ $a ]; then
      if [ $a = 'y' ]; then
        echo "$ALARM will be installed from local \"$ARCH\"" 1>&2
        echo "$(pwd)/$ARCH"
      else
        echo " " 1>&2
        echo "Arch Linux ARM will be downloaded" 1>&2
      fi
    fi
  fi
}

# checks if arch linux arm download is possible
# loops until the user establishes internet connection, or quits
confirm_internet_connection () {
  
  # checks for a good ping to URL
  check_conn () {
    c="$(ping -c 1 $1 2>/dev/null | head -1 | sed 's/[ ].*//')"
    if [ $c ]; then
      echo "0"
    fi
  }
  
  while [ true ]
    do
    # try to connect to archlinuxarm.org
    if [ "$(check_conn 'archlinuxarm.org')" ]; then
      break
    # if connection was bad,
    else
      # try to connect to duckduckgo.com
      if [ "$(check_conn 'duckduckgo.com')" ]; then
        echo "failed to connect to archlinuxarm.org" 1>&2
        echo "site may be down" 1>&2
        echo "try again later" 1>&2
        exit 1
      # if both connections failed
      else
        clear
        echo " "
        echo "#################################################################" 1>&2
        echo " "                                                                 1>&2
        echo "ArchLinuxARM-peach-latest.tar.gz was not found in this directory," 1>&2
        echo "   and cannot be downloaded without an internet connnection"       1>&2
        echo " "                                                                 1>&2
        echo "           connect to the internet and try again."                 1>&2
        echo " "                                                                 1>&2
        echo "   **********************************************************"     1>&2
        echo "   ***   press enter to retry, or press q+enter to quit   ***"     1>&2
        echo "   **********************************************************"     1>&2
        echo " "                                                                 1>&2
        echo "#################################################################" 1>&2
        echo " "                                                                 1>&2
        read -p " " a
        if [ $a ]; then
          if [ $a = 'q' ]; then
            exit 1
          fi
        fi
      fi
    fi
  done
}


# looks for install tarball in current directory, sets path to tarball, if found
# checks for internet connection, if needed
essentials () {
  ARCH='ArchLinuxARM-peach-latest.tar.gz'
  ALARM='Arch Linux ARM'
  path="$(have_arch)"
  
  if [ !$path ]; then
    confirm_internet_connection
  fi
}

main () {
  essentials
  init
  install_arch
}

main