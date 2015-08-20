#Author: Nissan Dookeran
#Date: 20-Aug-2015
#Problem: While there is an automated deployment for SharePoint 2013 farm
#It will create a SP2013 SP1 farm.
#For testing purposes, e.g. in testing a backup and restore from an older environment, a farm needs to be created that is running SharePoint 2013 prior to SP1, which this script
#Will help accelerate the creation of the VMs for
#Solution: This script will create the VMs ONLY for a new SharePoint farm consisting of
#One Windows Server 2008 R2 server to be configured as DC
#One Windows Server 2008 R2 server to be configured as SQL Server
#One Windows Server 2008 R2 server to be configured as SharePoint Server (WFE/App)
#Script does not include installation or configuration of VMs as DC, SQL or SP servers. See attached documentation for these steps
#Script can be repurposed to configure any number of machines that need to be spun up as part of the same Virtual Network
#
#References: 
#See documentation attached in Readme.MD, but the script itself relied heavily on various documentation from https://azure.microsoft.com/en-us/documentation/services/virtual-machines/
#Set-InfotechAzureSubscription.ps1 - Step 1 is a cut and paste of this code also available at https://github.com/nissan/Set-AzureSubscriptionEasier
#

#Step 1: Ensure authenticated to Azure and current subscription is set correctly
$cacct=Read-Host 'Enter 1 to add an Azure account, or press Enter to continue with current account'
if ($cacct -eq 1)
{
  Add-AzureAccount
}
Write-Host 'Current Development environment is:'
Get-AzureSubscription -Current | Select SubscriptionName, SupportedModes, DefaultAccount | Format-Table

$csubscr=Read-Host 'Enter 1 to change, or press Enter to continue with current Subscription'
if ($csubscr -eq 1)
{
  Write-Host 'All available Azure Subscriptions are: '
  Get-AzureSubscription | Sort SubscriptionName | Select SubscriptionName, DefaultAccount | Format-Table
  #, DefaultAccount | Format-Table
  Write-Host '---------------------------------------------'
  $subscr= Read-Host 'What is the Azure Subscription Name to use' #"Infotech Demo and Development Environment"
  Select-AzureSubscription -SubscriptionName $subscr -Current
  Write-Host 'Current Development environment is now set to:'
  Get-AzureSubscription -Current | Select SubscriptionName, SupportedModes | Format-Table
}

#Step 2: Switch to Azure Resource Manager mode and set the name of the resource group and the location for the target VMs
Switch-AzureMode AzureResourceManager
$rgName= Read-Host 'Enter Resource Group Name, e.g. DemoResourceGroup1' #Resource Group Name
#To get a list of available locations where VMs can run execute following lines
Write-Host 'Current list of available Azure locations for Virtual Machines are:'
$loc = Get-AzureLocation | where { $_.Name -eq "Microsoft.Compute/virtualMachines" }
$loc.Locations
$locName= Read-Host 'Enter Azure location for placement of Virtual Machines created e.g. East US' #Location Name
#Create the resource group
Write-Host "Creating the resource group $rgName in location $locName" -foregroundcolor green
New-AzureResourceGroup -Name $rgName -Location $locName |Format-Table

#Step 3: Set the storage account to be used for storage of VM disks, ensure it is globally unique
$stacct = Get-AzureStorageAccount | Sort Name | Select Name, Label | Format-Table
Switch-AzureMode AzureServiceManagement
$stacctsm = Get-AzureStorageAccount | Sort Name | Select Name, Label | Format-Table
Write-Host 'Currently deployed storage accounts are:'
$stacctsm
$stacct
Do
{
  $saProposedName = Read-Host 'Enter proposed name for Storage Account (must be globally unique, lowercase letters, numbers and symbols only, must start and end with a number or letter) e.g. demo_storage_account1'
  $isNameTaken = Test-AzureName -Storage $saProposedName
} While ($isNameTaken -eq $true)


# make sure to switch back to Resource Manager mode
Switch-AzureMode AzureResourceManager
$saName=$saProposedName #Storage Account Name

# Storage account types are one of: "Standard_LRS", "Standard_GRS", "Standard_RAGRS", "Premium_LRS"
do 
{
  $saType=Read-Host 'Enter storage account type, storage account types are one of "Standard_LRS", , "Standard_GRS", "Standard_RAGRS", "Premium_LRS"' #Storage Account Type
} while ($saType -ne 'Standard_LRS' -and $saType -ne 'Standard_GRS' -and $saType -ne 'Standard_RARGS' -and $saType -ne 'Premium_LRS') 

#Create the storage account
Write-Host "Creating storage account $saName of type $saType in Resource Group $rgName at location $locName" -foregroundcolor green
New-AzureStorageAccount -Name $saName -ResourceGroupName $rgName -Type $saType -Location $locName |Format-Table

#Set the names for the availability sets
#List existing availability sets with Get-AzureAvailabilitySet -ResourceGroupName $rgName | Sort Name | Select Name
#ensure there are no naming conflicts with chosen names for $avADName
$avADName=Read-Host 'What is the Availability Set Name to use for the Active Directory Server VMs? e.g. DemoADAvailabilitySet1' #Availability set for AD servers
$avSQLName= Read-Host 'What is the Availability Set Name to use for the SQL Server VMs e.g. DemoSQLAvailabilitySet1' #Availability set for SQL Servers
$avSPName= Read-Host 'What is the Availability Set Name to use for the SP2013 Server VMs e.g. DemoSPAvailabilitySet1' #Availability set for SharePoint Servers

#Set the virtual network name and the subnet names and ranges
#List existing virtual networks with 
#Get-AzureVirtualNetwork -ResourceGroupName $rgName | Sort Name | Select Name
#ensure there are no naming conflicts with chosen $vnetName value
$frontendSubnet=New-AzureVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix 10.0.1.0/24
$backendSubnet=New-AzureVirtualNetworkSubnetConfig -Name backendSubnet -AddressPrefix 10.0.2.0/24
Write-Host 'Existing virtual network names are:'
Get-AzureVirtualNetwork -ResourceGroupName $rgName | Sort Name | Select Name | Format-Table
Write-Host 'Ensure there are no naming conflicts with the chosen VNet name before entering'
$vnetName=Read-Host 'What is the Virtual Network name to use all VMs? e.g. DemoVNet1'
Write-Host 'Two subnets have been automatically created: frontendSubnet with AddressPrefix 10.0.1.0/24 and backendSubnet with AddressPrefix 10.0.2.0/24'





#Create the Availability sets
New-AzureAvailabilitySet -Name $avADName -ResourceGroupName $rgName -Location $locName
New-AzureAvailabilitySet -Name $avSQLName -ResourceGroupName $rgName -Location $locName
New-AzureAvailabilitySet -Name $avSPName -ResourceGroupName $rgName -Location $locName

#Create the virtual network, attach the subnets
Write-Host 'Virtual network will be created with AddressPrefix 10.0.0.0/16 and subnets frontendSubnet, backendSubnet'
New-AzurevirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Location $locName -AddressPrefix 10.0.0.0/16 -Subnet $frontendSubnet,$backendSubnet

#Run
#Get-AzureVirtualNetwork -Name $vnetName -ResourceGroupName $rgName | Select Subnets
#Count list of names from left to right, starting at 0 to get the index of the subnet name
#Need to get index for subnets, assuming 0 for frontendSubnet, 1 as index for backendSubnet
Get-AzureVirtualNetwork -Name $vnetName -ResourceGroupName $rgName | Select Subnets

##################################################################################################
#Create VM for a AD DC, this is setup as one with the Static IP
$subnetIndex=1 #create this in the backendSubnet
$vnet=Get-AzureVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$nicNameAD=Read-Host 'What is the NIC Name to use for the AD Server VM NIC? e.g. DemoDCNIC1'
$staticIPAD=Read-Host 'What is the Fixed IP to use for the AD Server VM? e.g. 10.0.2.4'
$pipAD = New-AzurePublicIPAddress -Name $nicNameAD -ResourceGroupName $rgName -Location $locName -AllocationMethod Dynamic
$nic = New-AzureNetworkInterface -Name $nicNameAD -ResourceGroupName $rgName -Location $locName -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pipAD.Id -PrivateIpAddress $staticIPAD
#Create the VM
$vmNameAD= Read-Host 'What is the Name to use for the AD Server VM? e.g. DemoDC1'
#Get List of available vmSize run Get-AzureVMSize -Location $locName | Select Name
Write-Host 'Currently available VM sizes are:'
Get-AzureVMSize -Location $locName | Sort Name| Select Name | Format-Table
$vmSizeAD=Read-Host 'What size VM should be created for the AD VM? e.g. Standard_A0'
$avADSet=Get-AzureAvailabilitySet -Name $avADName -ResourceGroupName $rgName
$vm=New-AzureVMConfig -VMName $vmNameAD -VMSize $vmSizeAD -AvailabilitySetId $avADset.Id
#Create the AD SysVol disk
Write-Host 'Configure the disk volume to be created for storing AD data:'
$diskSizeADSysVol= Read-Host 'What disk size should be created (in GB)? e.g. 50' 
$diskLabelADSysVol=  Read-Host 'What label should be given to this disk? e.g. ADSysVol'
$diskNameADSysVol= Read-Host 'What name should be given to this disk? e.g. DemoDC-disk2'
$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameAD + $diskNameADSysVol + ".vhd"
Write-Host "Creating the $diskLabelADSysVol disk of size $diskSizeADSysVol GB for $vmNameAD at $vhdURI..." -foregroundcolor Green
Add-AzureVMDataDisk -VM $vm -Name $diskLabelADSysVol -DiskSizeInGB $diskSizeADSysVol -VhdUri $vhdURI -LUN 0 -CreateOption empty
Write-Host 'Disk creation completed' -foregroundcolor Green

#To get the SKU to use for the VM
#Get-AzureVMImagePublisher -Location $locName | Select PublisherName
#$pubName="<publisher>"
#Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer
#$offerName="<offer>"
#Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus
#$skuName="<skuName>"
Write-Host 'Available VM Image Publishers are:'
Get-AzureVMImagePublisher -Location $locName | Sort PublisherName | Select PublisherName | Format-Table
$pubName= Read-Host 'What VM Image Publisher should be used? e.g. MicrosoftWindowsServer'

Write-Host 'Available offers for this image are:'
Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer | Format-Table
$offerName= Read-Host 'Which offer should be used for this image? e.g. WindowsServer'

Write-Host 'Available SKUs are:'
Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Sort Skus | Select Skus | Format-Table
$skuName=Read-Host 'Which SKU should be used? e.g. 2008-R2-SP1'

$cred=Get-Credential -Message "Type the name and password of the local administrator account"
$vm=Set-AzureVMOperatingSystem -VM $vm -Windows -ComputerName $vmNameAD -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm=Set-AzureVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm=Add-AzureVMNetworkInterface -vm $vm -ID $nic.Id
$OSdiskName=Read-Host 'What name should be given to the OS disk? e.g. DemoDCOSDisk'
$storageAcc=Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString()+"vhds/"+$OSdiskName+".vhd"
$vm=Set-AzureVMOSDisk -VM $vm -Name $OSdiskName -VhdUri $osDiskUri -CreateOption fromImage
Write-Host 'Creating the AD VM...' -foregroundcolor Green
New-AzureVM -ResourceGroupName $rgName -Location $locName -VM $vm
Write-Host "Completed creation of the AD DC VM" -foregroundcolor Green
#End Create the AD DC
##################################################################################################

##################################################################################################
#Create VM for SQL Server
Write-Host "Starting creation of the SQL Server VM" -foregroundcolor Green
$subnetIndex=1 #create this in the backendSubnet
$vnet=Get-AzureVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$nicNameSql= Read-Host 'What is the NIC Name to use for the Sql Server VM NIC? e.g. DemoSQLNIC1'
#Public domain name label
#Test the DNS availability by running 
#Test-AzureDnsAvailability -DomainQualifiedName $domName -Location $locName
$domNameSql= Read-Host 'What is the domain name for the SQL Server VM? e.g. demosql1'
$pipSql = New-AzurePublicIpAddress -Name $nicNameSql -ResourceGroupName $rgName -DomainNameLabel $domNameSql -Location $locName -AllocationMethod Dynamic
$nicSql = New-AzureNetworkInterface -Name $nicNameSql -ResourceGroupName $rgName -Location $locName -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pipSql.Id
$vmNameSql= Read-Host 'What is the Name to use for the SQL Server VM? e.g. DemoSQL1'
Write-Host 'Currently available VM sizes are:'
Get-AzureVMSize -Location $locName | Sort Name| Select Name | Format-Table
$vmSizeSql=Read-Host 'What size VM should be created for the SQL VM? e.g. Standard_A1'
$avSqlSet=Get-AzureAvailabilitySet -Name $avSQLName -ResourceGroupName $rgName
$vmSql=New-AzureVMConfig -VMName $vmNameSql -VMSize $vmSizeSql -AvailabilitySetId $avSqlSet.Id
#Create the SQL Data disk
Write-Host 'Configure the disk volume to be created for storing SQL Server data files:'
$diskSizeSQLDataVol= Read-Host 'What disk size should be created (in GB)? e.g. 250'  
$diskLabelSQLDataVol= Read-Host 'What label should be given to this disk? e.g. SQLData'
$diskNameSQLDataVol= Read-Host 'What name should be given to this disk? e.g. DemoSql-disk2'
$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameSQL + $diskNameSQLDataVol + ".vhd"
Write-Host "Creating the $diskLabelSQLDataVol disk of size $diskSizeSQLDataVol GB for $vmNameSql at $vhdURI..." -foregroundcolor Green
Add-AzureVMDataDisk -VM $vmSql -Name $diskLabelSQLDataVol -DiskSizeInGB $diskSizeSQLDataVol -VhdUri $vhdURI -LUN 0 -CreateOption empty
Write-Host 'Disk creation completed' -foregroundcolor Green

#Create the SQL Log disk
Write-Host 'Configure the disk volume to be created for storing SQL Server log files:'
$diskSizeSQLLogVol= Read-Host 'What disk size should be created (in GB)? e.g. 100'  
$diskLabelSQLLogVol= Read-Host 'What label should be given to this disk? e.g. SQLLog'
$diskNameSQLLogVol= Read-Host 'What name should be given to this disk? e.g.DemoSql-disk3'
$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameSQL + $diskNameSQLLogVol + ".vhd"
Write-Host "Creating the $diskLabelSQLLogVol disk of size $diskSizeSQLLogVol GB for $vmNameSql at $vhdURI..." -foregroundcolor Green
Add-AzureVMDataDisk -VM $vmSql -Name $diskLabelSQLLogVol -DiskSizeInGB $diskSizeSQLLogVol -VhdUri $vhdURI -LUN 1 -CreateOption empty
Write-Host 'Disk creation completed' -foregroundcolor Green

####Ideally there should be separate disks for TempDB database and log files, but Azure VMs limit number of attachable VMs to 2, so this won't work.
#Create the SQL TempDB Log disk
#Write-Host 'Configure the disk volume to be created for storing SQL Server TempDB log files'
#$diskSizeSQLTempDBLogVol= Read-Host 'What disk size should be created (in GB)? e.g. 10' 
#$diskLabelSQLTempDBLogVol= Read-Host 'What label should be given to this disk? e.g. SQLTempDBLog'
#$diskNameSQLTempDBLogVol= Read-Host 'What name should be given to this disk? e.g.DemoSql-disk4'
#$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
#$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameSQL + $diskNameSQLTempDBLogVol + ".vhd"
#Write-Host 'Creating the $diskLabelSQTempDBLogVol disk of size $diskSizeSQLTempDBLogVol GB for $vmNameSql at $vhdURI...' -foregroundcolor Green
#Add-AzureVMDataDisk -VM $vmSql -Name $diskLabelSQLTempDBLogVol -DiskSizeInGB $diskSizeSQLTempDBLogVol -VhdUri $vhdURI -CreateOption empty
#Write-Host 'Disk creation completed' -foregroundcolor Green

#Create the SQL TempDB Data disk
#Write-Host 'Configure the disk volume to be created for storing SQL Server TempDB data files'
#$diskSizeSQLTempDBDataVol= Read-Host 'What disk size should be created (in GB)? e.g. 50' 
#$diskLabelSQLTempDBDataVol= Read-Host 'What label should be given to this disk? e.g. SQLTempDBData'
#$diskNameSQLTempDBDataVol= Read-Host 'What name should be given to this disk? e.g. DemoSql-disk5'
#$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
#$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameSQL + $diskNameSQLTempDBDataVol + ".vhd"
#Write-Host 'Creating the $diskLabelSQTempDBDataVol disk of size $diskSizeSQLTempDBDataVol GB for $vmNameSql at $vhdURI...' -foregroundcolor Green
#Add-AzureVMDataDisk -VM $vmSql -Name $diskLabelSQLTempDBDataVol -DiskSizeInGB $diskSizeSQLTempDBDataVol -VhdUri $vhdURI -CreateOption empty
#Write-Host 'Disk creation completed' -foregroundcolor Green

#To get the SKU to use for the VM
#Get-AzureVMImagePublisher -Location $locName | Select PublisherName
#$pubName="<publisher>"
#Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer
#$offerName="<offer>"
#Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus
#$skuName="<skuName>"
Write-Host 'Available VM Image Publishers are:'
Get-AzureVMImagePublisher -Location $locName | Sort PublisherName | Select PublisherName | Format-Table
$pubName= Read-Host 'What VM Image Publisher should be used? e.g. MicrosoftWindowsServer'

Write-Host 'Available offers for this image are:'
Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer | Format-Table
$offerName= Read-Host 'Which offer should be used for this image? e.g. WindowsServer'

Write-Host 'Available SKUs are:'
Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Sort Skus | Select Skus | Format-Table
$skuName=Read-Host 'Which SKU should be used? e.g. 2008-R2-SP1'


$cred=Get-Credential -Message "Type the name and password of the local administrator account"
$vmSql=Set-AzureVMOperatingSystem -VM $vmSql -Windows -ComputerName $vmNameSql -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vmSql=Set-AzureVMSourceImage -VM $vmSql -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vmSql=Add-AzureVMNetworkInterface -vm $vmSql -ID $nicSql.Id
$OSdiskName= Read-Host 'What name should be given to the OS disk? e.g. DemoSQLOSDisk'
$storageAcc=Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString()+"vhds/"+$OSdiskName+".vhd"
$vmSql=Set-AzureVMOSDisk -VM $vmSql -Name $OSdiskName -VhdUri $osDiskUri -CreateOption fromImage
Write-Host 'Creating the SQL Server VM...' -foregroundcolor Green
New-AzureVM -ResourceGroupName $rgName -Location $locName -VM $vmSql
Write-Host "Completed creation of the SQL Server VM" -foregroundcolor Green
#End create VM For SQL Server
##################################################################################################

##################################################################################################
#Create VM for SP 2013 Server
$subnetIndex=0 #create this in the frontendSubnet
$vnet=Get-AzureVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$nicNameSp=Read-Host 'What is the NIC Name to use for the Sql Server VM NIC? e.g. DemoSPNIC1'
#Public domain name label
#Test the DNS availability by running 
#Test-AzureDnsAvailability -DomainQualifiedName $domName -Location $locName
$domNameSp=Read-Host 'What is the domain name for the SP Server VM? e.g. demosp1'
$pipSp = New-AzurePublicIpAddress -Name $nicNameSp -ResourceGroupName $rgName -DomainNameLabel $domNameSp -Location $locName -AllocationMethod Dynamic
$nicSp = New-AzureNetworkInterface -Name $nicNameSp -ResourceGroupName $rgName -Location $locName -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pipSp.Id
$vmNameSp= Read-Host 'What is the Name to use for the SP Server VM? e.g. DemoSP1'
Write-Host 'Currently available VM sizes are:'
Get-AzureVMSize -Location $locName | Sort Name| Select Name | Format-Table
$vmSizeSp=Read-Host 'What size VM should be created for the SQL VM? e.g. Standard_A1'

$avSpSet=Get-AzureAvailabilitySet -Name $avSQLName -ResourceGroupName $rgName
$vmSp=New-AzureVMConfig -VMName $vmNameSp -VMSize $vmSizeSp -AvailabilitySetId $avSpSet.Id
#Create the SP Data disk
Write-Host 'Configure the disk volume to be created for storing SP Server program and data files'
$diskSizeSPDataVol= Read-Host 'What disk size should be created (in GB)? e.g. 250'
$diskLabelSPDataVol= Read-Host 'What label should be given to this disk? e.g. SPData'
$diskNameSPDataVol= Read-Host 'What name should be given to this disk? e.g. DemoSp-disk2'
$storageAcc=Get-AzureStorageAccount -ResourceGroup $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndPoints.Blob.ToString() +"vhds/" + $vmNameSQL + $diskNameSPDataVol + ".vhd"
Write-Host "Creating the $diskLabelSPDataVol disk of size $diskSizeSPDataVol GB for $vmNameSql at $vhdURI..." -foregroundcolor Green
Add-AzureVMDataDisk -VM $vmSql -Name $diskLabelSPDataVol -DiskSizeInGB $diskSizeSPDataVol -VhdUri $vhdURI -LUN 0 -CreateOption empty
Write-Host 'Disk creation completed' -foregroundcolor Green
#To get the SKU to use for the VM
#Get-AzureVMImagePublisher -Location $locName | Select PublisherName
#$pubName="<publisher>"
#Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer
#$offerName="<offer>"
#Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus
#$skuName="<skuName>"

Write-Host 'Available VM Image Publishers are:'
Get-AzureVMImagePublisher -Location $locName | Sort PublisherName | Select PublisherName | Format-Table
$pubName= Read-Host 'What VM Image Publisher should be used? e.g. MicrosoftWindowsServer'

Write-Host 'Available offers for this image are:'
Get-AzureVMImageOffer -Location $locName -Publisher $pubName | Select Offer | Format-Table
$offerName= Read-Host 'Which offer should be used for this image? e.g. WindowsServer'

Write-Host 'Available SKUs are:'
Get-AzureVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Sort Skus | Select Skus | Format-Table
$skuName=Read-Host 'Which SKU should be used? e.g. 2008-R2-SP1'

$cred=Get-Credential -Message "Type the name and password of the local administrator account"
$vmSp=Set-AzureVMOperatingSystem -VM $vmSp -Windows -ComputerName $vmNameSp -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vmSp=Set-AzureVMSourceImage -VM $vmSp -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vmSp=Add-AzureVMNetworkInterface -vm $vmSp -ID $nicSp.Id
$OSdiskName= Read-Host 'What name should be given to the OS disk? e.g. DemoSPOSDisk'
$storageAcc=Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString()+"vhds/"+$OSdiskName+".vhd"
$vmSp=Set-AzureVMOSDisk -VM $vmSp -Name $OSdiskName -VhdUri $osDiskUri -CreateOption fromImage
Write-Host "Creating the SP Server VM..." -foregroundcolor Green
New-AzureVM -ResourceGroupName $rgName -Location $locName -VM $vmSp
Write-Host "Completed creation of the SP VM" -foregroundcolor Green
#End create VM for SP 2013 Server
##################################################################################################
