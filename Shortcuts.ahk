#Requires AutoHotkey v2.0

PSPath := A_ScriptDir . "\MakeRelativeShortcut.ps1"

; Gestion des arguments passés par le menu contextuel (clic droit)
if (A_Args.Length >= 2) {
    Action := A_Args[1]
    TargetPath := A_Args[2]
    RunPowerShellSilently('-Action ' . Action . ' -Path "' . TargetPath . '"')
    if (Action == "copy") {
        ToolTip("Relative target copied!")
    } else if (Action == "paste") {
        ToolTip("Relative shortcut created!")
    }
    SetTimer () => ToolTip(), -2000
    ExitApp()
}

; Inscription silencieuse dans le registre Windows
RegisterContextMenu()

RegisterContextMenu() {
    try {
        AHKPath := A_AhkPath
        
        ; Commande : Exécute AHK en mode silencieux avec le script courant
        CmdCopy := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "copy" "%1"'
        CmdPaste := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "paste" "%V"'

        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative\command", "")

        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative\command", "")

        RegWrite("[RSW] Create relative shortcut here", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "")
        RegWrite("shell32.dll,264", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "Icon")
        RegWrite(CmdPaste, "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative\command", "")
    }
}

RunPowerShellSilently(args) {
    ComObject("WScript.Shell").Run('powershell.exe -ExecutionPolicy Bypass -File "' . PSPath . '" ' . args, 0, true)
}

; -------------------------------------------------------------
; Keyboard Hotkeys (Ctrl + D + C / Ctrl + D + V)
; -------------------------------------------------------------

#HotIf GetKeyState("Ctrl", "P")
d & c::
{
    A_Clipboard := ""
    Send("^c")
    if ClipWait(1) {
        SelectedPath := A_Clipboard
        RunPowerShellSilently('-Action copy -Path "' . SelectedPath . '"')
        ToolTip("Relative target copied!")
        SetTimer () => ToolTip(), -2000
    }
}

d & v::
{
    A_Clipboard := ""
    Send("^c")
    
    DestPath := A_Clipboard
    if (DestPath == "") {
        try {
            hwnd := WinExist("A")
            for window in ComObject("Shell.Application").Windows {
                if (window.hwnd == hwnd) {
                    DestPath := window.Document.Folder.Self.Path
                    break
                }
            }
        }
    }

    if (DestPath != "") {
        RunPowerShellSilently('-Action paste -Path "' . DestPath . '"')
        ToolTip("Relative shortcut created!")
        SetTimer () => ToolTip(), -2000
    }
}
#HotIf