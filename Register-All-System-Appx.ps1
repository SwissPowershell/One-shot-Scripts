# This script will analyse and try to register all systemapps manifests
Class SystemAppsPackage {
    [String] $Name
    [String] $Version
    [String] $Executable
    [String] $EntryPoint
    hidden [String] $DisplayName
    hidden [String] $Publisher
    hidden [String] $PublisherDisplayName
    hidden [Boolean] $VREG
    hidden [Boolean] $VFS
    hidden [OBJECT] $Appx
    [Boolean] $IsPartiallyStaged
    [Boolean] $IsOk
    [String] $Path

    hidden [System.Xml.XmlDocument] $manifestContent
    SystemAppsPackage(){}
    SystemAppsPackage([String] $Path) {
        $this.Path = $path
        $this.manifestContent = [XML] (Get-Content -path $Path -ErrorAction Stop)
        $this.Name = $this.manifestContent.Package.Identity.Name
        $this.Version = $this.manifestContent.Package.Identity.Version
        $this.Executable = try { $this.manifestContent.Package.Applications.Application.Executable.trim() }Catch{}
        $this.EntryPoint = try { $this.manifestContent.Package.Applications.Application.EntryPoint.trim() }Catch{}
        $this.DisplayName = $this.manifestContent.Package.Properties.DisplayName
        $this.Publisher = $this.manifestContent.Package.Identity.PublisherName
        $this.PublisherDisplayName = $this.manifestContent.Package.Properties.PublisherDisplayName
        $this.VREG = if ($this.manifestContent.Package.Properties.RegistryWriteVirtualization -eq 'disabled') {$false}Else{$true}
        $this.VFS = if ($this.manifestContent.Package.Properties.FileSystemWriteVirtualization -eq 'disabled') {$false}Else{$true}
        
        $this.Appx = Get-AppxPackage -Name $this.Name -ErrorAction SilentlyContinue
        if ($null -ne $this.Appx) {
            $this.IsPartiallyStaged = $this.Appx.IsPartiallyStaged
            $this.IsOk = if ($this.Appx.Status -eq 'OK') { $true }Else{ $false }
        }
        
        # Last

        # if the name is a guid like string add (entrypoint) before name
        if ($this.Name -match '^(?:\{[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\}|\([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\)|[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}|[0-9A-Fa-f]{32})$') {
            $this.Name = "($($this.EntryPoint)) $($this.Name)"
        }
    }
    
}
$SystemAppsInfo = @{
    Path = 'C:\Windows\SystemApps'
    Filter = 'appxmanifest.xml'
    Recurse = $True
    File = $True
}
$AllManifests = Get-ChildItem @SystemAppsInfo | ForEach-Object {
    [SystemAppsPackage]::new($_.FullName)
}
$Answer = Read-Host "Found $($AllManifests.Count) system appx manifests. Type 'Y' to try to register all system apps or 'N' to exit."
if ($Answer -ne 'Y') {
    Write-Host "Exiting without registering any apps."
    Break
}
foreach ($app in $AllManifests) {
    Write-Host "Registering $($app.Name) ..."
    Try {
        Add-AppxPackage -Register $app.Path -DisableDevelopmentMode -ErrorAction Stop
        Write-Host "Successfully registered $($app.Name)." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to register $($app.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
