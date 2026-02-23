#H1 ontap_poller
This is a generic polling script for NetApp ONTAP systems, written in Powershell, and intended to be run on Windows utility hosts that are hosted close to the cluster management interfaces of NetApp ONTAP systems. 
This repo consists of the files:
- store_credential.ps1
- config.ini
- check_config.ps1
- poll_clusters.ps1
The initial code in the `poll_clusters.ps1` is set to poll point-in-time CIFS sessions and connections information from each filer in the `config.ini` file and stitch tegoether the output on a single line. 
#H2 Step one: store_credential.ps1
After downloading this project and copying the files onto your Windows utility host, run the `store_credential.ps1` script once for every unique service account credential that you intended to use for polling. This will store your username and password in a secure-string in the output file that you specify.
#H2 Step two: config.ini
Once credential information is stored, update the `config.ini` file.
1. Update the `common` section with the output CSV filename for the polling operations.
2. Create one new section for each cluster, specifying the FQDN or IP address of the cluster management interface of the cluster in the `ontap_cluster` field, and the relevant credential file in the `credential_file` field. You can reuse the existing exmples sections in the downloaded file.
#H2 Step three: Check config.ini syntax
Run the `check_config.ps1` script to make sure that the syntax of the config file is correct.
#H2 Step four: First run of the polling script
Run the `poll_clusters.ps1` script and make sure that an output CSV file is created. Log into the ONTAP clusters to verify that the output is roughly correct
#H2 Step five: Schedule the polling script to run
Set up a Windows Task Scheduler task to run the polling script at the desired interval.
#H2 TODO
- Logging
- Task scheduler job creation script
- Extensibility by plugin
