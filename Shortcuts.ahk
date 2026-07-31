#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent

LogMsg(msg) {
    TimeString := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    try FileAppend("[" . TimeString . "] [AHK] " . msg . "`n", A_Temp . "\rsw_debug.log", "UTF-8")
}

PSPath := A_ScriptDir . "\MakeRelativeShortcut.ps1"

; Traitement des clics droits
if (A_Args.Length >= 2) {
    Action := A_Args[1]
    TargetPath := A_Args[2]
    LogMsg("Clic droit declenche: Action=" . Action . " | Path=" . TargetPath)
    RunPowerShellSilently(Action, TargetPath)
    
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

RegisterContextMenu()

RegisterContextMenu() {
    try {
        AHKPath := A_AhkPath
        CmdCopy := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "copy" "%1"'
        CmdPaste := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "paste" "%V"'
        CmdConvert := '"' . AHKPath . '" "' . A_ScriptFullPath . '" "convert" "%1"'

        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\*\shell\RSWCopyRelative\command", "")

        RegWrite("[RSW] Copy as relative target", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "")
        RegWrite("shell32.dll,134", "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative", "Icon")
        RegWrite(CmdCopy, "REG_SZ", "HKCU\Software\Classes\Directory\shell\RSWCopyRelative\command", "")

        RegWrite("[RSW] Create relative shortcut here", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "")
        RegWrite("shell32.dll,264", "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative", "Icon")
        RegWrite(CmdPaste, "REG_SZ", "HKCU\Software\Classes\Directory\Background\shell\RSWPasteRelative\command", "")

        RegWrite("[RSW] Convert to relative shortcut", "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative", "")
        RegWrite("shell32.dll,167", "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative", "Icon")
        RegWrite(CmdConvert, "REG_SZ", "HKCU\Software\Classes\lnkfile\shell\RSWConvertRelative\command", "")
    } catch as err {
        LogMsg("Erreur Registre: " . err.Message)
    }
}

RunPowerShellSilently(action, path := "") {
    if (path != "") {
        ArgFile := A_Temp . "\rsw_arg.txt"
        try FileDelete(ArgFile)
        FileAppend(path, ArgFile, "UTF-8")
    }
    LogMsg("Lancement PS pour Action=" . action)
    ComObject("WScript.Shell").Run('powershell.exe -ExecutionPolicy Bypass -File "' . PSPath . '" "' . action . '"', 0, true)
}

GetSelectedPath() {
    try {
        hwnd := WinExist("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd == hwnd) {
                for item in window.Document.SelectedItems {
                    LogMsg("GetSelectedPath via COM: " . item.Path)
                    return item.Path
                }
            }
        }
    } catch as err {
        LogMsg("Erreur COM: " . err.Message)
    }
    
    A_Clipboard := ""
    Send("^c")
    if ClipWait(1) {
        path := StrSplit(A_Clipboard, "`n")[1]
        path := Trim(path, "`r`n ")
        LogMsg("GetSelectedPath via Clip: " . path)
        return path
    }
    LogMsg("GetSelectedPath: Aucun element trouve")
    return ""
}

#HotIf GetKeyState("Ctrl", "P")

d & c::
{
    LogMsg("Hotkey Ctrl+D+C declenchee")
    SelectedPath := GetSelectedPath()
    if (SelectedPath != "") {
        RunPowerShellSilently("copy", SelectedPath)
        ToolTip("Relative target copied!")
        SetTimer () => ToolTip(), -2000
    }
}

d & v::
{
    LogMsg("Hotkey Ctrl+D+V declenchee")
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
        LogMsg("DestPath pour Paste: " . DestPath)
        RunPowerShellSilently("paste", DestPath)
        ToolTip("Relative shortcut created!")
        SetTimer () => ToolTip(), -2000
    } else {
        LogMsg("DestPath introuvable pour Paste")
    }
}

d & f::
{
    LogMsg("Hotkey Ctrl+D+F declenchee")
    SelectedPath := GetSelectedPath()
    if (SelectedPath != "" && SubStr(SelectedPath, -4) == ".lnk") {
        RunPowerShellSilently("convert", SelectedPath)
        ToolTip("Shortcut converted to relative!")
        SetTimer () => ToolTip(), -2000
    } else {
        LogMsg("SelectedPath invalide ou non-.lnk: " . SelectedPath)
    }
}

#HotIf