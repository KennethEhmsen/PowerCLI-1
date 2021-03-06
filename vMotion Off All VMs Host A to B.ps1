<#  
 .SYNOPSIS  
  Script to vMotion VMs off one ESXi host to do maintenance - non-DRS user.
    
 .DESCRIPTION
  I use this script to vMotion VMs off one ESXi host to another ESXi host (A to B),
  perform some maintenance on the host, then migrate the VMs back to host (B to A).
  Optional progress bar, unmounting of ISO files (sometimes causes issues),
  and maintenance mode for standard vs. Virtual SAN hosts.
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2016-01-28
  Contact  : http://www.allthingstechie.net
  Revision : v1.1
  Changes  : v1.0 Original
			 v1.1 Added Progress Bar and Notes
#>
#Connect-VIServer myvCenterServer.local

#Show Progress
$showProgress = $true
#maintenance host
$srchostesx = "esxA.domain.local"
#temp VM host
$dsthostesx = "esxB.domain.local"

#VMs to be migrated around
$VMs = Get-VM | ? { $_.VMHost -like $srchostesx }

#disconenct any ISOs as needed
# $VMs | % { get-vm -name $_.name | Get-CDDrive  } | ? { $_.IsoPath -like "*.iso" -OR $_.HostDevice -match "/" } | % { $_ | Set-CDDrive -NoMedia -Confirm:$false }

#move VMs off
if ($VMs.Count -gt 0) { $VMs | % {$i=0} { 
	$i++
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($srchostesx) to $($dsthostesx)" -Status "$($i)/$($VMs.Count): VM:$($_.Name) - Attempting to vMotion to $($dsthostesx)..." -PercentComplete (($i/$VMs.Count)*100) }
	Move-VM $_ -Destination $dsthostesx -VMotionPriority High
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($srchostesx) to $($dsthostesx)" -Status "$($i)/$($VMs.Count): VM:$($_.Name) - Pausing 10 seconds..." -PercentComplete (($i/$VMs.Count)*100) }
	sleep 10
	}
}

#enter host maintenance 
Get-VMHost -Name $srchostesx | Set-VMHost -State Maintenance
#enter host maintenance - VSAN
# Get-View -ViewType HostSystem -Filter @{"Name" = $srchostesx }|?{!$_.Runtime.InMaintenanceMode}|%{$_.EnterMaintenanceMode(0, $false, (new-object VMware.Vim.HostMaintenanceSpec -Property @{vsanMode=(new-object VMware.Vim.VsanHostDecommissionMode -Property @{objectAction=[VMware.Vim.VsanHostDecommissionModeObjectAction]::NoAction})}))}

#
# do my thang ¯\_(ツ)_/¯
#

#exit host maintenance
Get-VMHost -name $srchostesx | Set-VMHost -State Connected

#move VMs back
if ($VMs.Count -gt 0) { $VMs | % {$i=0} { 
	$i++
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($dsthostesx) to $($srchostesx)" -Status "$($i)/$($VMs.Count): VM:$($_.Name) - Attempting to vMotion to $($srchostesx)..." -PercentComplete (($i/$VMs.Count)*100) }
	Move-VM $_ -Destination $srchostesx -VMotionPriority High
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($dsthostesx) to $($srchostesx)" -Status "$($i)/$($VMs.Count): VM:$($_.Name) - Pausing 10 seconds..." -PercentComplete (($i/$VMs.Count)*100) }
	sleep 10
	}
}
