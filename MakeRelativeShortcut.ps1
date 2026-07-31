param (
    [string]$Action,
    [string]$Path
)

$TempFile = "$env:TEMP\jdr_shortcut_source.txt"

if ($Action -eq "copy") {
    # Sauvegarde la cible sélectionnée
    $Path | Out-File -FilePath $TempFile -Encoding utf8 -Force
}
elseif ($Action -eq "paste") {
    if (-not (Test-Path $TempFile)) { exit }
    
    $SourcePath = Get-Content -Path $TempFile -Raw
    $SourcePath = $SourcePath.Trim()
    
    # Détermine si la destination passée est un dossier ou un fichier
    $DestDir = $Path
    if (-not (Test-Path -Path $DestDir -PathType Container)) {
        $DestDir = Split-Path -Path $DestDir -Parent
    }
    
    # Calcul du chemin relatif depuis la destination vers la source
    $SourceUri = New-Object System.Uri($SourcePath)
    $DestUri = New-Object System.Uri($DestDir + "\")
    $RelativeUri = $DestUri.MakeRelativeUri($SourceUri)
    $RelativePath = [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', '\')
    
    # Nom du raccourci
    $TargetName = Split-Path -Path $SourcePath -Leaf
    $ShortcutPath = Join-Path -Path $DestDir -ChildPath "$TargetName.lnk"
    
    # Création du raccourci .lnk utilisant explorer.exe (aucun clignotement de terminal)
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "explorer.exe"
    $Shortcut.Arguments = """$RelativePath"""
    $Shortcut.WorkingDirectory = "%CD%"
    
    # Icône appropriée (dossier ou fichier)
    if (Test-Path -Path $SourcePath -PathType Container) {
        $Shortcut.IconLocation = "shell32.dll,3"
    } else {
        $Shortcut.IconLocation = "shell32.dll,0"
    }
    
    $Shortcut.Save()
}