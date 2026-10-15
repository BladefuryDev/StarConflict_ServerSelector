# Star Conflict Community Server Selector Mod

[![Release](https://img.shields.io/github/v/release/BladefuryDev/StarConflict_ServerSelector?color=0ea5e9&label=Release)](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://github.com/BladefuryDev/StarConflict_ServerSelector)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A custom community server manager mod and standalone patcher for **Star Conflict** designed for self-hosted and private community servers. It upgrades the game's login screen with persistent multi-server saving, default server auto-load on launch, an inline "Add Server" button, right-click context menu management, and native scrollbar overflow handling.

---

## Features

- **Server Dropdown & Native Scrollbar**:
  - Lists `localhost`, all saved community servers, and a custom direct connect entry (`Custom Server...`).
  - Automatically manages overflow: fits 1 to 6 servers compactly, and dynamically activates the game's native vertical scrollbar with arrow buttons, thumb slider, and mouse wheel support when more servers are added.
- **"Add Server" Button**: Positioned directly beside the dropdown. Automatically opens server address/port fields if on `localhost`, trims input, handles combined `host:port` syntax, and saves to persistent storage.
- **Persistent Storage**: Uses Star Conflict's native profile storage (`_G.GetProfileTable()` and `Profile:Save()`), backed up by a local fallback file (`saved_servers.cfg`). Saved servers and your default choice survive game updates, restarts, and crashes.
- **Right-Click Context Menu**:
  - Right-click any server in the dropdown to open the native context menu.
  - **Set as Default**: Marks the server with `[Default]` and configures the game to automatically select it and configure networking on startup.
  - **Delete Server**: Removes saved servers from the list and profile.
- **Default Auto-Load (No Auto-Join)**: When launching the game, if a default remote server is set, the menu automatically loads that server, sets `cvars.net_masterServerAddress`, and selects it in the dropdown ready for play without cluttering the screen with unnecessary edit fields. The pilot retains full control to click **Play / Log In** whenever ready.
- **Integrated Auto-Update Checker**: The graphical patcher checks GitHub for new releases in the background, notifying you when an updated patcher or mod version is available.

---

## Downloads & Installation

Get the latest release from the [**GitHub Releases Page**](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest):

### 1. Graphical Patcher (`StarConflict_Patcher.exe`) — Recommended
- Download **`StarConflict_Patcher.exe`** from the latest release.
- Standalone 64-bit Windows executable. Zero setup or Python install required—ready to run!
- Automatically detects your Steam game directory, verifies files, and installs with one click.
- Features live status diagnostics, directory browser with a gear button, and non-destructive backups (`loginwnd.lua.orig`).

### 2. Portable Python Package (`StarConflict_Patcher_Portable.zip`)
- Download **`StarConflict_Patcher_Portable.zip`**.
- Extract anywhere and run **`Launch_Patcher.bat`** or **`StarConflict_Patcher.pyw`**.
- Powered by the Omega UI framework on standard Python 3.8+ with zero third-party pip dependencies.

### 3. Command-Line CLI Patcher
Run the command-line patcher from your terminal:

```powershell
# Auto-detect game directory and install
python patcher.py --install

# Check installation status
python patcher.py --status

# Uninstall and restore original game file
python patcher.py --uninstall
```

If your game is installed in a non-standard location:
```powershell
python patcher.py --game-dir "D:\SteamLibrary\steamapps\common\star conflict" --install
```

---

## How to Use In-Game

1. **Selecting a Server**:
   - Open the dropdown on the login screen to choose between `localhost`, your saved community servers, or `Custom Server...`.
   - Selecting a saved server automatically populates its address and port and updates `net_masterServerAddress`.

2. **Adding a New Server**:
   - Click the **Add Server** button beside the dropdown.
   - The address and port fields will appear and keyboard focus will jump directly to the address box. The button label dynamically changes to **Save Server**.
   - Enter the server address (e.g., `play.starfury.net` or `192.168.1.100`) and port (defaults to `3801` if omitted).
   - Click **Save Server** to store it. The newly added server is selected immediately and the input fields automatically close.

3. **Setting a Server as Default**:
   - Click the dropdown to expand the server list.
   - **Right-click** on any server (including `localhost`).
   - Click **Set as Default**.
   - The selected server will now have `[Default]` next to its name and will be loaded automatically every time you launch the game.

4. **Deleting a Server**:
   - Expand the dropdown, **right-click** on any saved server, and click **Delete Server**.

---

## Technical Architecture & Safety

- **Target File**: `data/ui/scripts/windows/loginwnd.lua`
- **Hooked Systems**:
  - `UI.LoginWnd:BuildServersList()`: Constructs the dynamic server table from persistent profile data.
  - `UI.LoginWnd:UpdateServersComboBox()`: Populates dropdown records and auto-selects default server on startup.
  - `UI.LoginWnd:UpdateServerAddressWnd()`: Controls visibility of address & port edit fields based on selected server.
  - `UI.Login_AddServerBtn`: Injected button positioned beside the dropdown.
  - `UI.ComboBox1_ListSlot:F_OnMouseRButtonDown()`: Intercepts right-clicks on dropdown list items and invokes `UI.LoginWnd:ShowServerContextMenu()`.
  - `UI.ContextMenu_SlotWnd:UpdateForData()` & `Action()`: Extends native context menu slots with custom text and callback handlers.
- **Virtualized Window Pooling & Native Scrollbar**:
  - Dropdown lists in Targem's engine inherit from `ButtonsList3Wnd`.
  - `ButtonsList3Wnd` pools `MAX_SLOTS + 1` window handles and recycles them on scroll, avoiding window exhaustion.
  - When records exceed `MAX_VISIBLE_RECORDS = 6`, `BaseListWnd:UpdateScrollBarVisibility()` automatically binds the vertical scrollbar (`EffectScrollWnd_Vrt`) to `scroll_max`.
- **Backup & Safety**:
  - The patcher creates a full backup (`loginwnd.lua.orig`) before applying any modifications.
  - All mod code is isolated between explicit `-- BEGIN STAR CONFLICT SERVER SELECTOR MOD` and `-- END ...` markers for complete, clean uninstallation.

---

## Project Structure

```
StarConflict_ServerSelector/
├── .github/workflows/
│   └── release.yml                 # Automated GitHub Actions PyInstaller & Release builder
├── StarConflict_Patcher.exe        # Standalone 64-bit Windows executable
├── StarConflict_Patcher.pyw        # Graphical patcher interface (Omega UI)
├── StarConflict_Patcher_Portable.zip# All-in-one portable distribution for sharing
├── Launch_Patcher.bat              # One-click Windows launcher
├── omega_ui.py                     # Universal Omega UI Python framework
├── star_conflict.ico               # Star Conflict high-res icon
├── patcher.py                      # Standalone Python CLI installer / uninstaller
├── server_selector_mod.lua         # Complete Lua source for the Server Selector mod
├── validate_lua.py                 # Syntax and block balancer validation script
├── .gitignore                      # Git ignore configuration
└── README.md                       # Documentation and usage guide
```

---

## Credits

- **Alan Hexfury**: UI development, UX design for the patcher interface, and mod layout.
- **Gemini**: Reverse-engineering, Lua decompilation analysis, and tracing Targem UI engine function calls in the Star Conflict environment.
