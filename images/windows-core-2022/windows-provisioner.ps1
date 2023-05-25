$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

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
Write-Host "Finished Installing msbuild..."
# Set system variables
$msBuildPath = "C:\VisualStudio\MSBuild\Current\bin"
$registryPath = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
$oldPath = (Get-ItemProperty -Path $registryPath -Name PATH).path
$newPath = "$oldpath;$msBuildPath"
Set-ItemProperty -Path "$registryPath" -Name PATH -Value "$newPath"

# Install .net 4
Write-Host "Install .net dev pack 4.8"
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
Write-Host "Finished installing .net dev pack 4.8"


Write-Host "Enable long path behavior"
# See https://docs.microsoft.com/en-us/windows/desktop/fileio/naming-a-file#maximum-path-length-limitation
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

Write-Host "Installing cloudwatch agent..."
Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi -OutFile C:\amazon-cloudwatch-agent.msi
$cloudwatchParams = '/i', 'C:\amazon-cloudwatch-agent.msi', '/qn', '/L*v', 'C:\CloudwatchInstall.log'
Start-Process "msiexec.exe" $cloudwatchParams -Wait -NoNewWindow
Remove-Item C:\amazon-cloudwatch-agent.msi


# Install dependent tools
Write-Host "Installing additional development tools"

# Define the URL of the AWS CLI MSI installer
$installerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"

# Define the path where the installer will be saved
$installerPath = "$env:TEMP\AWSCLIV2.msi"

# Download the installer
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Install the AWS CLI
Start-Process msiexec.exe -Wait -ArgumentList "/I $installerPath /quiet"

# Verify the installation
refreshenv
aws --version

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
