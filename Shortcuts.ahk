#Requires AutoHotkey v2.0

; Trouve le fichier PowerShell dans le même dossier que ce script AHK
ScriptPath := A_ScriptDir . "\MakeRelativeShortcut.ps1"

; Ctrl + D + C : Copier la cible pour le raccourci relatif
#HotIf GetKeyState("Ctrl", "P")
d & c::
{
    A_Clipboard := ""
    Send("^c")
    if ClipWait(1) {
        SelectedPath := A_Clipboard
        RunWait('powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' ScriptPath '" -Action copy -Path "' SelectedPath '"', , "Hide")
        ToolTip("Cible copiée pour raccourci relatif !")
        SetTimer () => ToolTip(), -2000
    }
}

; Ctrl + D + V : Créer le raccourci relatif ici
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
        RunWait('powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' ScriptPath '" -Action paste -Path "' DestPath '"', , "Hide")
        ToolTip("Raccourci relatif créé !")
        SetTimer () => ToolTip(), -2000
    }
}
#HotIf