param (
	[string]$computerName,
	[string]$domain,
	[string]$user,
	[string]$pass,
	[string]$state,	
	[string]$webRoot,
	[string]$offlineFileName,
	[string]$onlineFileName,
	[string]$throwFailure,
	[string]$delayBefore,
	[string]$delayAfter
)

Function Has-Credentials($domain) {
	return -not($domain -eq "")
}

Function Get-Credential($domain, $user, $pass) {
	$Username = "$domain\$user"
	$Password = $pass | ConvertTo-SecureString
	$Cred = New-Object System.Management.Automation.PsCredential($Username,$Password)
	return $Cred
}

Function PathExists($computerName, $path, $domain, $user, $pass) {

	if ($computerName -eq "") {
		return Test-Path $path
	}
	if (Has-Credentials $domain) {
		$Cred = Get-Credential $domain $user $pass
		return Invoke-Command -ComputerName $computerName -Credential $Cred -ScriptBlock { Test-Path($args[0]) } -ArgumentList $path
	}
	else {
		return Invoke-Command -ComputerName $computerName -ScriptBlock { Test-Path($args[0]) } -ArgumentList $path
	}
}

Function MoveFile($computerName, $from, $to, $domain, $user, $pass) {

	if ($computerName -eq "") {
		Move-Item $from $to
		return
	}
	if (Has-Credentials $domain) {
		$Cred = Get-Credential $domain $user $pass
		Invoke-Command -ComputerName $computerName -Credential $Cred -ScriptBlock { Move-Item $args[0] $args[1] } -ArgumentList $from, $to
	}
	else {
		Invoke-Command -ComputerName $computerName -ScriptBlock { Move-Item $args[0] $args[1] } -ArgumentList $from, $to
	}
}

Function DeleteFile($computerName, $path, $domain, $user, $pass) {

	if ($computerName -eq "") {
		Remove-Item $path
		return
	}
	if (Has-Credentials $domain) {
		$Cred = Get-Credential $domain $user $pass
		Invoke-Command -ComputerName $computerName -Credential $Cred -ScriptBlock { Remove-Item $args[0] } -ArgumentList $path
	}
	else {
		Invoke-Command -ComputerName $computerName -ScriptBlock { Remove-Item $args[0] } -ArgumentList $path
	}
}

$hostName = $computerName
if ($computerName -eq "") {
	$hostName = "localhost"
}

Write-Host "Changing website status on $hostName"

if (-not($delayBefore -eq "" -or $delayBefore -eq "0")) {

	$seconds = [int]$delayBefore
	Write-Host "Waiting $delayBefore seconds before changing state"
	Start-Sleep -s $seconds
}

$offlineHtml = Join-Path $webRoot $offlineFileName
$onlineHtml = Join-Path $webRoot $onlineFileName

$offlineExists = PathExists $computerName $offlineHtml
$onlineExists = PathExists $computerName $onlineHtml


if ($state -eq "Online")
{
	if (-not($offlineExists))
	{
		if (($onlineExists) -or ($throwFailure.ToLower() -eq "false")) 
		{
			Write-Warning "File $offlineHtml cannot be found. Nothing will be changed! Note, $onlineFileName does exist."
			exit
		}
		else
		{
			Write-Error "File $offlineHtml cannot be found. Nothing will be changed!"
			exit 1
		}
	}

	#Offline exists and so does online - remove offline
	if (($offlineExists) -and ($onlineExists))
	{
		DeleteFile $computerName $offlineHtml
	}

	
	#Offline exists and online doesn't - move offline to online
	if (($offlineExists) -and -not($onlineExists))
	{
		MoveFile $computerName $offlineHtml $onlineHtml
	}

	Write-Host "Website is set to Online"
}

if ($state-eq "Offline")
{
	if (-not($onlineExists))
	{
		if (($offlineExists) -or ($throwFailure.ToLower() -eq "false")) 
		{
			Write-Warning "File $onlineHtml cannot be found. Website will not be taken offline! Note, $offlineFileName does exist."
			exit
		}
		else
		{
			Write-Error "File $onlineHtml cannot be found. Website will not be taken offline!"
			exit 1
		}
	}

	#Online exists and offline doesn't - move online to offline
	if (($onlineExists) -and -not($offlineExists))
	{
		MoveFile $computerName $onlineHtml $offlineHtml
	}

	Write-Host "Website is set to Offline"
}

if (-not($delayAfter -eq "" -or $delayAfter -eq "0")) {

	$secondsAfter = [int]$delayAfter
	Write-Host "Waiting $delayAfter seconds after changing state"
	Start-Sleep -s $secondsAfter
}
