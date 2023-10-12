$StartReceiveJobs = {
    param ( [string[]] $ComputerNames, [ScriptBlock] $ScriptBlock)
    function runJobs ([string[]] $ComputerNames) {
	foreach($computer in $ComputerNames){
	    Start-Job -name $computer -ScriptBlock $ScriptBlock -ArgumentList $computer
	}

	$runningcount = (get-job | where State -eq running).count

	while ($runningcount -ne 0){
	    $runningcount = (get-job | where State -eq running).count
	    Write-Output "sleeping for 1 second"
	    Start-Sleep -Seconds 1
	}

	$endResult = get-job | Receive-Job -Force -Wait # Collects Return values
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

$InvokeGPUpdateBlock = { 
    param( [string]$ComputerName )
    function GPUpdateSystem  ([string] $ComputerName) { 
        Start-Sleep -Seconds 1
	# Quiet option makes the result a boolean
        Invoke-GPupdate -Computer $($ComputerName) -Force -boot -RandomDelayInMinutes 0 | Out-Null
	Switch ($?) {
	    0 {return "Invoked successfully"}
	    1 {return "Invoked unsuccessfully"}
	}
    }
    # GPUpdateSystem entry point
    GPUpdateSystem $ComputerName
}

# Script entry point
$ComputerNames = @("www.google.nl", "localhost", "www.test.com")
$arugments = @($ComputerNames, $InvokeGPUpdateBlock)
# $arugments = @($ComputerNames, $StartReceiveJobs)
Invoke-Command -ScriptBlock $StartReceiveJobs -ArgumentList $arugments
