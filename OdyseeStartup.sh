#!/bin/bash

sudo apt-get -y install mdadm xfsprogs;

user=$(id -u -n);
group=$(id -g -n);

function goto
{
    label=$1
    cmd=$(sed -n "/^:[[:blank:]][[:blank:]]*${label}/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

start=${1:-"start"}

clear
: start
echo "Choose your new configuration of 5 disks";
echo " 1 ) Raid 6 (3D+2P)";
echo " 2 ) Raid 5 (4D+1P)";
echo " 3 ) Raid 0 (5D+0P) Danger-Loss of one disk will result in lost of all data in all disks";
echo " 4 ) No Raid";
echo " 5 ) Quit";
echo ""

read -p ' #? ' diskConf;

if [[ $diskConf ]] && [ $diskConf -eq $diskConf 2>/dev/null ] && [ $diskConf -lt 6 ]
then
    if [ $diskConf -eq 5 ]
    then
        echo " Disk configuration cancelled !";
        exit
    fi
else
    clear
    echo "\"$diskConf\" is not a valid choice !";
    goto "$start"
fi


echo -e "\n\nYou will loose all your data in disks. Do you wish to continue?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done
echo ""

diskList=""
serialList=""

sudo umount /media/*/*;
sudo umount /mnt/*;
sudo mdadm --stop /dev/md127;

for i in $(lsblk -dp | grep -o '^/dev/sd[^ ]*'); do

    SerialReturn=$(udevadm info --query=all --name=$i | grep ID_SERIAL_SHORT;);
	SerialNo=$(cut -d "=" -f2 <<< $SerialReturn);
    SerialNo=${SerialNo//[^[:alnum:]]/};
    serialList=${serialList}$SerialNo"\n";

    DiskSize=$(sudo blockdev --getsize64 $i);


    iPartName=$i"1"
    sudo mdadm --zero-superblock $iPartName;

    DiskSize=$(sudo blockdev --getsize64 $i);

    echo "";	
    echo -e $i"\t"$SerialNo"\t"$DiskSize;

    Limit=4000000000;
    if (($DiskSize < $Limit))
    then
            echo $i "disk size is "$DiskSize" byte. Less than required "$Limit "byte";
            continue;
    else
            echo $i "disk size is "$DiskSize" byte. More than  required "$Limit "byte";
    fi

    sudo sgdisk --zap-all $i;
    sudo sgdisk -n 1 $i;

    if [ $diskConf -eq 4 ]
    then
        echo $i " " $SerialNo;
        sudo mkfs.xfs -f $iPartName;

        sudo mkdir /mnt/$SerialNo;
	    sudo mount ${i}1 /mnt/$SerialNo;
	    sudo chmod 777 /mnt/$SerialNo;
        sudo chown -R $user:$group /mnt/$SerialNo;
        
        sudo sed -i "/\/dev\/md127.*/d" /etc/fstab;
        modifiedI=${i//\//\\\/};
        modifiedI=$modifiedI"1"
        echo $modifiedI;
        sudo sed -i "/$modifiedI.*/d" /etc/fstab;
        sudo echo -e "$iPartName  /mnt/$SerialNo  xfs defaults    0   0" | sudo tee -a /etc/fstab
    else
        modifiedI=${i//\//\\\/};
        sudo sed -i "/$modifiedI.*/d" /etc/fstab;
        diskList=${diskList}$i"1 ";
    fi

done

if [ $diskConf -lt 4 ]
then
    mountPoint="";
    if [ $diskConf -eq 1 ]
    then
        raidLevel=6;
        mountPoint="/mnt/Raid6Storage";
    elif [ $diskConf -eq 2 ]
    then
        raidLevel=5;
        mountPoint="/mnt/Raid5Storage";
    else
        raidLevel=0;
        mountPoint="/mnt/NoRaidStorage";
    fi
    sudo mdadm --create /dev/md127 --level=$raidLevel --raid-devices=5 $diskList;
    sudo mkfs.xfs -f /dev/md127;

    sudo mkdir -p $mountPoint;
    sudo chmod 777 $mountPoint;
    sudo chown -R $user:$group $mountPoint;

    sudo mount /dev/md127 $mountPoint;
    sudo chmod 777 $mountPoint;
    sudo chown -R $user:$group $mountPoint;

    sudo sed -i "/\/dev\/md127.*/d" /etc/fstab;
    sleep 1;
    sudo echo -e "/dev/md127  $mountPoint  xfs defaults    0   0" | sudo tee -a /etc/fstab;
    sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf;
    sudo update-initramfs -u;
    sudo reboot now;
fi

touch serialList.dat;
echo -e $serialList > serialList.dat;

echo "Disk configuration is completed."
