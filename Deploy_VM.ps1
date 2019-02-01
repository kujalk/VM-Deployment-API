<#
--This script is invoked from Rest Ful API located at cmbmig01
--Required 6 parameters
				1. VM Name
				2. Datacenter
				3. VM Template
				4. VM Notes
				5. Folder
				6. User Mail
#>


[CmdletBinding()]
param(
    [parameter(position=0)]
    [string]$VM_Name,	
	[parameter(position=1)]
    [string]$Datacenter,
	[parameter(position=2)]
    [string]$VM_Template,
	[parameter(position=3)]
    [string]$VM_Notes,
	[parameter(position=4)]
    [string]$VM_Folder,
	[parameter(position=5)]
    [string]$User_Mail
)

#--Mail Function
function sendmail ($recipient,$body_mail)
{

$smtpServer = "mail.server@domain.com"

$msg = new-object Net.Mail.MailMessage

$smtp = new-object Net.Mail.SmtpClient($smtpServer)

#--Change according to server where the script is executed
$msg.From = "Test.server@domain.com"

#Recepients
$msg.To.Add($recipient)


$msg.Subject = "VM Deployment"

$msg.Body = $body_mail

$smtp.Send($msg)
}

#--Clusters for SSP VM deployments in 3 datacenters
$dc_cluster=@("DC1-Cluster-01","DC2-Cluster-01","DC3-Cluster-01")

#--Log File location

$log="C:\deployVM\"+$VM_Name+".txt"

#--function for logging time
function timestamp ($message)
{
$date=Get-Date
"$date : <<Info>> : $message" >> $log
}

#--This is used to specify the folder

function Get-FolderByPath{
 param(
  [CmdletBinding()]
  [parameter(Mandatory = $true)]
  [System.String[]]${Path},
  [char]${Separator} = '/'
  )
 
  process{
    if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
      $vcs = $defaultVIServers
    }
    else{
      $vcs = $defaultVIServers[0]
    }
 
    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
          if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
          }
        }
        $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
        }
      }
    }
  }
}

#--Vcenters
$dc_vcenter=@("DC1.domain.com","DC2.domain.com","DC3.domain.com")

#--Customization
$Spec=@("DC1_Windows","DC2_Windows","DC3_Windows")

#--Check which DC
	if ($Datacenter -eq "Dc1")
		{
			$final_dc_cluster=$dc_cluster[0]
			$final_dc_vcenter=$dc_vcenter[0]
			$final_Spec=$Spec[0]
		}
	elseif ($Datacenter -eq "DC2")
		{
			$final_dc_cluster=$dc_cluster[1]
			$final_dc_vcenter=$dc_vcenter[1]
			$final_Spec=$Spec[1]
		}
	elseif ($Datacenter -eq "DC3")
		{
			$final_dc_cluster=$dc_cluster[2]
			$final_dc_vcenter=$dc_vcenter[2]
			$final_Spec=$Spec[2]
		}

		

#--Vcenter User
$vCenterUser="domain\user1"

#--Password retrieved from Encrypted file
$vCenterUserPassword= Get-Content C:\deployVM\pass.txt | ConvertTo-SecureString


$credential = New-Object System.Management.Automation.PSCredential($vCenterUser,$vCenterUserPassword)

#--Login to Vcenter
Connect-VIServer -Server $final_dc_vcenter -Credential $credential
timestamp "Connected to $final_dc_vcenter"


$VM_Host=Get-Cluster $final_dc_cluster | Get-VMHost | Select Name -ExpandProperty Name | Get-Random
timestamp "VM Host - $VM_Host"

$VM_Datastore=Get-Cluster $final_dc_cluster | Get-Datastore | where {$_.FreeSpaceGB -gt 200}| select Name -ExpandProperty Name | Select-String "Cluster" | Get-Random
timestamp "VM Datastore - $VM_Datastore"


$Final_store= Get-Datastore -Name $VM_Datastore

#--Sample Path "CMB/CoS/Product Development Environments/Dev"
$Path_Folder = $VM_Folder

#--After connecting to Vcenter only we can use this
$Final_Folder= Get-FolderByPath -Path $Path_Folder

#--Deploying the VM
New-VM -Name $VM_Name -Template $VM_Template -VMHost $VM_Host -Datastore $Final_store -OSCustomizationSpec $final_Spec -Notes $VM_Notes -Location $Final_Folder

	if ($? -eq "True")
	{
	timestamp "VM deployment is successfull"
	Start-VM -VM $VM_Name -Confirm:$false
		if ($? -eq "True")
		{
		timestamp "VM is Powered ON successfully"
		$body="`n New VM - $VM_Name deployed successfully, Login after 30 Minutes"
		}
		else
		{
		timestamp "VM is failed to Power ON"
		$body="`n New VM - $VM_Name deployed successfully but failed to power ON"
		}
	}
	else
	{
	timestamp "VM deployment is failed"
	$body="`n New VM - $VM_Name deployment failed"
	}



#--Disconnecting from Vcenter	
Disconnect-VIServer -Server $final_dc_vcenter -confirm:$false
timestamp "Disconnected from VCenter"

timestamp "Bye!!! Bye!!!"

sendmail $User_Mail $body