# source: https://gist.github.com/chamindac/6045561f84f8548b052f523114583d41
Write-Host "Installing Docker..."

Write-Host "Downloading..."
Invoke-WebRequest -Uri https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe -OutFile DockerInstaller.exe -UseBasicParsing
Write-Host "Download complete."

start-process .\DockerInstaller.exe "install --quiet" -Wait -NoNewWindow
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
