# This is second version (2.0) of ILO5 Redfish and HPE SimpliVity REST API manipulation.
# This script checking status of HPE SimpliVity node ethernet interfaces through ILO 
# If something happen script will get the list of VMs on this node and through 
# Simplivity REST makes backup of all this VMs on another Datacenter
#
# You need to connect with POwerCLI to run this script
#-----------------Varibales-----------
# ilologin1 - login for the ILO5
# ilopass1 - login for the ILO5
# login1 - login of vSphere
# $pass1 - password of vSphere
# $s - the key for the Redfish session
# $esxi1 - Simplivity node mgmt address (that ilo you connect)
# $ovcilo1 - the OVC mgmt ip address
#----------------- End-of-Varibles----
#
$ilologin1="hpadmin"
$ilopass1="Your secret password"
$login1="administrator@vsphere.local"
$pass1="Your secret password"
$esxi1="s-esxi-01.newsynergy.local"
$ovcilo1="192.168.1.140"
#
$s=Connect-HPERedfish -Address 16.52.177.13 -Username $ilologin1 -Password $ilopass1 -DisableCertificateAuthentication
$A1=0
$Alert1=0
do 
{
    for ($i=1;$i -lt 4;$i++)
    {
        sleep 1
        $Alert1=Get-HPERedfishDataRaw -Odataid "/redfish/v1/Systems/1/EthernetInterfaces/$i" -Session $s -DisableCertificateAuthentication
        $Alert2=$Alert1.LinkStatus
        $IntName1=$Alert1.Name
        if ($Alert2 -eq 'LinkUp')
        {
            write-host -foreground Green "-------------------------------------------------------------"
            write-host -foreground Green "System is stable... Interface - $IntName1 is up"
            write-host -foreground Green "-------------------------------------------------------------"
        }
        else
        {
            $A1=1
            write-host -foreground Red "-------------------------------------------------------------"
            write-host -foreground Red "We get error...$IntName1 is down"
            write-host -foreground Red "-------------------------------------------------------------"
            $VMS1=Get-VMHost -Name $esxi1 | get-VM
            $VMS2=$VMS1.Count
            $VMS3=$VMS2-1
            for ($j=0;$j -lt $VMS3;$j++)
            {
                $VMName1=$VMS1[$j].Name
                .\SVT-BackupVM.ps1 -OVC $ovcip1 -Username $login1 -Password $pass1 -VM $VMName1 -DC HTC-R -Name "Emegency-Backup-$IntName1" -Expire 0
            }
        }
    }
} until ($A1 -eq 1)
