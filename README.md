# PCI-Data-Scan
Includes scripts that can be used to scan data in files and determine if there are visible credit card numbers.

NOTE: The instructions provided here will be for the default setup. Feel free to modify these instructions to fit your system the best!

# System Requirements
- Linux/Unix server with a command-line interface to execute bash commands
- A directory with at least 1 file to be scanned
- A user set up with proper access to location of files to scan
- MailUtils successfully installed and able to send emails in bash terminal
- A /var/tmp/ directory made in the server (this is where all files are copied to for scanning)

# Setup and Execution
1. Download or clone the files in the repository
2. Navigate to the /var/tmp/ directory on the server and create a "files-to-scan" directory with mkdir command
3. Save a copy of the files to the ~/bin/ directory on the server you're using (if this directory doesn't exist, create it with mkdir command)
4. Run 'chmod 755 fileName' with both pciScan.sh and pciScanMaintenance.sh (as the fileName) to make them executable
5. Run manually: 
    <br/>5a. Run command "./pciScan.sh /full/path/to/files/to/scan/ emailToSendResultsTo" but the first and second parameters are the actual values
    <br/>5b. Wait for the script to complete. "PCI Scan Completed" should be printed last to the terminal
    <br/>5c. Type "ls" in the terminal and a file names pci_scan_results_date_time.log should exist.

6. Run with cron (automatically):
    <br/>6a. Type "crontab -e"
    <br/>6b. If first time running crontab command follow instructions printed to set it up
    <br/>6c. Once taken inside the cron file, type "i" to edit ("INSERT" should appear at the bottom left of the screen)
    <br/>6d. Type "0 0 * * * ~/bin/pciScan.sh /full/path/to/files/to/scan/ emailToSendResultsTo" (See this site for a tutorial on cron: https://www.hostinger.com/tutorials/cron-job)
    <br/>6e. Type "0 1 * * 1 ~/bin/pciScanMaintenance.sh emailToSendResultsTo"
    <br/>6f. Type ":wq" to save and quit
    <br/>6g. Verify pciScan.sh ran sometime after it was scheduled to run by checking if its pci_scan_result_date_time.log is in the directory 
    <br/>6h. Verify pciScanMaintenance.sh ran sometime after it was scheduled to run by checking if an email was received of the report
