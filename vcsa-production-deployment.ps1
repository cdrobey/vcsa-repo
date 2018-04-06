# Author: William Lam
# Website: www.virtuallyghetto.com
# Description: PowerCLI script to deploy a fully functional vSphere 6.5 lab consisting of 3
#               Nested ESXi hosts enable wVCSA 6.5. Expects a single physical ESXi host
#               as the endpoint and all four VMs will be deployed to physical ESXi host
# Reference: http://www.virtuallyghetto.com/2016/11/vghetto-automated-vsphere-lab-deployment-for-vsphere-6-0u2-vsphere-6-5.html
# Credit: Thanks to Alan Renouf as I borrowed some of his PCLI code snippets :)
#
# Changelog
# 01/20/17
#   * Resolved "Another task in progress" thanks to Jason M
# 02/12/17
#   * Support for deploying to VC Target
#   * Support for enabling SSH on VCSA
#   * Added option to auto-create vApp Container for VMs
#   * Added pre-check for required files
# 02/17/17
#   * Added missing dvFilter param to eth1 (missing in Nested ESXi OVA)
# 02/21/17
#   * Support for both Virtual & Distributed Portgroup on $VMNetwork
#   * Support for adding ESXi hosts into VC using DNS name (disabled by default)
#   * Added CPU/MEM/Storage resource requirements in confirmation screen
# 05/08/17
#   * Support for patching ESXi using VMware Online repo thanks to Matt Lichstein for contribution
#   * Added fix to test ESXi endpoint before trying to patch

# Physical ESXi host or vCenter Server to deploy vSphere 6.5 lab
$VIServer = "r610.fr.lan"
$VIUsername = "root"
$VIPassword = "password"

# Specifies whether deployment is to an ESXi host or vCenter Server
# Use either ESXI or VCENTER
$DeploymentTarget = "ESXI"
$VCSAInstallerPath = "E:\"

# VCSA Deployment Configuration
$VCSADeploymentSize = "tiny"
$VCSADisplayName = "hostname"
$VCSAIPAddress = ""
$VCSAHostname = "host"
$VCSAPrefix = "24"
$VCSASSODomainName = "vcsa.local"
$VCSASSOSiteName = "Default"
$VCSASSOPassword = "password"
$VCSARootPassword = "password"
$VCSASSHEnable = "true"

# General Deployment Configuration for Nested ESXi, & VCSAVMs
$VirtualSwitchType = "VSS" # VSS or VDS
$VMNetwork = "vS0EAN"
$VMDatastore = "DS-LABNAS-NFS01"
$VMNetmask = "255.255.255.0"
$VMGateway = "10.1.3.1"
$VMDNS = "10.1.3.1"
$VMNTP = "10.1.3.1"
$VMPassword = "FamilyR0bersonL@b"
$VMDomain = "fr.lan"
$VMSyslog = "10.1.3.17"
# Applicable to Nested ESXi only
$VMSSH = "true"
$VMVMFS = "false"
# Applicable to VC Deployment Target only
$VMCluster = "Cluster"

# Name of new vSphere Datacenter/Cluster when VCSA is deployed
$NewVCDatacenterName = "Datacenter"
$NewVCClusterName = "Cluster"

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vsphere65-vghetto-lab-deployment.log"
$vSphereVersion = "6.5"
$deploymentType = "Standard"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$VAppName = "vGhetto-Nested-vSphere-Lab-$vSphereVersion-$random_string"
$depotServer = "https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml"

$vcsaSize2MemoryStorageMap = @{
"tiny"=@{"cpu"="2";"mem"="10";"disk"="250"};
"small"=@{"cpu"="4";"mem"="16";"disk"="290"};
"medium"=@{"cpu"="8";"mem"="24";"disk"="425"};
"large"=@{"cpu"="16";"mem"="32";"disk"="640"};
"xlarge"=@{"cpu"="24";"mem"="48";"disk"="980"}
}

$esxiTotalCPU = 0
$vcsaTotalCPU = 0
$esxiTotalMemory = 0
$vcsaTotalMemory = 0
$esxiTotStorage = 0
$vcsaTotalStorage = 0

$preCheck = 1
$confirmDeployment = 1
$deployNestedESXiVMs = 1
$deployVCSA = 1
$setupNewVC = 1
$addESXiHostsToVC = 1
$setupVXLAN = 11
$moveVMsIntovApp = 1

$StartTime = Get-Date

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

if($preCheck -eq 1) {
    if(!(Test-Path $VCSAInstallerPath)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCSAInstallerPath ...`nexiting"
        exit
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- vGhetto vCenter Server Appliance ---- "
    Write-Host -NoNewline -ForegroundColor Green "Deployment Target: "
    Write-Host -ForegroundColor White $DeploymentTarget
    Write-Host -NoNewline -ForegroundColor Green "Deployment Type: "
    Write-Host -ForegroundColor White $deploymentType
    Write-Host -NoNewline -ForegroundColor Green "vSphere Version: "
    Write-Host -ForegroundColor White  "vSphere $vSphereVersion"
    Write-Host -NoNewline -ForegroundColor Green "Nested ESXi Image Path: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "VCSA Image Path: "
    Write-Host -ForegroundColor White $VCSAInstallerPath

    if($DeploymentTarget -eq "ESXI") {
        Write-Host -ForegroundColor Yellow "`n---- Physical ESXi Deployment Target Configuration ----"
        Write-Host -NoNewline -ForegroundColor Green "ESXi Address: "
    } 

    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "Username: "
    Write-Host -ForegroundColor White $VIUsername
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork


    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore

    Write-Host -ForegroundColor Yellow "`n---- VCSA Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Deployment Size: "
    Write-Host -ForegroundColor White $VCSADeploymentSize
    Write-Host -NoNewline -ForegroundColor Green "SSO Domain: "
    Write-Host -ForegroundColor White $VCSASSODomainName
    Write-Host -NoNewline -ForegroundColor Green "SSO Site: "
    Write-Host -ForegroundColor White $VCSASSOSiteName
    Write-Host -NoNewline -ForegroundColor Green "SSO Password: "
    Write-Host -ForegroundColor White $VCSASSOPassword
    Write-Host -NoNewline -ForegroundColor Green "Root Password: "
    Write-Host -ForegroundColor White $VCSARootPassword
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VCSASSHEnable
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $VCSAHostname
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $VCSAIPAddress
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    
    $vcsaTotalCPU = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.cpu
    $vcsaTotalMemory = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.mem
    $vcsaTotalStorage = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.disk

    Write-Host -ForegroundColor Yellow "`n---- Resource Requirements ----"
    Write-Host -NoNewline -ForegroundColor Green "VCSA VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " VCSA VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "VCSA VM Storage: "
    Write-Host -ForegroundColor White $vcsaTotalStorage "GB"

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
    Clear-Host
}

My-Logger "Connecting to $VIServer ..."
$viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

$datastore = Get-Datastore -Server $viConnection -Name $VMDatastore

# Deploy using the VCSA CLI Installer
$config = (Get-Content -Raw "$($VCSAInstallerPath)\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json") | convertfrom-json
$config.'new.vcsa'.esxi.hostname = $VIServer
$config.'new.vcsa'.esxi.username = $VIUsername
$config.'new.vcsa'.esxi.password = $VIPassword
$config.'new.vcsa'.esxi.'deployment.network' = $VMNetwork
$config.'new.vcsa'.esxi.datastore = $datastore
$config.'new.vcsa'.appliance.'thin.disk.mode' = $true
$config.'new.vcsa'.appliance.'deployment.option' = $VCSADeploymentSize
$config.'new.vcsa'.appliance.name = $VCSADisplayName
$config.'new.vcsa'.network.'ip.family' = "ipv4"
$config.'new.vcsa'.network.mode = "static"
$config.'new.vcsa'.network.ip = $VCSAIPAddress
$config.'new.vcsa'.network.'dns.servers'[0] = $VMDNS
$config.'new.vcsa'.network.prefix = $VCSAPrefix
$config.'new.vcsa'.network.gateway = $VMGateway
$config.'new.vcsa'.network.'system.name' = $VCSAHostname
$config.'new.vcsa'.os.password = $VCSARootPassword
$config.'new.vcsa'.os.'ssh.enable' = $true
$config.'new.vcsa'.sso.password = $VCSASSOPassword
$config.'new.vcsa'.sso.'domain-name' = $VCSASSODomainName
$config.'new.vcsa'.sso.'site-name' = $VCSASSOSiteName

My-Logger "Creating VCSA JSON Configuration file for deployment ..."
$config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json"

My-Logger "Deploying the VCSA ..."
Invoke-Expression "$($VCSAInstallerPath)\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-esx-ssl-verify --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
 
if($moveVMsIntovApp -eq 1 -and $DeploymentTarget -eq "VCENTER") {
    My-Logger "Creating vApp $VAppName ..."
    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

    if($deployNestedESXiVMs -eq 1) {
        My-Logger "Moving Nested ESXi VMs into $VAppName vApp ..."
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $vm = Get-VM -Name $_.Key -Server $viConnection
            Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployVCSA -eq 1) {
        $vcsaVM = Get-VM -Name $VCSADisplayName -Server $viConnection
        My-Logger "Moving $VCSADisplayName into $VAppName vApp ..."
        Move-VM -VM $vcsaVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }
}

My-Logger "Disconnecting from $VIServer ..."
Disconnect-VIServer $viConnection -Confirm:$false


#if($setupNewVC -eq 1) {
#    My-Logger "Connecting to the new VCSA ..."
#    $vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue

#    My-Logger "Creating Datacenter $NewVCDatacenterName ..."
#    New-Datacenter -Server $vc -Name $NewVCDatacenterName -Location (Get-Folder -Type Datacenter -Server $vc) | Out-File -Append -LiteralPath $verboseLogFile

#    My-Logger "Creating  Cluster $NewVCClusterName ..."
#    New-Cluster -Server $vc -Name $NewVCClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vc) -DrsEnabled  | Out-File -Append -LiteralPath $verboseLogFile
#
#    if($addESXiHostsToVC -eq 1) {
#        $NestedESXiHostnameToIPs.GetEnumerator() | sort -Property Value | Foreach-Object {
#            $VMName = $_.Key
#            $VMIPAddress = $_.Value
#
#            $targetVMHost = $VMIPAddress
#            if($addHostByDnsName -eq 1) {
#                $targetVMHost = $VMName
#            }
#            My-Logger "Adding ESXi host $targetVMHost to Cluster ..."
#            Add-VMHost -Server $vc -Location (Get-Cluster -Name $NewVCClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile
#        }
#    }
#
#    My-Logger "Disconnecting from new VCSA ..."
#    Disconnect-VIServer $vc -Confirm:$false
#}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "vSphere $vSphereVersion Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"
