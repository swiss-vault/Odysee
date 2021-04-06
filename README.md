# Odysee

**For Initial Setup :**
$ git clone https://github.com/swiss-vault/Odysee
$ cd Odysee
$ sudo ./OdyseeStartup.sh
      - Select Raid Type
      - Confirm
Note 1 : It will configure RAID and generate "serialList.dat" which includes serial numbers of disks installed. Please do not modify or delete the serial list file.
Note 2 : MDADM needs about 3 days to rebuild the spare disk. If user lose any disk during this time, RAID will fail.

**For HDD Test :**
Put "hddTest.sh" into crontab to run periodically and it will generate a "faultyDisks.dat" file that includes the missing HDD serial number in ASCII format.

**For Rebuilding :**
$ sudo ./replaceDisk.sh
      Run this script after replacing the faulty disk. New disk will be added to RAID array and missing one will be removed from RAID array.
