$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

Write-Host "Starting Install msbuild..."

try {
    Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vs_community.exe -OutFile $env:TEMP\vs_community.exe
    $process = Start-Process -FilePath $env:TEMP\vs_community.exe -ArgumentList "--installPath", "C:\VisualStudio", "--allWorkloads", "--includeRecommended", "--passive", "--wait" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Installation process exited with code $($process.ExitCode)"
    }
}
catch {
    Write-Error $_.Exception.Message
}

# Set system variables
$msBuildPath = "C:\VisualStudio\MSBuild\Current\bin"
$registryPath = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
$oldPath = (Get-ItemProperty -Path $registryPath -Name PATH).path
$newPath = "$oldpath;$msBuildPath"
Set-ItemProperty -Path "$registryPath" -Name PATH -Value "$newPath"

# Install .net 4

# Define the URL for the .NET Framework 4.8 Developer Pack
$url = "https://go.microsoft.com/fwlink/?linkid=2088517"

# Define the path where the installer will be saved
$output = "$env:TEMP\ndp48-devpack-enu.exe"

# Download the installer
Invoke-WebRequest -Uri $url -OutFile $output

# Run the installer
Start-Process -FilePath $output -Args "/quiet /norestart" -Wait -Passthru

# Delete the installer
Remove-Item -Path $output

# Install Chocolatey
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$env:chocolateyUseWindowsCompression = 'true'
Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression

# Add Chocolatey to powershell profile
$ChocoProfileValue = @'
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

refreshenv
'@

# Write it to the $profile location
Set-Content -Path "$PsHome\Microsoft.PowerShell_profile.ps1" -Value $ChocoProfileValue -Force
# Source it
. "$PsHome\Microsoft.PowerShell_profile.ps1"

refreshenv

Write-Host "Installing cloudwatch agent..."
Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi -OutFile C:\amazon-cloudwatch-agent.msi
$cloudwatchParams = '/i', 'C:\amazon-cloudwatch-agent.msi', '/qn', '/L*v', 'C:\CloudwatchInstall.log'
Start-Process "msiexec.exe" $cloudwatchParams -Wait -NoNewWindow
Remove-Item C:\amazon-cloudwatch-agent.msi

# Install dependent tools
Write-Host "Installing additional development tools"
choco install git awscli -y
refreshenv

Write-Host "Creating actions-runner directory for the GH Action installtion"
New-Item -ItemType Directory -Path C:\actions-runner ; Set-Location C:\actions-runner

Write-Host "Downloading the GH Action runner from ${action_runner_url}"
Invoke-WebRequest -Uri ${action_runner_url} -OutFile actions-runner.zip

Write-Host "Un-zip action runner"
Expand-Archive -Path actions-runner.zip -DestinationPath .

Write-Host "Delete zip file"
Remove-Item actions-runner.zip

$action = New-ScheduledTaskAction -WorkingDirectory "C:\actions-runner" -Execute "PowerShell.exe" -Argument "-File C:\start-runner.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "runnerinit" -Action $action -Trigger $trigger -User System -RunLevel Highest -Force

C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1 -Schedule