#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent

PSPath := A_ScriptDir . "\MakeRelativeShortcut.ps1"

; Traitement des clics droits (instances éphémères)
if (A_Args.Length >= 2) {
    Action := A_Args[1]
    TargetPath := A_Args[2]
    RunPowerShellSilently('-Action ' . Action . ' -Path "' . TargetPath . '"')
    
    if (Action == "copy") {
        ToolTip("Relative target copied!")
    } else if (Action == "paste") {
        ToolTip("Relative shortcut created!")
    } else if (Action == "convert") {
        ToolTip("Shortcut converted to relative!")
    }
    SetTimer () => ToolTip(), -2000
    ExitApp()
}

; Enregistrement automatique dans le Registre Windows
RegisterContextMenu()

RegisterContextMenu() {
    try {
        AHKPath := A_AhkPath
        
        CmdCopy := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "copy" "%1"'
        CmdPaste := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "paste" "%V"'
        CmdConvert := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "convert" "%1"'

        ; --- Clic droit : Copier la cible relative ---
        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative\command", "")

        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative\command", "")

        ; --- Clic droit : Créer le raccourci relatif ici ---
        RegWrite("[RSW] Create relative shortcut here", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "")
        RegWrite("shell32.dll,264", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "Icon")
        RegWrite(CmdPaste, "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative\command", "")

        ; --- Clic droit : Convertir un fichier .lnk existant en relatif ---
        RegWrite("[RSW] Convert to relative shortcut", "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative", "")
        RegWrite("shell32.dll,167", "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative", "Icon")
        RegWrite(CmdConvert, "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative\command", "")
    }
}

RunPowerShellSilently(args) {
    ComObject("WScript.Shell").Run('powershell.exe -ExecutionPolicy Bypass -File "' . PSPath . '" ' . args, 0, true)
}

; -------------------------------------------------------------
; Obtention directe de la sélection Windows Explorer via COM
; -------------------------------------------------------------

GetSelectedPath() {
    ; 1. Interrogation directe de l'Explorateur Windows
    try {
        hwnd := WinExist("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd == hwnd) {
                for item in window.Document.SelectedItems {
                    return item.Path
                }
            }
        }
    }
    
    ; 2. Secours par le Presse-papier si hors de l'Explorateur
    A_Clipboard := ""
    Send("^c")
    if ClipWait(1) {
        path := StrSplit(A_Clipboard, "`n")[1]
        return Trim(path, "`r`n ")
    }
    return ""
}

; -------------------------------------------------------------
; Raccourcis Clavier Persistants
; -------------------------------------------------------------

#HotIf GetKeyState("Ctrl", "P")

; Ctrl + D + C : Copier la cible
d & c::
{
    SelectedPath := GetSelectedPath()
    if (SelectedPath != "") {
        RunPowerShellSilently('-Action copy -Path "' . SelectedPath . '"')
        ToolTip("Relative target copied!")
        SetTimer () => ToolTip(), -2000
    }
}

; Ctrl + D + V : Créer le raccourci relatif
d & v::
{
    DestPath := ""
    try {
        hwnd := WinExist("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd == hwnd) {
                DestPath := window.Document.Folder.Self.Path
                break
            }
        }
    }

    if (DestPath != "") {
        RunPowerShellSilently('-Action paste -Path "' . DestPath . '"')
        ToolTip("Relative shortcut created!")
        SetTimer () => ToolTip(), -2000
    }
}

; Ctrl + D + F : Convertir le .lnk sélectionné en relatif
d & f::
{
    SelectedPath := GetSelectedPath()
    if (SelectedPath != "" && SubStr(SelectedPath, -4) == ".lnk") {
        RunPowerShellSilently('-Action convert -Path "' . SelectedPath . '"')
        ToolTip("Shortcut converted to relative!")
        SetTimer () => ToolTip(), -2000
    }
}

#HotIf