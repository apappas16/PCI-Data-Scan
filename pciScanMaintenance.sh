#!/usr/bin/env bash

# Contact Alexander Pappas for any questions/comments at apappas5@asu.edu
# @author Alexander Pappas

# This script runs on a given schedule to verify pciScan.sh is properly scanning log files once a day and archiving the
# resulting log files older than a week (NOTE: this can be modified to archive files older than any date that the
# owner specifies)

# TODO figure out generic location for where the report log files are stored

validated="false"
emailList=$1
archiveLocation=$2

function displayInstructions() {
  echo "*******************************************************************"
  echo "SYNOPSIS"
  echo "  pciScanMaintenance.sh [EMAIL_LIST] [ARCHIVE_LOCATION]"
  echo ""
  echo "DESCRIPTION"
  echo " pciScanMaintenance.sh verifies that the pciScan.sh script has been running daily every week."
  echo " It also archives the log result files that are older than a week."
  echo " The archived files go into the 'archive' folder in the same directory."
  echo ""
  echo " [EMAIL_LIST] - the email of the person to whom the results of the maintenance report will be sent to weekly."
  echo ""
  echo "EXAMPLES:"
  echo "Shedule run with cron:   call 'crontab -e' type 'i' to insert new text."
  echo " Type '0 1 * * 1 ~/bin/pciScanMaintenance.sh John.Smith@email.com'"
  echo " '0 1 * * 1' tells cron to execute the script at 1AM every Monday. This can be adjusted based on preference."
  echo "*******************************************************************"
}

function verifyPciScanIsRunning() {
  currentDate=$(date +%m-%d-%Y)
  echo "Verifying PCI Scan has been running..."
  for fileName in ~/bin/*; do
   if [[ $fileName == ~/bin/pci_scan_results_"$currentDate"* ]]; then
     validated="true"
   fi
 done;
}

function archiveOldLogFiles() {
  echo "Archiving old log files..."
  find ~/bin/*.log -mtime +7 -exec cp {} ~/"$1" \; -delete
}

function mailMaintenanceReport() {
  if [ $validated == "true" ]; then
    echo "pciScan.sh Validated Successfully"
    echo "pciScan.sh is running correctly and log files older than a week have been archived." | mail -s "Weekly PCI Scan Maintenance Report" "$1"
  else
    echo "pciScan.sh Might NOT Be Running Correctly"
    echo "pciScan.sh Might NOT Be Running Correctly. Check the server for more information." | mail -s "Weekly PCI Scan Maintenance Report" "$1"
  fi
}

#****************************************************
#check if email was provided
if [ -z "$emailList" ]; then
  displayInstructions
  exit 0
fi

#check if archive directory needs to be made
# shellcheck disable=SC2027
if [ ! -d "$HOME/$archiveLocation" ]; then
  echo "Creating archive Directory..."
  mkdir archive
fi

archiveOldLogFiles "$archiveLocation"
verifyPciScanIsRunning
mailMaintenanceReport "$emailList"
echo "Maintenance Scan Complete"
exit 0
