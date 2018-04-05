# HomeLab Build

## Table of Contents

* [Description](#description)
* [Changelog](#changelog)
* [Requirements](#requirements)
* [Supported Deployments](#supported-deployments)
* [Scripts](#scripts)
* [Configuration](#configuration)
* [Logging](#logging)
* [Verification](#verification)
* [Acknowledgement](#acknowledgement)

## Description

This script originates from William Lam and his effort to build a nested lab automated deploy.  I chose to make modifications to support my own selfish needs for Puppet Work.  The deployment supports a fully functional vSphere 6.5 environment that includes a set of Nested ESXi Virtual Appliance(s) ready to configure an IP datastore, as well as a vCenter Server Appliance (VCSA) using PowerCLI.  The VCSA requires a mounted datastore before building any new VMs.

## Changelog

### **12/28/17**

* Updated scripts to support testing against new ESXI target.
* Performed testing and teardown on multiple scenarios.

### **10/18/17**

* Modified William Lam's nested vm powercli scipts
* Deleted all NSX and VSAN related code to simply management
* Removed all scripts and images other than 6.5 standard deployment

## Requirements

* 1 x Physical ESXi host or vCenter Server running at least vSphere 6.0u2 or later
* Windows system
* Remote IP DataStore (Synology ISCSI/NFS Mounts)
* [PowerCLI 6.5 R1](https://my.vmware.com/group/vmware/details?downloadGroup=PCLI650R1&productId=568)
* vCenter Server Appliance (VCSA) 6.5 extracted ISO
* Nested ESXi [6.0](http://www.virtuallyghetto.com/2015/12/deploying-nested-esxi-is-even-easier-now-with-the-esxi-virtual-appliance.html) or [6.5](http://www.virtuallyghetto.com/2016/11/esxi-6-5-virtual-appliance-is-now-available.html) Virtual Appliance OVA
* [ESXi 6.5a offline patch bundle](https://my.vmware.com/web/vmware/details?downloadGroup=ESXI650A&productId=614&rPId=14229) (extracted)

## Supported Deployments

The script supports deploying both vSphere 6.0 and 6.5 environments with all VMs deployed directly to a physical ESXihosts.  The deployment includes the setup and configuration of a VCSA applicance.

## Configuration

This section describes the location of the files required for deployment. The first two are mandatory for the basic deployment. The Offline upgrade bundle isn't a requirement, but brings the deployment to the latest revision of ESXi.

```console
$NestedESXiApplianceOVA = "C:\Users\primp\Desktop\Nested_ESXi6.5_Appliance_Template_v1.ova"
$VCSAInstallerPath = "C:\Users\primp\Desktop\VMware-VCSA-all-6.5.0-4944578"
$ESXi65aOfflineBundle = "C:\Users\primp\Desktop\ESXi650-201701001\vmw-ESXi-6.5.0-metadata.zip"
```

This section describes the credentials to your physical ESXi server or vCenter Server in which the vSphere lab environment will be deployed to:

```console
$VIServer = "labvsphere"
$VIUsername = "root"
$VIPassword = "vmware123"
```

This section describes whether your deployment environment (destination) will be an ESXi host or a vCenter Server. You will need to specify either **ESXI** or **VCENTER** keyword:

```console
$DeploymentTarget = "ESXI"
```

This section defines the number of Nested ESXi VMs to deploy along with their associated IP Address(s). The names are merely the display name of the VMs when deployed. At a minimum, you should deploy at least two hosts, but you can always add additional hosts and the script will automatically take care of provisioning them correctly.

```console
$NestedESXiHostnameToIPs = @{
"vesxi65-1" = "172.30.0.171"
"vesxi65-2" = "172.30.0.172"
"vesxi65-3" = "172.30.0.173"
}
```

This section describes the resources allocated to each of the Nested ESXi VM(s). Depending on the deployment type, you may need to increase the resources. For Memory and Disk configuration, the unit is in GB.  The ESXi Disk drives are allocated in the nested vm, but ae not used after the installation.  They may be manually deleted.

```console
$NestedESXivCPU = "2"
$NestedESXivMEM = "6"
$NestedESXiCachingvDisk = "4"
$NestedESXiCapacityvDisk = "8"
```

This section describes the VCSA deployment configuration such as the VCSA deployment size, Networking & SSO configurations. If you have ever used the VCSA CLI Installer, these options should look familiar.

```console
$VCSADeploymentSize = "tiny"
$VCSADisplayName = "vcenter65-1"
$VCSAIPAddress = "172.30.0.170"
$VCSAHostname = "vcenter65-1.lab.local #Change to IP if you don't have valid DNS
$VCSAPrefix = "24"
$VCSASSODomainName = "LAB.local"
$VCSASSOSiteName = "LAB"
$VCSASSOPassword = "VMware1!"
$VCSARootPassword = "VMware1!"
$VCSASSHEnable = "true"
```

This section describes the location as well as the generic networking settings applied to BOTH the Nested ESXi VM and VCSA.

```console
$VirtualSwitchType = "VDS" # VSS or VDS for both $VMNetwork & $PrivateVXLANVMNetwork
$VMNetwork = "vS0LAB"
$VMDatastore = "vdsNFS"
$VMNetmask = "255.255.255.0"
$VMGateway = "172.30.0.1"
$VMDNS = "172.30.0.100"
$VMNTP = "pool.ntp.org"
$VMPassword = "vmware123"
$VMDomain = "lab.local"
$VMSyslog = "172.30.0.170"
# Applicable to Nested ESXi only
$VMSSH = "true"
$VMVMFS = "false"
# Applicable to VC Deployment Target only
$VMCluster = "LAB-Cluster"
```

This section describes the configuration of the new vCenter Server from the deployed VCSA.

```console
$NewVCDatacenterName = "Datacenter"
$NewVCVSANClusterName = "LAB-Cluster"
```

This section describes some advanced options for the deployment. Th first setting adds the ESXi hosts into vCenter Server using DNS names (must have both forward/reverse DNS working in your environment). The second option will upgrade the Nested ESXi 6.5 VMs to ESXi 6.5a which is required if you are deploying NSX 6.3 or if you just want to run the latest version of ESXi, you can also enable this. Both of these settings are disabled by default

```console
# Set to 1 only if you have DNS (forward/reverse) for ESXi hostnames
$addHostByDnsName = 0
# Upgrade vESXi hosts to 6.5a
$upgradeESXiTo65a = 0
```

Once you have saved your changes, you can now run the PowerCLI script as you normally would.

## Logging

There is additional verbose logging that outputs as a log file in your current working directory **vsphere65-vghetto-lab-deployment.log** depending on the deployment you have selected.

## Verification

Once you have saved all your changes, you can then run the script. You will be provided with a summary of what will be deployed and you can verify that everything is correct before attempting the deployment. Below is a screenshot on what this would look like:

## Post Installation Instructions

After the installation completes you need to mount the shared storage used for the nested environment.  I build a linux VM and export an NFS file system from the a VM on the host system.

To export the file system correctly, **/etc/exports**, needs to allow root access to the file system.

'''console
/vmware 192.168.1.0/24(rw,async,no_wdelay,root_squash,insecure_locks,sec=sys,anonui
d=65534,anongid=65534)
'''

The operating system images for Centos, Ubuntu, and Windows 2016 must be registered after the file system is mounted.  The images may be used by the terraform-repo to build the client vms.

## Acknowledgement

This script was built on the work of William Lam of VMware.  Make sure you visit his blogs and github for better detail on the broader effort he placed on this project. 

* William Lam's Github:	https://github.com/lamw/vghetto-vsphere-automated-lab-deployment
* William Lam's Blog:	http://www.virtuallyghetto.com/
