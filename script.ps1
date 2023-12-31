# ============================UAC prompt caller=================================
$isAdmin = [System.Security.Principal.WindowsPrincipal]::new(
    [System.Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole('Administrators')

if(-not $isAdmin) {
    $params = @{
        FilePath     = 'powershell' # or pwsh if Core
        Verb         = 'RunAs'
        ArgumentList = @(
            '-NoExit'
            '-ExecutionPolicy ByPass'
            '-File "{0}"' -f $PSCommandPath
        )
    }

    Start-Process @params
    return
}

# ============================Libraries and Globals=================================

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$global:hostnames = @()

# ============================Script Blocks=================================
# ---------------Script Block Caller--------------
$StartReceiveJobs = {
	param ( [string[]] $ComputerNames, [ScriptBlock] $ScriptBlock)
	function runJobs ([string[]] $ComputerNames) {
		foreach($computer in $ComputerNames){
			Start-Job -name $computer -ScriptBlock $ScriptBlock -ArgumentList $computer
		}

		$runningcount = (get-job | where State -eq running).count
		$spin = ".oO@*"
		Write-Host "Running Jobs  " -nonewline
		while ($runningcount -ne 0){
			$runningcount = (get-job | where State -eq running).count
			# Write-Host "sleeping for 1 second"
			Write-Host "`b$($spin.Substring($i++%$spin.Length)[0])" -nonewline
			Start-Sleep -Milliseconds 500
		}
		Write-Host ""
		$endResult = get-job | Receive-Job -Force -Wait # Collects Return values
		Write-Host $endResult
		# $endResult | ogv
		
		get-job | remove-job -Force	# Stops each of the jobs
	}
	runJobs $ComputerNames $ScriptBlock
}

# ---------------Endpoint Interaction Script Blocks--------------
$TestConnectionBlock = { 
	param( [string]$ComputerName )
	function checkSystem  ([string] $ComputerName) { 
		Start-Sleep -Seconds 1
		# Quiet option makes the result a boolean
		$Passed = Test-Connection $($ComputerName) -Count 1  -TimeToLive 64 -Quiet
		if ($Passed) {
			return "Connection made with {0}`n" -f $ComputerName
		} else {
			return "Connection not made with {0}`n" -f $ComputerName
		}
	}
	# checkSystem entry point
	checkSystem $ComputerName
}



$InvokeGPUpdateBlock = { 
	param( [string]$ComputerName )
	function GPUpdateSystem  ([string] $ComputerName) { 
		Start-Sleep -Seconds 1
		Invoke-GPupdate -Computer $($ComputerName) -Force -boot -RandomDelayInMinutes 0 -ErrorAction 'SilentlyContinue' | Out-Null
		if ($?) {		# If no error
			return "GPUpdate Invoked on {0}`n" -f $ComputerName
		} else {		# If error
			return "GPUpdate not Invoked on {0}`n" -f $ComputerName
		}
	}
	# GPUpdateSystem entry point
	GPUpdateSystem $ComputerName
}

$GetMECMVersionBlock = { 
	param( [string]$ComputerName )
	function GetMECMVersion ([string] $ComputerName) { 
		Start-Sleep -Seconds 1
		$MECM_Version = (Get-WMIObject -ComputerName $ComputerName `
		    -Namespace root\ccm -Class SMS_Client).ClientVersion 
		if (-not ([string]::IsNullOrEmpty($MECM_Version))) {
			return "MECM Version of {0}: {1}`n" -f $ComputerName, $MECM_Version
		} else {
			return "MECM Version of {0} Could not be found`n" -f $ComputerName
		}
	}
	# GetMECMVersion entry point
	GetMECMVersion $ComputerName
}

$RunActionsBlock = { 
	param( [string]$ComputerName )
	function RunActions ([string] $ComputerName) { 
		Start-Sleep -Seconds 1
		$actions = @(
			# Application Deployment
			"{00000000-0000-0000-0000-000000000121}"
			# Discovery Data Collection
			"{00000000-0000-0000-0000-000000000003}"
			# Hardware Inventory
			"{00000000-0000-0000-0000-000000000001}"
			# Machine Policy Retrieval
			"{00000000-0000-0000-0000-000000000021}"
		)
		foreach ($action in $actions) {
			Invoke-WMIMethod -ComputerName $ComputerName -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule $action |Out-Null
		}
		if ($?) {		# If no error on last action
			return "Actions ran on {0}`n" -f $ComputerName
		} else {		# If error on last action
			return "Actions not ran on {0}`n" -f $ComputerName
		}
	}
	# RunActions entry point
	RunActions $ComputerName
}

$GetActivePoliciesBlock = { 
	param( [string]$ComputerName )
	function GetActivePolicies ([string] $ComputerName) { 
 		Start-Sleep -Seconds 1
		$Active_Policies = $(cmd /c gpresult /r /s $ComputerName /scope computer)
		if (-not ([string]::IsNullOrEmpty($Active_Policies))) {
			return "Active Policies of {0}:`n{1} `n" `
			    -f $ComputerName, $($Active_Policies | Out-String)
		} else {
			return "Active Policies of {0} Could not be found`n" -f $ComputerName
		}
	}
	# GetActivePolicies  entry point
	GetActivePolicies $ComputerName
}

$RestartSystemBlock = { 
	param( [string]$ComputerName )
	function RestartSystem  ([string] $ComputerName) { 
		Start-Sleep -Seconds 1
		Restart-Computer -ComputerName $ComputerName -Force
		if ($?) {		# If no error
			return "Computer has been restarted {0}`n" -f $ComputerName
		} else {		# If error
			return "Computer has not been restarted {0}`n" -f $ComputerName
		}
	}
	# RestartSystem entry point
	RestartSystem $ComputerName
}

$GetSystemInfoBlock = { 
	param( [string]$ComputerName )
	function GetSystemInfo ([string] $ComputerName) { 
 		Start-Sleep -Seconds 1
		$SystemInfo = systeminfo /s $ComputerName
		if (-not ([string]::IsNullOrEmpty($SystemInfo))) {
			return "System Info of {0}:`n{1} `n" `
			    -f $ComputerName, $($SystemInfo | Out-String)
		} else {
			return "System Info of {0} Could not be found`n" -f $ComputerName
		}
	}
	# GetSystemInfo  entry point
	GetSystemInfo $ComputerName
}



# ===============================Gui to Script Calling Functions==================
function get_MECM_versions{
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $GetMECMVersionBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

function group_policy_updates {
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $InvokeGPUpdateBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

function get_active_policies{
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $GetActivePoliciesBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

function test_connections{
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $TestConnectionBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

function run_actions {
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $RunActionsBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

function restart_computers {
	param ([string[]]$ComputerNames)
	$result = [System.Windows.Forms.MessageBox]::Show('Restart Computers?' , "" , 4)
	if ($result -eq 'Yes') {
		$arugments = @($ComputerNames, $RestartSystemBlock)
		Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
	} else {
		Write-Host "Restart Cancelled"
	}
}

function system_info {
	param ([string[]]$ComputerNames)
	$arugments = @($ComputerNames, $GetSystemInfoBlock)
	Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
}

# ==========================Gui Functions=================================
function Read-MultiLineInputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText) {

    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    # Create the Label.
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Size(10,10)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.AutoSize = $true
    $label.Text = $Message

    # Create the TextBox used to capture the user's text.
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Size(10,40)
    $textBox.Size = New-Object System.Drawing.Size(575,200)
    $textBox.AcceptsReturn = $true
    $textBox.AcceptsTab = $false
    $textBox.Multiline = $true
    $textBox.ScrollBars = 'Both'
    $textBox.Text = $DefaultText

    # Create the OK button.
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Size(415,250)
    $okButton.Size = New-Object System.Drawing.Size(75,25)
    $okButton.Text = "OK"
    $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })

    # Create the Cancel button.
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Size(510,250)
    $cancelButton.Size = New-Object System.Drawing.Size(75,25)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $form.Tag = $null; $form.Close() })

    # Create the form.
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $WindowTitle
    $form.Size = New-Object System.Drawing.Size(610,320)
    $form.FormBorderStyle = 'FixedSingle'
    $form.StartPosition = "CenterScreen"
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.Topmost = $True
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.ShowInTaskbar = $true

    # Add all of the controls to the form.
    $form.Controls.Add($label)
    $form.Controls.Add($textBox)
    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)

    # Initialize and show the form.
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() > $null  # Trash the text of the button that was clicked.

    # Return the text that the user entered.
    return $form.Tag
}

function main_menu() {
	$form = New-Object System.Windows.Forms.Form
	$textbox_button = New-Object System.Windows.Forms.Button
	$textbox_button.Location = New-Object System.Drawing.Size(35,25)
	$textbox_button.Size = New-Object System.Drawing.Size(120,23)
	$textbox_button.Text = "Edit Hostnames"
	$call_textbox = {call_textbox}
	$textbox_button.Add_Click($call_textbox)

	$connection_button = New-Object System.Windows.Forms.Button
	$connection_button.Location = New-Object System.Drawing.Size(35,50)
	$connection_button.Size = New-Object System.Drawing.Size(120,23)
	$connection_button.Text = "Test Connections"
	$call_connection = {test_connections $global:hostnames}
	$connection_button.Add_Click($call_connection)

	$MECM_version_button = New-Object System.Windows.Forms.Button
	$MECM_version_button.Location = New-Object System.Drawing.Size(35,75)
	$MECM_version_button.Size = New-Object System.Drawing.Size(120,23)
	$MECM_version_button.Text = "MECM versions"
	$call_MECM_versions = {get_MECM_versions $global:hostnames}
	$MECM_version_button.Add_Click($call_MECM_versions)

	$gpupdate_button = New-Object System.Windows.Forms.Button
	$gpupdate_button.Location = New-Object System.Drawing.Size(35,100)
	$gpupdate_button.Size = New-Object System.Drawing.Size(120,23)
	$gpupdate_button.Text = "Invoke gpupdates"
	$call_gpupdate= {group_policy_updates $global:hostnames}
	$gpupdate_button.Add_Click($call_gpupdate)

	$active_policies_button = New-Object System.Windows.Forms.Button
	$active_policies_button.Location = New-Object System.Drawing.Size(35,125)
	$active_policies_button.Size = New-Object System.Drawing.Size(120,23)
	$active_policies_button.Text = "Show Active Policies"
	$call_gpresult= {get_active_policies $global:hostnames}
	$active_policies_button.Add_Click($call_gpresult)

	$run_actions_button = New-Object System.Windows.Forms.Button
	$run_actions_button.Location = New-Object System.Drawing.Size(35,150)
	$run_actions_button.Size = New-Object System.Drawing.Size(120,23)
	$run_actions_button.Text = "Run Actions"
	$call_actions= {run_actions $global:hostnames}
	$run_actions_button.Add_Click($call_actions)

	$system_info_button = New-Object System.Windows.Forms.Button
	$system_info_button.Location = New-Object System.Drawing.Size(35,175)
	$system_info_button.Size = New-Object System.Drawing.Size(120,23)
	$system_info_button.Text = "Get System Info"
	$call_systeminfo = {system_info $global:hostnames}
	$system_info_button.Add_Click($call_systeminfo)

	$restart_button = New-Object System.Windows.Forms.Button
	$restart_button.Location = New-Object System.Drawing.Size(35,225)
	$restart_button.Size = New-Object System.Drawing.Size(120,23)
	$restart_button.Text = "Restart Computers"
	$call_restart_computers = {restart_computers $global:hostnames}
	$restart_button.Add_Click($call_restart_computers)

	$Form.Controls.Add($textbox_button)
	$Form.Controls.Add($connection_button)
	$Form.Controls.Add($MECM_version_button)
	$Form.Controls.Add($gpupdate_button)
	$Form.Controls.Add($active_policies_button)
	$Form.Controls.Add($run_actions_button)
	$Form.Controls.Add($system_info_button)
	$Form.Controls.Add($restart_button)


	$form.showdialog()
}

# ==============================Helper Functions===========================
function call_textbox() {
	$hostnames_string = Read-MultiLineInputBoxDialog "Message" "Window Tile" (array_to_string $global:hostnames)
	$global:hostnames = (string_to_array $hostnames_string)

}

function string_to_array {
	param ([string[]]$string)
	return ($string).Trim() -split '\r?\n'
}

function array_to_string{
	param ([string[]]$array)
	return $array -join [Environment]::NewLine
}

# ===============================SCRIPT ENTRY POINT=============================
# Script entry point
# $ComputerNames = @("www.google.nl", "localhost", "www.test.com")
# $ComputerNames = @("localhost")
# $arugments = @($ComputerNames, $GetActivePoliciesBlock)
# $arugments = @($ComputerNames, $InvokeGPUpdateBlock)
# $arugments = @($ComputerNames, $StartReceiveJobs)
# $arugments = @($ComputerNames, $GetMECMVersionBlock)
# $arugments = @($ComputerNames, $RunActionsBlock)
# Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments

# ============================Check for Dependant commands=========================
# try {if $(Get-Command Invoke-GPUpdate)){}}
# Catch {
# 	$result = [System.Windows.Forms.MessageBox]::Show('Install RSAT tools? (required)' , "" , 4)
# 	if ($result -eq 'Yes') {
# 		Write-Host "Installing RSAT tools..."
# 		Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online
# 	} else {
# 		Exit
# 	}
# }
main_menu