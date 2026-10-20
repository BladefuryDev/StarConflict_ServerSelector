# Star Conflict Community Server Selector Mod

[![Release](https://img.shields.io/github/v/release/BladefuryDev/StarConflict_ServerSelector?color=0ea5e9&label=Release)](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://github.com/BladefuryDev/StarConflict_ServerSelector)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A custom community server manager mod and standalone patcher for **Star Conflict** designed for self-hosted and private community servers. It upgrades the game's login screen with persistent multi-server saving, default server auto-load on launch, an inline "Add Server" button, right-click context menu management, native scrollbar overflow handling, and an optional **UI Overhaul** powered by Roblox-style Lua utilities.

---

## Features

- **Server Dropdown & Native Scrollbar**:
  - Lists `localhost`, all saved community servers, and a custom direct connect entry (`Custom Server...`).
  - Automatically manages overflow: fits 1 to 6 servers compactly, and dynamically activates the game's native vertical scrollbar with arrow buttons, thumb slider, and mouse wheel support when more servers are added.
- **"Add Server" Button**: Positioned directly beside the dropdown. Automatically opens server address/port fields if on `localhost`, trims input, handles combined `host:port` syntax, and saves to persistent storage.
- **Persistent Storage**: Uses Star Conflict's native profile storage (`_G.GetProfileTable()` and `Profile:Save()`). The profile is saved immediately after every add, delete, or default change, so saved servers and your default choice survive restarts. There is no separate config file: the game's Lua environment does not include the `io` library, so profile storage is the only place mod data can be kept.
- **Right-Click Context Menu**:
  - Right-click any server in the dropdown to open the native context menu.
  - **Set as Default**: Marks the server with `[Default]` and configures the game to automatically select it and configure networking on startup.
  - **Delete Server**: Removes saved servers from the list and profile.
- **Default Auto-Load (No Auto-Join)**: When launching the game, if a default remote server is set, the menu automatically loads that server, sets `cvars.net_masterServerAddress`, and selects it in the dropdown ready for play without cluttering the screen with unnecessary edit fields. The pilot retains full control to click **Play / Log In** whenever ready.
- **Integrated Auto-Update Checker**: The graphical patcher checks GitHub for new releases in the background, notifying you when an updated patcher or mod version is available.

### Second mod: UI Overhaul (optional, flavor & comfort)

The patcher manages two independent mods, each on its own tab under the diagnostics panel:

| Tab | Mod | What it does |
| :--- | :--- | :--- |
| **Server Selector** | essential | Everything above: saving and switching community servers, telemetry header dock, and live resolution scaling |
| **UI Overhaul** | flavor & comfort | Cinematic login boot sequence: fades in smoothly from pure black while the space background zooms out (`1.10x -> 1.00x`), then cascades in the UI chrome, login fields, Server Selector dock, and right-hand menu column; pulses the patch name between white and accent gold; scales menu buttons on hover. Built on **TweenService**, a Roblox-style animation and UI utility library in pure Lua 5.1 |

Install, update or remove either one without touching the other. **↺ Restore original** (next to the backup status) puts back `loginwnd.lua.orig` and removes every mod at once.

---

## UI Overhaul & Roblox-Style Lua Utilities (`TweenService`)

![Cinematic Login Boot Sequence](assets/cinematic_intro.gif)

Star Conflict's native UI engine (`m3d` / Targem Lua 5.1) relies on static `.sanim` keyframe files and has no built-in procedural tweening or interpolation utilities beyond a single color lerp helper. To modernize the UI and make authoring rich, responsive menus straightforward, the **UI Overhaul** module introduces **Roblox-style UI utilities** directly into the game's Lua environment—starting with **`TweenService`**, **`TweenInfo`**, **`Enum`**, and **`RBXScriptSignal`-style events**.

### Cinematic Login Screen (`ui_overhaul/login_tween_demo.lua`)
- **Seamless Fade-In from Black**: Transitions smoothly from opaque black (`0xFF000000`) as `UI.LoginWnd` opens so the handoff from the initial loading screen (with the loading circle) is completely seamless and never leaks the underlying 3D scene behind the login canvas.
- **Centered Background Zoom-Out**: Starts the background artwork (`BG_EFFECT` / `BG2_EFFECT`) slightly zoomed in (`1.10x`, centered around Rel `512, 384`) and smoothly eases out to `1.00x` (`Cubic` / `Out`).
- **Staggered UI Entrance**: After a brief beat (`0.35s`), fades in the top-left Star Conflict logo and bottom bar (`BG3_EFFECT`), status/version text layers, login fields, the Server Selector dock and action buttons, and cascades the right-hand menu column (`Back` / `Out`).
- **Interactive Hover & Accent Pulse**: Right-hand menu items grow subtly (`1.04x`) from their center on mouse hover (`0.075s` `Quad` / `Out`), and the *"Legacy of the Precursors"* patch title continuously pulses between white and login accent gold (`0xFFFFD200`).
- **Dynamic Resolution & Windowed Resize Support**: Widgets are unlinked from their `.sanim` locators only while actively animating and re-linked immediately on completion. If the game resolution or window size changes mid-animation (`1080p <-> 1440p`), both the Server Selector dock and `LoginTweenDemo` automatically recompute their layout and snap cleanly to the new coordinate system.

### `TweenService` API Overview (`ui_overhaul/tweenservice.lua`)
Modelled directly after Roblox's `TweenService` API so scripts read naturally:

```lua
local info = TweenInfo.new(
    0.6,                        -- Time (seconds)
    Enum.EasingStyle.Back,      -- Linear, Sine, Quad, Cubic, Quart, Quint, Exponential, Circular, Back, Elastic, Bounce
    Enum.EasingDirection.Out,   -- In, Out, InOut
    0,                          -- RepeatCount (-1 for infinite loop)
    false,                      -- Reverses (yoyo on each cycle)
    0.35                        -- DelayTime (seconds before playback begins)
)

local tween = TweenService:Create(UI.Login_OptionsBtn, info, {
    Left = targetX,
    Transparency = 0,
})

tween.Completed:Connect(function(playbackState)
    -- Fires with Enum.PlaybackState.Completed or Enum.PlaybackState.Cancelled
end)

tween:Play() -- Also supports :Pause(), :Cancel(), :Destroy(), TweenService:Set(), TweenService:CancelAll()
```

**Supported Targets & Properties (Extensible via `TweenService:AddAdapter`):**
- **Windows (`UI.SomeWnd`)**: `Left`, `Top`, `Width`, `Height` (in Rel `1024x768` space), `Position` (`Vec2`), `Size` (`Vec2`), `Rect` (`Quat`), and `Transparency` (`0..1`, cascaded across all window layers, `.sanim` effects, and child windows).
- **Layers (`TweenService:Layer(wnd, layerIdx)`)**: `Color` (ARGB), `Transparency` (`0..1`), `Left`, `Top`, `Width`, `Height`.
- **Effects (`UI:GetEffectFromLayer(wnd, layerIdx)`)**: `Scale` (number or `Vec2`), `Position` (`Vec2`), `Alpha` (`0..255`), `Transparency` (`0..1`), `Color` (ARGB multiply tint), and `AnimTime`.
- **Controller Tables**: Any plain Lua table with numeric, ARGB `*Color`, or `{x, y}` fields and an optional `OnChanged(self)` callback (similar to Roblox `NumberValue` / `Color3Value` objects).

> **Roadmap**: More Roblox-style UI utilities, layout helpers, and additional screen overhauls will follow as more of the engine's UI internals are mapped out and new UI features are ported in.

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
   - Click the **Add** button beside the dropdown.
   - The address and port fields will appear and keyboard focus will jump directly to the address box. The button label dynamically changes to **Save**.
   - Enter the server address (e.g., `play.starfury.net` or `192.168.1.100`) and port (defaults to `3801` if omitted).
   - Click **Save** to store it. The newly added server is selected immediately and the input fields automatically close.

3. **Setting a Server as Default**:
   - Select any server (or right-click it in the dropdown) and click **Default** (or **Set as Default** in the context menu).
   - The selected server will now have `[Default]` next to its name and will be loaded automatically every time you launch the game.

4. **Deleting a Server**:
   - Select any saved server and click **Delete** (or right-click it in the dropdown and click **Delete Server**).

---

## Technical Architecture & Safety

- **Target File**: `data/ui/scripts/windows/loginwnd.lua`
- **Hooked Systems**:
  - `UI.LoginWnd:BuildServersList()`: Constructs the dynamic server table from persistent profile data.
  - `UI.LoginWnd:UpdateServersComboBox()`: Populates dropdown records and auto-selects default server on startup.
  - `UI.LoginWnd:UpdateServerAddressWnd()`: Controls visibility of address & port edit fields based on selected server.
  - `UI.Login_ServerDockWnd`, `UI.Login_AddServerBtn`, `UI.Login_DefaultServerBtn`, `UI.Login_DeleteServerBtn`: Telemetry header dock and inline action buttons beside the dropdown.
  - `UI.ComboBox1_ListSlot:F_OnMouseRButtonDown()`: Intercepts right-clicks on dropdown list items and invokes `UI.LoginWnd:ShowServerContextMenu()`.
  - `UI.ContextMenu_SlotWnd:UpdateForData()` & `Action()`: Extends native context menu slots with custom text and callback handlers.
- **Virtualized Window Pooling & Native Scrollbar**:
  - Dropdown lists in Targem's engine inherit from `ButtonsList3Wnd`.
  - `ButtonsList3Wnd` pools `MAX_SLOTS + 1` window handles and recycles them on scroll, avoiding window exhaustion.
  - When records exceed `MAX_VISIBLE_RECORDS = 6`, `BaseListWnd:UpdateScrollBarVisibility()` automatically binds the vertical scrollbar (`EffectScrollWnd_Vrt`) to `scroll_max`.
- **Backup & Safety**:
  - The patcher creates a full backup (`loginwnd.lua.orig`) before applying any modifications.
  - Each mod is isolated between its own explicit markers (`-- BEGIN STAR CONFLICT SERVER SELECTOR MOD`, `-- BEGIN TWEENSERVICE`, `-- BEGIN LOGIN_TWEEN_DEMO`, each with a matching `-- END ...`). Uninstalling a mod strips only its blocks, so other mods keep working.
  - Before anything is written, the patched script is compiled with Lua 5.1 when the `lupa` package is available, or checked for balanced blocks otherwise. A file that would not load is never saved. UTF-8 and CRLF line endings are preserved.

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
├── assets/
│   └── cinematic_intro.gif         # Recorded preview of the login boot sequence
├── ui_overhaul/                    # UI Overhaul mod (copied from SC_UIRenderer/mods, its dev source)
│   ├── tweenservice.lua            #   Roblox-style TweenService animation library
│   └── login_tween_demo.lua        #   Cinematic animated login screen
├── validate_lua.py                 # Syntax and block balancer validation script
├── .gitignore                      # Git ignore configuration
└── README.md                       # Documentation and usage guide
```

---

## Credits

- **Alan Hexfury**: UI development, UX design for the patcher interface, and mod layout.
- **Claude & Gemini**: Reverse-engineering, headless UI renderer (`scui`), `TweenService` & UI Overhaul architecture, Lua decompilation analysis, and tracing Targem UI engine function calls in the Star Conflict environment.
