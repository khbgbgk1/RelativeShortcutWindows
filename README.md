# RelativeShortcutWindows (RSW)

> Easily create true relative shortcuts (`.lnk`) in Windows 10/11 using keyboard hotkeys or the right-click context menu.

Windows shortcuts natively refuse relative paths (e.g., `..\Folder`). **RelativeShortcutWindows** solves this by dynamically calculating the lowest common ancestor path between source and target, allowing you to move or share your directory structures without breaking shortcuts.

---

## Features

- **Keyboard Shortcuts:**
  - `Ctrl` + `D` + `C`: Copy target path.
  - `Ctrl` + `D` + `V`: Paste as a relative shortcut in the current folder.
  - `Ctrl` + `D` + `F`: Convert an existing absolute shortcut (`.lnk`) to a relative shortcut.
- **Context Menu Integration:** Native right-click menu options in File Explorer (`[RSW]`).
- **Full Unicode (UTF-16) Support:** Flawlessly handles special characters, accented letters, emojis, and non-ANSI alphabets (Gujarati, Cyrillic, Japanese, etc.).
- **Dynamic & Portable:** Uses `explorer.exe` with relative path arguments (`..\path\to\target`) so your links don't break on external drives, USBs, or cloud syncs.
- **Silent Execution:** Runs completely hidden in the background with zero terminal pop-ups.
- **Auto-Configuring:** Keeps context menu paths updated automatically in the Registry when launching `Shortcuts.ahk`.

---

## Prerequisites

- **Windows 10 or 11**
- **[AutoHotkey v2.0+](https://www.autohotkey.com/)** installed
- **PowerShell 5.1+** (Pre-installed on Windows)

---

## Installation

1. Clone or download this repository.
2. Place both `Shortcuts.ahk` and `MakeRelativeShortcut.ps1` in the **same folder** (any location on your drive).
3. Double-click `Shortcuts.ahk` to launch the script and automatically register the context menu options.

### Run Automatically at Windows Startup

To keep the keyboard shortcuts active every time you turn on your PC:

1. Press `Win` + `R` to open the **Run** dialog.
2. Type `shell:startup` and click **OK**.
3. Create a shortcut of `Shortcuts.ahk` inside this `Startup` folder.

---

## Usage

### Method 1: Keyboard Hotkeys

- **Copy & Paste Relative Shortcut:**
  1. Select the source file or folder and press `Ctrl` + `D` + `C` *(Copy target)*.
  2. Navigate to your destination directory and press `Ctrl` + `D` + `V` *(Paste relative shortcut)*.
- **Convert Existing Shortcut:**
  1. Select any existing standard (`.lnk`) shortcut.
  2. Press `Ctrl` + `D` + `F` *(Convert to relative)*.

### Method 2: Context Menu (Right-Click)

- **Copy & Paste Relative Shortcut:**
  1. Right-click the file or folder you want to link to and select **`[RSW] Copy as relative target`**.
  2. Go to the destination folder, right-click in an empty space, and select **`[RSW] Create relative shortcut here`**.
- **Convert Existing Shortcut:**
  1. Right-click an existing shortcut (`.lnk`) and select **`[RSW] Convert to relative shortcut`**.

---

## How It Works

1. **AutoHotkey (`Shortcuts.ahk`):** Captures the selected file/folder paths via Shell COM interfaces and triggers background PowerShell actions silently.
2. **PowerShell (`MakeRelativeShortcut.ps1`):** 
   - Calculates the exact relative URI path (`System.Uri.MakeRelativeUri`).
   - Uses `Shell.Application` COM methods to read and write UTF-16 Unicode paths natively (bypassing legacy ANSI limitations of `WScript.Shell`).
   - Generates an `explorer.exe` wrapper shortcut pointing directly to `"..\relative\path"`.

---

## Troubleshooting & Debugging

If a shortcut fails to convert or generate, execution logs are stored in a temporary log file:

```text
%TEMP%\rsw_debug.log
```

## License

MIT License — Feel free to modify and share!
