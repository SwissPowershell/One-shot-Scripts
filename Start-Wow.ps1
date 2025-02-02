# Clear the screen
Clear-Host
# Set the current location to the temp directory
Set-Location -Path $Env:Temp
# Get the wow installation path
Function Get-Wow {
    [CMDLetBinding()]
    Param()
    Try {
        $WowInstallationPath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft" -Name InstallPath -ErrorAction STOP
        Return $WowInstallationPath
        BREAK
    }Catch {
        
    }

    # trying to find wow in an another way
    # 1 Current Directory
    if (Test-Path -Path "$($PSSCriptRoot)\wow.exe") {
        Return $PSSCriptRoot
        BREAK
    }
    # Searching accros the whole disk, for \_retail_\wow.exe to determine the installation directory
    $WowInstallationPath = Get-ChildItem -Path 'C:\' -Recurse -Filter 'wow.exe' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '_retail_' } | Select-Object -ExpandProperty DirectoryName -First 1
    Return $WowInstallationPath
    BREAK
}
function Get-BattleNet {
    [CMDLetBinding()]
    Param()
    $Default = Get-ItemPropertyValue -path 'HKLM:\SOFTWARE\Classes\Blizzard.URI.Battlenet\Shell\Open\Command' -Name '(Default)'
    if ($Default) {
        $Path = (($Default -replace '--uri="%1"','').Replace('"','')).Trim()
        if (Test-Path -Path $Path -ErrorAction SilentlyContinue){
            return $Path
            BREAK
        }
    }
    # Trying to find the path in an another way
    $BattleNetPath = Get-ChildItem -Path 'C:\' -Recurse -Filter 'Battle.net.exe' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Battle.net.exe' } | Select-Object -ExpandProperty FullName -First 1
    Return $BattleNetPath
}
$WowInstallationPath = Get-Wow
# Remove potential double \\ for better readability
$WowAddonPath = "$($WowInstallationPath)\Interface\AddOns\" -replace '\\\\','\'
if (-not (Test-Path -Path $WowAddonPath -ErrorAction SilentlyContinue)) {
    Write-Warning 'WoW Addon path not found !!! the script will exit'
    Exit
}Else{
    Write-Host "WoW Addon path: $($WowAddonPath)" -ForegroundColor Yellow
}
Write-Host 'Checking ElvUI version...' -ForegroundColor Yellow
# Get information about the current version of ElvUI locally installed by reading the toc file version
$ElvUIPath = 'ElvUI'
$File = 'ElvUI_Mainline.toc'
$Content = Get-Content "$($WowAddonPath)\$($ElvUIPath)\$($File)"
[Version] $LocalVersion = ($Content | Where-Object { $_ -match '## Version: v' } | ForEach-Object {$_ -replace '## Version: v', '' }).Trim()

# Get version information from ElvUI API
$URL = 'https://api.tukui.org/v1/addon/elvui'
$Response = Invoke-RestMethod -Uri $URL
[Version] $RemoteVersion = $Response.version
$DownloadURL = $Response.url


if ($LocalVersion -eq $RemoteVersion) {
    Write-Host "ElvUI is up to date !!!" -ForegroundColor Green
} else {
    Write-Host '=============================' -ForegroundColor RED
    Write-Host '!! ElvUI is not up to date !!' -ForegroundColor RED
    Write-Host '=============================' -ForegroundColor RED
    Write-Host "`t Local ElvUI version:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$($LocalVersion)" -ForegroundColor Red
    Write-Host "`t Latest ElvUI version: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($RemoteVersion)" -ForegroundColor Magenta
    Write-Host "`t Latest ElvUI Update:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$($Response.last_update)" -ForegroundColor Magenta
    Write-Host "Downloading..." -ForegroundColor DarkCyan -NoNewline
    $Dest = "$($Env:Temp)\ElvUI-Update.zip"
    if (Test-Path -Path $Dest) {
        # There is allready a file with the same name, we remove it
        Remove-Item -Path $Dest -Force
    }
    # Download the latest version of ElvUI
    Invoke-WebRequest -Uri $DownloadURL -OutFile $Dest
    if (Test-Path -Path $Dest) {
        # Extract the downloaded file to the addon directory
        # Change the ProgressPreference to SilentlyContinue to avoid the progress bar
        $Original_ProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Expand-Archive -Path $Dest -DestinationPath $WowAddonPath -Force
        # Restore the ProgressPreference
        $ProgressPreference = $Original_ProgressPreference
        # Remove the downloaded file
        Remove-Item -Path $Dest -Force
        Write-Host ''
        Write-Host 'ElvUI updated successfully !!!' -ForegroundColor Green
    } else {
        Write-Host '`t`t Error downloading ElvUI !!!' -ForegroundColor Red
    }
}
# Search for battle net
$BattleNet = Get-BattleNet
if ($BattleNet) {
    Write-Host "Starting Battle.Net..." -ForegroundColor Yellow
    Start-Process -FilePath $BattleNet 
} else {
    Write-Host 'Battle Net not found !!! Please start Wow manually' -ForegroundColor Yellow
}

# Start CurseForge
$CurseForgeDir = "$($Env:LOCALAPPDATA)\Programs\CurseForge Windows"
$CurseForgeExe = 'CurseForge.exe'
if (Test-Path -path $CurseForgeDir) {
    $CurseForgeProcess = Get-Process -Name $($CurseForgeExe -split '\.' | Select-Object -first 1) -ErrorAction SilentlyContinue
    if ($CurseForgeProcess) {
        Write-Host 'CurseForge is already running !!!' -ForegroundColor Yellow
        do {
            Start-Sleep -Seconds 5
            $CurseForgeProcess = Get-Process -Name $($CurseForgeExe -split '\.' | Select-Object -first 1) -ErrorAction SilentlyContinue
        } while ($CurseForgeProcess)
    } else {
        Write-Host 'Starting CurseForge...' -ForegroundColor Yellow
        Start-Process "cmd.exe" -ArgumentList "/c `"$($CurseForgeDir)\$($CurseForgeExe)`"" -wait -WindowStyle Hidden
    }
    Write-Host 'Exitted...' -ForegroundColor Yellow
} else {
    Write-Host 'CurseForge is not installed... Ignoring CurseForge Update' -ForegroundColor Yellow
}

