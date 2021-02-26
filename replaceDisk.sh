#!/bin/bash

sudo umount /media/*/*;
sudo mdadm /dev/md127 -r detached
sudo mdadm /dev/md127 -r failed

for i in $(lsblk -dp | grep -o '^/dev/sd[^ ]*'); do

    SerialReturn=$(udevadm info --query=all --name=$i | grep ID_SERIAL_SHORT;);
	SerialNo=$(cut -d "=" -f2 <<< $SerialReturn);
    SerialNo=${SerialNo//[^[:alnum:]]/};

    DiskSize=$(sudo blockdev --getsize64 $i);

    echo -e $i" | "$SerialNo" | "$DiskSize" | "$iPartName;

    diskFound=0
    input="serialList.dat"
    while IFS= read -r line
    do
        if [[ $line ]]
        then
            if [ "$line" = "$SerialNo" ]
            then
                diskFound=1
            fi
        fi
    done < "$input"


    if [ $diskFound -eq 1 ]
    then
        echo -e "\tDisk Found";
    else
        echo -e "\tDisk Not Found !!";
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
        sleep 1;
        PartName=$i"1"
        sudo mkfs.xfs -f $PartName;
        sudo mdadm --manage /dev/md127 --add $PartName
    fi

done

serialList=""
for i in $(lsblk -dp | grep -o '^/dev/sd[^ ]*'); do

    SerialReturn=$(udevadm info --query=all --name=$i | grep ID_SERIAL_SHORT;);
	SerialNo=$(cut -d "=" -f2 <<< $SerialReturn);
    SerialNo=${SerialNo//[^[:alnum:]]/};
    serialList=${serialList}$SerialNo"\n";

done

touch serialList.dat;
echo -e $serialList > serialList.dat;

echo "Disk configuration is completed."

echo ""
sudo ./hddTest.sh
