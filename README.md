# New-AzureSPFarmEasier
Creates a New SharePoint Farm in Azure easier
Follow the instructions to have a fully deployed and configured SharePoint 2013 farm hosted in Windows Azure

1. Run the New-AzureSPFarmEasier.ps1 powershell script from an Azure Powershell console. Follow the steps as indicated in the prompts.
2. Go to the [Azure Portal] (http://portal.azure.com), Log in 
  3.   Select each VM that was created
  4.   Click `Connect` to download the Remote Deskop (RDP) files for each VM.
5. Using the RDP files downloaded, log in to each VM and Open the Storage Management console [Azure Documentation Reference] (https://azure.microsoft.com/en-us/documentation/articles/storage-windows-attach-disk/) Note: The screenshots may be different from the version of Windows Server you have chosen, but the steps are the same
  6.  Initialize the additional disk(s)
  7.  Format the disk(s) and name it
  8.  Assign drive letters to each disk. 
9. Run `Windows Update` and apply available updates to each VM. You may need to reboot and re-run `Windows Update` several times to get all the latest patches applied.
10. [Download Google Chrome] (https://www.google.com/intl/en/chrome/browser/desktop/index.html) to each VM and install. This will allow the downloading of software ISOs needed in the isolated VM environment without hitting the security warnings from Internet Explorer.
11. [Download Virtual CloneDrive] (http://www.slysoft.com/en/download.html) and install. This will allow the "loading" of software ISOs into virtual drives if using Windows Server 2008 R2 or previous.
12. Configure the VM delegated as the Domain Controller (DC) and add user accounts for SQLService, SPFarm, SPAdmin. [Reference here] (https://azure.microsoft.com/en-us/documentation/articles/active-directory-new-forest-virtual-machine/) for steps to configuring a new domain within the Azure environment as there are some specific steps regarding DNS that are unique when compared to deploying a DC in an on-premises network.
13. Log in to the VMs delegated as the SQL Server and the SharePoint Server and join each VM to the new domain that was created.
14. Add SPAdmin to Administrators group on local computers for SQLServer, SPServer
15. Log in to SQLServer as SPAdmin, configure the firewall for SQL Server (Incoming Port 1433). [Reference Microsoft documentation here] (https://msdn.microsoft.com/en-us/library/cc646023.aspx) for further details and methods for doing so.	Note, ensure that the port for SQL Server is open for both "Domain" and "Private" networks
16. Logged in to the SQL Server VM as `SPAdmin`, open the SQL Server ISO file if downloaded using Virtual CloneDrive, and run `setup` for SQL Server installation and start a new installation of SQL Server
  17. Select *only* "Database Services" and "Client Tools" (Basic and Advanced) from SQL Server Feature list
  18. Set collation to Latin_General_CI_AS_KS_WS
  19. Set Data Directories to point to different physical partitions for SQL Server Data and Log files
  20. Save the configuration file, stored somewhere like `C:\Program Files\Microsoft SQL Server\110\Setup Bootstrap\Log\20150818_101753\ConfigurationFile.ini`.
  21. Cancel the installation, and then run the installation using this configuration file (this confirms the file is configured correctly in case additional servers are to be configured for SQL Server). See [Microsoft Technet Reference Documentation] (https://technet.microsoft.com/en-us/library/dd239405(v=sql.110).aspx) for more details.
  22. Open SQL Server Management Studio
  23. Set `Max Degrees of Parallelism` to `1`, restart server. This can be set either through the Properties window for the SQL Server or via the stored procedure. See [Microsoft Technet Reference Documentation] (https://technet.microsoft.com/en-us/library/ms181007(v=sql.105).aspx) for further details.
  24. Add `SPFarm` account to `Security-->Logins` and assign server roles `dbcreator` and `securityadmin`. Note: This step is optional, SharePoint 2013 Setup will assign these permissions automatically when running the Product Configuration Wizard
  25. Add `Spadmin` account to `Security-->Logins`, assign server roles `dbcreator` and `securityadmin`. Note: Some IT Security Professionals may argue that SQL Server should not have been installed as `SPAdmin` under [the principle of least privilege] (https://en.wikipedia.org/wiki/Principle_of_least_privilege), but since SQL Server is supposed to be **dedicated** to SharePoint Server and not used for hosting other software databases, I'm not sure the value of using this approach here, which is the typical best practice, as the tradeoff to following the principle of least privilege here is the risk increases in future of hitting *permissions* issues that might need troubleshooting during subsequent SharePoint 2013 CU, PU or SP software patch installation. 
26. Log on to the SharePoint Server VM as SPAdmin. If opening the SharePoint installation from an ISO that has been loaded in Virtual CloneDrive, copy the files from the virtual drive to a local folder before continuing (this will prevent an error message on reboot when the virtual CD drive isnt loaded and it tries to continue).
	22. Run the pre-requisite installer file. Follow instructions as documented by [Microsoft Technet] (https://technet.microsoft.com/en-us/library/cc262243.aspx)
	23. Install hotfixes in the following order: `Windows6.1-KB2554876-V2-x64`, `Windows6.1-KB2708075-x64`, `NDP45-KB2759112-x64` (may say "does not apply" when run), `Windows8-RT-KB276317-x64` (may say "does not apply" when run)
	24. Run setup.exe from SharePoint 2013 installation folder
	25. Set installation and search index directories to Data partition
	26. Set connection to SQL Server to SPFarm account
	27. Specify port number as 2013
	28. Run Product Configuration Wizard to configure the connection to SQL Server and build the initial database tables for SharePoint 2013.
	28. Apply the appropriate SharePoint Server March Public Update according to [TechNet Blog documentation]. (http://blogs.technet.com/b/wbaer/archive/2013/05/09/sharepoint-server-2013-march-2013-public-update.aspx) Please note the steps on which services need to be stopped *before* the application of the SharePoint update files.
	29. Confirm the farm is successfully working by starting and running SharePoint Central Administration in a web browser.
