# source: https://gist.github.com/chamindac/6045561f84f8548b052f523114583d41
Write-Host "Installing Docker..."

start-process .\installer.exe "install --quiet" -Wait -NoNewWindow
cd "C:\Program Files\Docker\Docker\"
Write-Host "Installing..."
$ProgressPreference = 'SilentlyContinue'
& '.\Docker Desktop.exe'
$env:Path += ";C:\Program Files\Docker\Docker\Resources\bin"
$env:Path += ";C:\Program Files\Docker\Docker\Resources"
Write-Host "Installed successfully."

Write-Host "Starting..."
$ErrorActionPreference = 'SilentlyContinue';
do { $var1 = docker ps 2>$null } while (-Not $var1)
$ErrorActionPreference = 'Stop';
$env:Path += ";C:\Program Files\Docker\Docker\Resources\bin"
$env:Path += ";C:\Program Files\Docker\Docker\Resources"
Write-Host "Started successfully."

Write-Host "Enabling linux containers..."
& "C:\Program Files\Docker\Docker\DockerCli.exe" "-SwitchDaemon"

Write-Host "Complete."
# exit manually so that the exit code is 0
exit
