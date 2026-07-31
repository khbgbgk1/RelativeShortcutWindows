param (
    [string]$Action = "",
    [string]$Path = ""
)

$LogFile = "$env:TEMP\rsw_debug.log"

function Log-Msg ($msg) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [PS] $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Lecture de la cible avec Shell.Application (Unicode UTF-16)
function Get-LnkTargetUnicode ([string]$lnkPath) {
    try {
        $shell = New-Object -ComObject Shell.Application
        $dir = [System.IO.Path]::GetDirectoryName($lnkPath)
        $file = [System.IO.Path]::GetFileName($lnkPath)
        $folder = $shell.NameSpace($dir)
        $item = $folder.ParseName($file)
        
        if ($item -and $item.IsLink) {
            $link = $item.GetLink
            $target = $link.Path
            $args = $link.Arguments
            
            if ($target -like "*explorer.exe*" -and $args) {
                return $args.Trim('"')
            }
            if ($target) {
                return $target
            }
        }
    } catch {
        Log-Msg "Erreur lecture Shell.Application: $_"
    }
    return $null
}

# Création / Écriture du raccourci en UTF-16 via Shell.Application
function Write-RelativeShortcut ([string]$shortcutPath, [string]$relativePath, [bool]$isFolder) {
    $destDir = [System.IO.Path]::GetDirectoryName($shortcutPath)
    $fileName = [System.IO.Path]::GetFileName($shortcutPath)

    # 1. Génération de la structure de base du fichier .lnk
    $WScriptShell = New-Object -ComObject WScript.Shell
    $sc = $WScriptShell.CreateShortcut($shortcutPath)
    $sc.TargetPath = "explorer.exe"
    $sc.Save()

    # 2. Réécriture des propriétés en UTF-16 via Shell.Application
    $sh = New-Object -ComObject Shell.Application
    $folder = $sh.NameSpace($destDir)
    $item = $folder.ParseName($fileName)
    
    if ($item -and $item.IsLink) {
        $link = $item.GetLink
        $link.Path = "explorer.exe"
        $link.Arguments = """$relativePath"""
        $link.WorkingDirectory = "%CD%"
        $iconIdx = if ($isFolder) { 3 } else { 0 }
        try { $link.SetIconLocation("shell32.dll", $iconIdx) } catch {}
        $link.Save()
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
        
        Write-RelativeShortcut -shortcutPath $ShortcutPath -relativePath $RelativePath -isFolder ([System.IO.Directory]::Exists($SourcePath))
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

        $OriginalTarget = Get-LnkTargetUnicode -lnkPath $LnkPath
        Log-Msg "Convert Target originale: '$OriginalTarget'"

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

            Write-RelativeShortcut -shortcutPath $LnkPath -relativePath $RelativePath -isFolder ([System.IO.Directory]::Exists($FoundTarget))
            Log-Msg "Convert SUCCES pour '$LnkPath'"
        } else {
            Log-Msg "Convert ECHEC: Impossible de resoudre FoundTarget"
        }
    }
} catch {
    Log-Msg "EXCEPTION: $_"
}