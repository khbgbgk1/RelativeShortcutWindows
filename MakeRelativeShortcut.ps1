param (
    [string]$Action,
    [string]$Path
)

$TempFile = "$env:TEMP\rsw_shortcut_source.txt"

# --- COPY (Inchangé) ---
if ($Action -eq "copy") {
    $CleanPath = $Path.Trim('"')
    $CleanPath | Out-File -FilePath $TempFile -Encoding utf8 -Force
}
# --- PASTE (Inchangé) ---
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
# --- CONVERT (Corrigé : Suppression avant réécriture) ---
elseif ($Action -eq "convert") {
    $LnkPath = $Path.Trim('"')
    if (-not (Test-Path -Path $LnkPath)) { exit }

    # 1. On lit la cible actuelle
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($LnkPath)
    $OriginalTarget = $Shortcut.TargetPath

    if ($OriginalTarget -like "*explorer.exe*" -and $Shortcut.Arguments) {
        $OriginalTarget = $Shortcut.Arguments.Trim('"')
    }

    if (-not $OriginalTarget) { exit }

    # 2. On cherche le dossier correspondant
    $DestDir = Split-Path -Path $LnkPath -Parent
    $FoundTarget = $null

    if (Test-Path -Path $OriginalTarget) {
        $FoundTarget = $OriginalTarget
    } else {
        $Parts = $OriginalTarget.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries)
        $CurrentCheck = $DestDir
        
        while ($CurrentCheck) {
            for ($i = $Parts.Length - 1; $i -ge 0; $i--) {
                $SubPath = ($Parts[$i..($Parts.Length - 1)]) -join "\"
                $Candidate = Join-Path -Path $CurrentCheck -ChildPath $SubPath
                if (Test-Path -Path $Candidate) {
                    $FoundTarget = $Candidate
                    break
                }
            }
            if ($FoundTarget) { break }
            $CurrentCheck = Split-Path -Path $CurrentCheck -Parent
        }
    }

    # 3. Réécriture propre
    if ($FoundTarget) {
        $SourceUri = New-Object System.Uri($FoundTarget)
        $DestUri = New-Object System.Uri(($DestDir.ToString().TrimEnd('\') + "\"))
        $RelativeUri = $DestUri.MakeRelativeUri($SourceUri)
        $RelativePath = [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', '\')

        # FIX : Suppression obligatoire du fichier corrompu/existant avant la réécriture
        Remove-Item -Path $LnkPath -Force -ErrorAction SilentlyContinue

        # Re-création d'un raccourci totalement neuf
        $NewShortcut = $WScriptShell.CreateShortcut($LnkPath)
        $NewShortcut.TargetPath = "explorer.exe"
        $NewShortcut.Arguments = """$RelativePath"""
        $NewShortcut.WorkingDirectory = "%CD%"
        
        if (Test-Path -Path $FoundTarget -PathType Container) {
            $NewShortcut.IconLocation = "shell32.dll,3"
        } else {
            $NewShortcut.IconLocation = "shell32.dll,0"
        }
        
        $NewShortcut.Save()
    }
}