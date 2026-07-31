param (
    [string]$Action = "",
    [string]$Path = ""
)

$LogFile = "$env:TEMP\rsw_debug.log"

function Log-Msg ($msg) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [PS] $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Extraction de la cible et de l'icône originale d'un raccourci
function Get-LnkInfo ([string]$lnkPath) {
    $target = $null
    $icon = ""

    # 1. Extraction de l'icône via WScript.Shell
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $sc = $WScriptShell.CreateShortcut($lnkPath)
        $icon = $sc.IconLocation
    } catch {}

    # 2. Extraction de la cible en Unicode via Shell.Application
    try {
        $shell = New-Object -ComObject Shell.Application
        $dir = [System.IO.Path]::GetDirectoryName($lnkPath)
        $file = [System.IO.Path]::GetFileName($lnkPath)
        $folder = $shell.NameSpace($dir)
        $item = $folder.ParseName($file)
        
        if ($item -and $item.IsLink) {
            $link = $item.GetLink
            $t = $link.Path
            $args = $link.Arguments
            
            if ($t -like "*explorer.exe*" -and $args) {
                $target = $args.Trim('"')
            } elseif ($t) {
                $target = $t
            }
        }
    } catch {
        Log-Msg "Erreur Shell.Application: $_"
    }

    # Fallback WScript.Shell pour la cible si Shell.Application échoue
    if (-not $target) {
        try {
            $WScriptShell = New-Object -ComObject WScript.Shell
            $sc = $WScriptShell.CreateShortcut($lnkPath)
            $t = $sc.TargetPath
            if ($t -like "*explorer.exe*" -and $sc.Arguments) {
                $target = $sc.Arguments.Trim('"')
            } else {
                $target = $t
            }
        } catch {}
    }

    return @{
        Target = $target
        Icon   = $icon
    }
}

# Création / Écriture du raccourci avec conservation de l'icône
function Write-RelativeShortcut ([string]$shortcutPath, [string]$relativePath, [string]$targetPath, [string]$customIcon = "") {
    $destDir = [System.IO.Path]::GetDirectoryName($shortcutPath)
    $fileName = [System.IO.Path]::GetFileName($shortcutPath)

    # Détermination de l'icône à appliquer
    if ($customIcon -and $customIcon.Trim() -ne "" -and $customIcon -ne ",0") {
        $iconStr = $customIcon
    } elseif ([System.IO.Directory]::Exists($targetPath)) {
        $iconStr = "shell32.dll,3" # Icône de dossier par défaut
    } else {
        $iconStr = "$targetPath,0" # Icône native du fichier/exécutable ciblé
    }

    # Séparation du chemin d'icône et de son index
    $parts = $iconStr.Split(',')
    $iconFile = $parts[0].Trim()
    $iconIndex = 0
    if ($parts.Length -gt 1) {
        [int]::TryParse($parts[1].Trim(), [ref]$iconIndex) | Out-Null
    }

    # 1. Structure de base via WScript.Shell
    $WScriptShell = New-Object -ComObject WScript.Shell
    $sc = $WScriptShell.CreateShortcut($shortcutPath)
    $sc.TargetPath = "explorer.exe"
    $sc.Arguments = """$relativePath"""
    $sc.WorkingDirectory = "%CD%"
    $sc.IconLocation = "$iconFile,$iconIndex"
    $sc.Save()

    # 2. Réécriture UTF-16 Unicode via Shell.Application
    try {
        $sh = New-Object -ComObject Shell.Application
        $folder = $sh.NameSpace($destDir)
        $item = $folder.ParseName($fileName)
        
        if ($item -and $item.IsLink) {
            $link = $item.GetLink
            $link.Path = "explorer.exe"
            $link.Arguments = """$relativePath"""
            $link.WorkingDirectory = "%CD%"
            try { $link.SetIconLocation($iconFile, $iconIndex) } catch {}
            $link.Save()
        }
    } catch {
        Log-Msg "Erreur ecriture Shell.Application: $_"
    }
}

# Résolution de la cible sur le disque
function Resolve-TargetPath ([string]$targetPath, [string]$destDir) {
    if (-not $targetPath) { return $null }

    if (Test-Path -LiteralPath $targetPath) {
        return $targetPath
    }

    $parts = $targetPath.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries)
    $currentCheck = $destDir

    while ($currentCheck) {
        for ($i = $parts.Length - 1; $i -ge 0; $i--) {
            $subPath = ($parts[$i..($parts.Length - 1)]) -join "\"
            $candidate = Join-Path -Path $currentCheck -ChildPath $subPath

            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
        $currentCheck = [System.IO.Path]::GetDirectoryName($currentCheck)
    }

    return $null
}

try {
    $ArgFile  = "$env:TEMP\rsw_arg.txt"
    $TempFile = "$env:TEMP\rsw_shortcut_source.txt"

    if (-not $Path -and (Test-Path -LiteralPath $ArgFile)) {
        $Path = (Get-Content -LiteralPath $ArgFile -Encoding UTF8 -Raw).Trim()
    }

    Log-Msg "Execution - Action: '$Action' | Path: '$Path'"

    # --- COPY ---
    if ($Action -eq "copy") {
        $CleanPath = $Path.Trim('"')
        Set-Content -LiteralPath $TempFile -Value $CleanPath -Encoding UTF8 -Force
        Log-Msg "Copy OK. Path stocke: '$CleanPath'"
    }
    # --- PASTE ---
    elseif ($Action -eq "paste") {
        if (-not (Test-Path -LiteralPath $TempFile)) {
            Log-Msg "Paste ECHEC: $TempFile introuvable"
            exit
        }
        
        $SourcePath = (Get-Content -LiteralPath $TempFile -Encoding UTF8 -Raw).Trim()
        Log-Msg "Paste SourcePath: '$SourcePath'"
        
        if (-not $Path -or $Path -eq "%V") {
            $DestDir = (Get-Location).Path
        } else {
            $CleanPath = $Path.Trim('"')
            if ([System.IO.Directory]::Exists($CleanPath)) {
                $DestDir = $CleanPath
            } else {
                $DestDir = [System.IO.Path]::GetDirectoryName($CleanPath)
            }
        }
        Log-Msg "Paste DestDir: '$DestDir'"
        
        $SourceUri = New-Object System.Uri($SourcePath)
        $DestUri = New-Object System.Uri(($DestDir.ToString().TrimEnd('\') + "\"))
        $RelativeUri = $DestUri.MakeRelativeUri($SourceUri)
        $RelativePath = [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', '\')
        Log-Msg "Paste RelativePath: '$RelativePath'"

        $TargetName = [System.IO.Path]::GetFileName($SourcePath)
        $ShortcutPath = Join-Path -Path $DestDir -ChildPath "$TargetName.lnk"
        
        Write-RelativeShortcut -shortcutPath $ShortcutPath -relativePath $RelativePath -targetPath $SourcePath
        Log-Msg "Paste SUCCES -> '$ShortcutPath'"
    }
    # --- CONVERT ---
    elseif ($Action -eq "convert") {
        $LnkPath = $Path.Trim('"')
        Log-Msg "Convert LnkPath: '$LnkPath'"
        
        if (-not (Test-Path -LiteralPath $LnkPath)) {
            Log-Msg "Convert ECHEC: $LnkPath introuvable sur disque"
            exit
        }

        $LnkInfo = Get-LnkInfo -lnkPath $LnkPath
        $OriginalTarget = $LnkInfo.Target
        $OriginalIcon   = $LnkInfo.Icon
        Log-Msg "Convert Target originale: '$OriginalTarget' | Icone originale: '$OriginalIcon'"

        if (-not $OriginalTarget) {
            Log-Msg "Convert ECHEC: Target originale vide"
            exit
        }

        $DestDir = [System.IO.Path]::GetDirectoryName($LnkPath)
        $FoundTarget = Resolve-TargetPath -targetPath $OriginalTarget -destDir $DestDir

        Log-Msg "Convert FoundTarget final: '$FoundTarget'"

        if ($FoundTarget) {
            $SourceUri = New-Object System.Uri($FoundTarget)
            $DestUri = New-Object System.Uri(($DestDir.ToString().TrimEnd('\') + "\"))
            $RelativeUri = $DestUri.MakeRelativeUri($SourceUri)
            $RelativePath = [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', '\')

            Remove-Item -LiteralPath $LnkPath -Force -ErrorAction SilentlyContinue

            Write-RelativeShortcut -shortcutPath $LnkPath -relativePath $RelativePath -targetPath $FoundTarget -customIcon $OriginalIcon
            Log-Msg "Convert SUCCES pour '$LnkPath'"
        } else {
            Log-Msg "Convert ECHEC: Impossible de resoudre FoundTarget"
        }
    }
} catch {
    Log-Msg "EXCEPTION: $_"
}