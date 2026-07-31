param (
    [string]$Action,
    [string]$Path
)

$TempFile = "$env:TEMP\rsw_shortcut_source.txt"

if ($Action -eq "copy") {
    $CleanPath = $Path.Trim('"')
    $CleanPath | Out-File -FilePath $TempFile -Encoding utf8 -Force
}
elseif ($Action -eq "paste") {
    if (-not (Test-Path $TempFile)) { exit }
    
    $SourcePath = (Get-Content -Path $TempFile -Raw).Trim()
    
    if (-not $Path -or $Path -eq "%V") {
        $DestDir = Get-Location
    } else {
        $CleanPath = $Path.Trim('"')
        if (Test-Path -Path $CleanPath -PathType Container) {
            $DestDir = $CleanPath
        } else {
            $DestDir = Split-Path -Path $CleanPath -Parent
        }
    }
    
    $SourceUri = New-Object System.Uri($SourcePath)
    $DestUri = New-Object System.Uri(($DestDir.ToString().TrimEnd('\') + "\"))
    $RelativeUri = $DestUri.MakeRelativeUri($SourceUri)
    $RelativePath = [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', '\')
    
    $TargetName = Split-Path -Path $SourcePath -Leaf
    $ShortcutPath = Join-Path -Path $DestDir -ChildPath "$TargetName.lnk"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "explorer.exe"
    $Shortcut.Arguments = """$RelativePath"""
    $Shortcut.WorkingDirectory = "%CD%"
    
    if (Test-Path -Path $SourcePath -PathType Container) {
        $Shortcut.IconLocation = "shell32.dll,3"
    } else {
        $Shortcut.IconLocation = "shell32.dll,0"
    }
    
    $Shortcut.Save()
}