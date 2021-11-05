#!/bin/bash

serialListArr=()
echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|";
echo -e "|    Device\t|   Serial No\t|   Disk Size\t|  Partition\t|    File System Type\t| Size\t|     Used\t| Avail.|                   Mount Point";
echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|";
for i in $(lsblk -dp | grep -o '^/dev/sd[^ ]*'); do

    SerialReturn=$(udevadm info --query=all --name=$i | grep ID_SERIAL_SHORT;);
	SerialNo=$(cut -d "=" -f2 <<< $SerialReturn);
    SerialNo=${SerialNo//[^[:alnum:]]/};
    serialListArr+=($SerialNo)  

    DiskSize=$(sudo blockdev --getsize64 $i);

    for j in $(lsblk -p | grep -o $i'[^ ]'); do
            iPartName=$j;

            DiskFSTypeReturn=$(udevadm info  --query=all --name=$iPartName | grep ID_FS_TYPE;);
            DiskFSType=$(cut -d "=" -f2 <<< $DiskFSTypeReturn);

            
            output=$(df -h | grep $iPartName);
            IFS=" " read -ra arr <<< "$output";


            check=${#DiskFSType};
            if [ $check -gt 0 ];
            then
                check=${arr[1]};
                check=${#check};
                if [ $check -gt 0 ];
                then
                    echo -e "| "$i"\t| "$SerialNo"\t| "$DiskSize"\t| "$iPartName"\t|\t "$DiskFSType"\t\t| "${arr[1]}"\t| "${arr[2]}"("${arr[4]}")\t| "${arr[3]}"\t| "${arr[5]};
                    echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|";
                else
                    echo -e "| "$i"\t| "$SerialNo"\t| "$DiskSize"\t| "$iPartName"\t|\t "$DiskFSType"\t\t| Partition Not Mounted !"
                    echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|";
                fi
            else
                echo -e "| "$i"\t| "$SerialNo"\t| "$DiskSize"\t| "$iPartName"\t| The Volume Does Not Contain A Recognized File System !";
                echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|";
            fi


    done

done

echo -e "\n"
faultyDiskList=""
faultyDiskFound=1
input="serialList.dat"
while IFS= read -r line
do
    faultyDiskFound=1

    if [[ $line ]]
    then
        for iSerial in "${serialListArr[@]}"
        do
            if [ "$line" = "$iSerial" ];
            then
                faultyDiskFound=0;
                break;
            fi
        done

        if [ $faultyDiskFound -eq 1 ]
        then
            echo "Faulty Disk Found !   SerialNo : $line";
            faultyDiskList=${faultyDiskList}$line"\n";
        fi
    fi
    
done < "$input"

failedDiskFound=0;
IFS=$'\n' mdadmFaultyList=( $(mdadm --detail /dev/md127 | grep faulty) )
for mdadmFaultyLine in "${mdadmFaultyList[@]}"; do
    IFS='/' read -ra mdadmFaultyArr <<< "$mdadmFaultyLine"
    echo ${mdadmFaultyArr[2]};
    devDesc="/dev/"${mdadmFaultyArr[2]};
    SerialReturn=$(udevadm info --query=all --name=$devDesc | grep ID_SERIAL_SHORT;);
	SerialNo=$(cut -d "=" -f2 <<< $SerialReturn);
    SerialNo=${SerialNo//[^[:alnum:]]/};
    echo $SerialNo;
    faultyDiskList=${faultyDiskList}$SerialNo"\n";
    failedDiskFound=1;
done


if [ $failedDiskFound -eq 1 ];
then
	touch faultyDisks.dat;
	echo -e $faultyDiskList > faultyDisks.dat;
fi
