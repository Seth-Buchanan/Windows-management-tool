$StartReceiveJobs = {
    param ( [string[]] $ComputerNames, [string] $ScriptBlock)
    function runJobs ([string[]] $ComputerNames) {
	# $Computers = @("www.google.nl", "localhost", "www.test.com")

	foreach($computer in $Computer_Names){
	    Start-Job -name $computer -ScriptBlock $ScriptBlock `
	      -ArgumentList $computer
	}

	$runningcount = (get-job | where State -eq running).count

	while ($runningcount -ne 0){
	    $runningcount = (get-job | where State -eq running).count
	    Write-Output "sleeping for 1 second"
	    Start-Sleep -Seconds 1
	}

	$endResult = get-job | Receive-Job -Force -Wait #Finds the 
	echo $endResult
	# $endResult | ogv
	
	get-job | remove-job -Force	# Stops each of the jobs
    }
    runJobs $ComputerNames $ScriptBlock
}



$TestConnectionBlock = { 
    param( [string]$ComputerName )
    function checkSystem  ([string] $ComputerName) { 
        Start-Sleep -Seconds 1
	# Quiet option makes the result a boolean
        $Passed = Test-Connection $($ComputerName) -Count 1  -TimeToLive 64 -Quiet
	if ($Passed) {
	    return "Connection made with {0}" -f $ComputerName
	} else {
	    return "Connection not made with {0}" -f $ComputerName
	}
    } 
    # checkSystem entry point
    checkSystem $ComputerName
}

# Script entry point
$ComputerNames = @("www.google.nl", "localhost", "www.test.com")
$arugments = @($ComputerNames, $TestConnectionBlock)
Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
