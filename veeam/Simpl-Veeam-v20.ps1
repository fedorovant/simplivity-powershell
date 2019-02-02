# This is second version (2.0) of HPE Simplivity and Veeam integration.
# This script define the cluster at vCenter, makes HPE SimpliVity backup, 
# restore VMs at central cluster where Veeam can take it, send VMs list on Veeam job and start this job
# This modified version of script taken from here: https://github.com/tbeha/SimpliVity-Powershell
# Thanks Thomas Beha for original script and idea
#----Varibles---
# $ovclogin1 - login to OVC and vCenter
# $ovcpass1 - login to OVC and vCenter
# $ovcip1 - OVC ip address
# $DestinationStore - Destination Cluster where veeam can take temp-VMs
# $VeeamServer - veeam server address
# $VeeamBackupJob - Veeamjob
# $tempVMatJob - VM inside Veeam job at start (you need some - it Veeam rules)
#----Varibles---

Import-Module -Name ".\OmniStackCmds.psm1"
Add-PSSnapin -Name VeeamPSSnapin -ErrorAction SilentlyContinue

$A1=0
$Alert1=0
$ovclogin1="administrator@vsphere.local"
$ovcpass1="your secret password"
$ovcip1="192.168.1.132"
$DestinationStore="Simplivity"
$VeeamServer="veeam.newsynergy.local"
$VeeamBackupJob="SimplivityBackup"
$tempVMatJob="AD-SQL2016-clone"

Connect-VIServer -Server vcsa.newsynergy.local -User $ovclogin1 -Password $ovcpass1 -force
#----Cluster information----
$cluster1=Get-Cluster
$cluname1=$cluster1.Name
$clunum1=$cluster1.count
#---Show Clusters on the screen---
for ($j=0;$j -lt $clunum1;$j++)
    {
    Write-Host -ForegroundColor Cyan "$j)" $cluname1[$j]
    }
#Let Customer choice what Template he want to use for Deployment
$Name100=$cluster1.Count-1
$Num1=Read-Host "What Cluster you want to backup 0-$Name100 ?"
$Name1=$cluster1[$Num1].Name
Write-Host -ForegroundColor Cyan "==========================="
Write-Host -ForegroundColor Cyan "We'll use - $Name1 - Cluster"
Write-Host -ForegroundColor Cyan "==========================="

#-----Extract VMs from cluster------
$tempVM1=Get-Cluster -Name $Name1 | Get-VM
$tempVM1num=$tempVM1.Count
$tempVM1name=$tempVM1.Name
$VMs1= @()
$VMs1+='k'
$j=1
for ($i=0;$i -lt $tempVM1num;$i++)
{
    #filter OmniVMs
    if($tempVM1name[$i] -notmatch "OmniStackVC" ) 
    {
        if($tempVM1name[$i] -notmatch "Veeam")
        {
        $VMs1+=$tempVM1name[$i]
        Write-Host -ForegroundColor Cyan "==========================="
        Write-Host -ForegroundColor Cyan "This VMs will be backup:"
        Write-Host -ForegroundColor Cyan $VMs1[$j]
        $j++
        }
    }
}
Write-Host -ForegroundColor Cyan "==========================="
$VMs1count=$VMs1.count

#--- Veeam Backup----
# Connect to Veeam Server
Connect-VBRServer -Server $VeeamServer

# Find the current VM object in the job and remove it from the backupjob
$jobobject = Get-VBRJobObject -Name $tempVMatJob -Job $VeeamBackupJob
Remove-VBRJobObject -Objects $jobobject


# Get the Backup Job Object
$backupjob = Get-VBRJob -Name $VeeamBackupJob
$VMs2= @()
$VMs2+='l'
$bkpid1=@()
$bkpid1+='m'
$k=1
ConnectOmniStack -Server $ovcip1 -IgnoreCertReqs -OVCusername $ovclogin1 -OVCpassword $ovcpass1
    for ($j=1;$j -lt $VMs1count;$j++)
       {
            $VMName1=$VMS1[$j]
            #.\SVT-BackupVM.ps1 -OVC $ovcip1 -Username $ovclogin1 -Password $ovcpass1 -VM $VMName1 -DC $Name1 -Name "Veeam-$VMName1" -Expire 0
            $backupname = BackupVM -VM $VMName1 -Destination $Name1 -Retention 0
            #Write-Host "VM backup complet - Backupname: " $backupname
            $bkpid = GetBackupID -Backupname $backupname
            $bkpid1+=$bkpid
            RestoreVM -Bkpid $bkpid -Restorename Veeam-$VMName1 -Datastore $DestinationStore
            $VMs2+="Veeam-$VMName1"
            # Add the newly restored VM to the backup job
            $crm = Find-VBRViEntity -Name Veeam-$VMName1
            Add-VBRViJobObject -Entities $crm -Job $backupjob
       }
Write-Host -ForegroundColor Yellow "Wait for app-consistant backups.."
sleep 20 # waint for consistent backup finish
# Start the Veeam Backup Job
Start-VBRJob -Job $VeeamBackupJob

# Remove Temporary VMs
    for ($i=1;$i -lt $VMs1count;$i++)
    {
        # Remove Temp VMs from Veeam Job
        Write-Host $VMs2[$i]
        $jobobject = Get-VBRJobObject -Name $VMs2[$i] -Job $VeeamBackupJob
        Remove-VBRJobObject -Objects $jobobject
        # Remove Temp VMs
        Get-VM -Name $VMs2[$i] | Remove-VM -Confirm:$false
        # Remove Backup
        DeleteBackup -Bkpid $bkpid1[$i]
    }
# Restore Job default settings
$crm = Find-VBRViEntity -Name "AD-SQL2016-clone"
Add-VBRViJobObject -Entities $crm -Job $backupjob

Disconnect-VBRServer
Disconnect-VIServer -Confirm:$false
