# RelativeShortcutWindows (RSW)

> Easily create true relative shortcuts (`.lnk`) in Windows 10/11 using keyboard hotkeys or the right-click context menu.

Windows shortcuts natively refuse relative paths (e.g., `..\Folder`). **RelativeShortcutWindows** solves this by dynamically calculating the lowest common ancestor path between source and target, allowing you to move or share your directory structures without breaking shortcuts.

---

## Features

- **Keyboard Shortcuts:** Quick copy/paste workflow via `Ctrl` + `D` + `C` and `Ctrl` + `D` + `V`.
- **Context Menu Integration:** Native right-click menu options in File Explorer (`[RSW]`).
- **Dynamic & Portable:** Uses `%CD%` relative resolution so your links don't break on external drives, USBs, or cloud syncs.
- **Silent Execution:** Completely hidden in the background with zero terminal/PowerShell pop-ups.
- **Auto-Configuring:** Keeps context menu paths updated automatically if you move the tool to another folder.

---

## Prerequisites

- **Windows 10 or 11**
- **[AutoHotkey v2.0+](https://www.autohotkey.com/)** installed

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

1. Select the source file or folder and press `Ctrl` + `D` + `C` *(Copy target)*.
2. Navigate to your destination directory and press `Ctrl` + `D` + `V` *(Paste relative shortcut)*.

### Method 2: Context Menu (Right-Click)

1. Right-click the file or folder you want to link to and select **`[RSW] Copy as relative target`**.
2. Go to the destination folder, right-click in an empty space, and select **`[RSW] Create relative shortcut here`**.

---

## License

MIT License — Feel free to modify and share!
