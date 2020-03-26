#!/usr/bin/env bash
#***************************************************************************************
# Copyright (c) 2019 Choice Hotels International. All Rights Reserved.
#***************************************************************************************

#Contact Test OPs for any questions/comments
# @author alexander_pappas

#This script pulls all logs files from any given file location, scans them for credit card numbers,
#and reports out which files do or do not have active credit card numbers in them

datetime=$(date +%m-%d-%Y_%H.%M.%S)
hostName=$(hostname)
pciScanReport="$HOME/bin/pci_scan_results_$datetime.log"
tempDirectory="/var/tmp/files-to-scan/"
directoryToScan="NOT/A/VALID/DIRECTORY"
reportResults="false"
emailList=""

function displayInstructions() {
  echo "***************************************************************************"
  echo "SYNOPSIS"
  echo "  pciScan.sh [OPTION] [DIRECTORY] [EMAIL_LIST]"
  echo ""
  echo "DESCRIPTION"
  echo "  pciScan.sh scans all of the .log files in a provided directory for potential credit card numbers."
  echo ""
  echo "  NOTE: pciScan.sh only scans .log files modified in the last 24 hours since it runs daily."
  echo "  For the first time this actually runs on any server, the script should be editted to find every .log file."
  echo "  To do this, remove the '-mtime -1' from the first find statement in the scanDirectory function."
  echo "  Then after the first scan is completed, add it back in."
  echo ""
  echo "  The following is an OPTIONAL argument:"
  echo "  -r   indicates results should be reported to the qaawebtester database. This option should be ignored for test runs."
  echo ""
  echo "  [DIRECTORY] - the full path of the directory to be scanned (/opt/choice/logs/)."
  echo "  [EMAIL_LIST] - the email of the person to whom the results will be sent if potential credit card numbers are found."
  echo ""
  echo "EXAMPLES: "
  echo ""
  echo " Manually:   ./pciScan.sh /opt/choice/logs/ John.Smith@choicehotels.com"
  echo " Calling 'ls' should display a file called pci_scan_results_timestamp-when-script-was-executed.log"
  echo " Calling 'cat pci_scan_results_timestamp-when-script-was-executed.log' should display logging results for each file scanned."
  echo " Make sure to save the script in the /home/bin directory for cis_test_automation."
  echo ""
  echo " Schedule run with cron:   call 'crontab -e' type 'i' to insert new text."
  echo " Type 0 0 * * * ~/bin/pciScan.sh -r /opt/choice/logs/ Jane.Smith@choicehotels.com"
  echo " '0 0 * * *' tells cron to execute the script at midnight every day. This can be adjusted to whatever the user wants."
  echo " NOTE: The user will only receive an email if the script finds potential credit card numbers."
  echo " Double check that cron is working by inputting a time it should run and calling 'ls'. "
  echo " to see if a pci_scan_results_timestamp-when-script-was-executed.log is stored with the scheduled time."
  echo "***************************************************************************"
}

if [ "$1" == "-r" ]; then
  reportResults="true"
  directoryToScan=$2
  emailList=$3
else
  directoryToScan=$1
  emailList=$2
fi

if [ -z "$directoryToScan" ]; then
  displayInstructions
  exit 0
fi

function removeTempDirectory() {
  rm -r $tempDirectory
}

function emailPCIScanResults() {
  if [ -n "$emailList" ]; then
    echo "" | mail -s "Potential Credit Card Numbers Found" -a "$pciScanReport" "$1"
  fi
}

function reportScanResults() {
  fileName=$1
  hasCCData=$2
  maskedCards=$3

  if [ $reportResults == "true" ]; then
    echo Sending Results To QaaWebtester Database...
    curl --data "serverName=$hostName&fileName=$fileName&hasCCData=$hasCCData&maskedCards=$maskedCards" http://qaawebtester.chotel.com/api/addPCILogResult.ashx
  fi
}

function displayResults() {
  if grep '\[LOG_ERROR\]' "$pciScanReport"; then
    echo Test Failed. Credit Card Data Was Found. Check pci_scan_results_timestamp.log For Info.
    emailPCIScanResults "$1"
  else
    echo Test Completed Successfully. NO Credit Card Data Found Across All Log Files.
  fi
}

function scanDirectory() {
  mkdir $tempDirectory
  echo Finding logs...

  find "$directoryToScan" -type f -mtime -1 -exec cp {} $tempDirectory \;

  find $tempDirectory*.log -type f | while read -r fileName; do
    hasCCData="false"
    listOfMaskedCardsPerFile=""
    #13 Digit Visa Scan
    if grep -E -n '[^\.]\b4[0-9]{12}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b4[0-9]{8}/*********/g' "$pciScanReport"
      echo -e "[LOG_ERROR] 13 Digit Visa Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No 13 Digit Visa Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #16 Digit Visa Scan
    if grep -P -n '[^\.]\b4[0-9]{12}(\d{3,6})\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b4[0-9]{11}/************/g' "$pciScanReport"
      echo -e "[LOG_ERROR] 16 Digit Visa Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No 16 Digit Visa Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #Mastercard Scan
    if grep -P -n '[^\.]\b(?:5[1-5]\d{2}|222[1-9]|22[3-9]\d|2[3-6]\d{2}|27[01]\d|2720)\d{12}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b(5[1-5][0-9]{2}|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720)[0-9]{8}/************/g' "$pciScanReport"
      echo -e "[LOG_ERROR] Mastercard Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No Mastercard Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #Amex Data
    if grep -P -n '[^\.]\b3[47][0-9]{13}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b3[47][0-9]{9}/************/g' "$pciScanReport"
      echo -e "[LOG_ERROR] Amex Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No Amex Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #Discover Scan
    if grep -P -n '[^\.]\b6(?:011|5[0-9]{2})[0-9]{12,15}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b6[0-9]{11}/************/g' "$pciScanReport"
      echo -e "[LOG_ERROR] Discover Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No Discover Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #JCB Scan
    if grep -P -n '[^\.]\b(?:2131|1800|35\d{3,6})\d{11}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b35[0-9]{10}/************/g' "$pciScanReport"
      echo -e "[LOG_ERROR] JCB Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No JCB Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    #Diners Club Scan
    if grep -P -n '[^\.]\b3(?:0[0-5]|[68][0-9])[0-9]{11}\b(?![\]])' "$fileName" >>"$pciScanReport"; then
      sed -i -E 's/\b3(0[0-5]|[68][0-9])[0-9]{7}/**********/g' "$pciScanReport"
      echo -e "[LOG_ERROR] Diners Club Data In File: " "$fileName\n\n" >>"$pciScanReport"
      hasCCData="true"
    else
      echo -e "[LOG_INFO] No Diners Club Data Found In " "$fileName\n" >>"$pciScanReport"
    fi

    reducedFileName=${fileName#*scan/}
    if [ $hasCCData == "true" ]; then
      listOfMaskedCardsPerFile=$(grep -P -o '[\*]{9,13}[0-9]{4}\b' "$fileName")
    fi
    reportScanResults "$reducedFileName" $hasCCData "$listOfMaskedCardsPerFile"
  done
  removeTempDirectory
}

# **********************************************************
scanDirectory
displayResults "$2"

echo PCI Scan Completed
exit 0
