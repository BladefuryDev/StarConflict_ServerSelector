# Technical Notes

How the Server Selector and UI Overhaul work, and what modders can build on. For installing and using the mods, see [README.md](README.md).

- [How the patcher installs mods](#how-the-patcher-installs-mods)
- [Server Selector internals](#server-selector-internals)
- [UI Overhaul internals](#ui-overhaul-internals)
- [TweenService API](#tweenservice-api)
- [RbxUI toolkit](#rbxui-toolkit)
- [Command-line patcher](#command-line-patcher)
- [Project structure](#project-structure)

---

## How the patcher installs mods

- **Target file:** `data/ui/scripts/windows/loginwnd.lua` (UTF-8, CRLF).
- **Backup:** `loginwnd.lua.orig` is created once, before the first change. **↺ Restore original** copies it back and so removes every mod.
- **Marker blocks:** each mod lives between its own markers and is appended in load order:
  - `-- BEGIN STAR CONFLICT SERVER SELECTOR MOD` … `-- END …`
  - `-- BEGIN TWEENSERVICE`, `-- BEGIN RBXUI`, `-- BEGIN LOGIN_TWEEN_DEMO` (UI Overhaul)

  Installing replaces a mod's blocks; uninstalling strips only them, so other mods keep working.
- **Compile check:** before anything is written, the patched script is compiled with Lua 5.1 (via `lupa` when available, otherwise a block-balance check). A file that would not load is never saved. Encoding and line endings are preserved.
- **Lua 5.1 limits:** every block is wrapped in `do … end`, because appended code shares `loginwnd.lua`'s 200-local limit.

---

## Server Selector internals

- **Hooked systems:**
  - `UI.LoginWnd:BuildServersList()` builds the server table from profile data.
  - `UI.LoginWnd:UpdateServersComboBox()` fills the dropdown and selects the default server at startup.
  - `UI.LoginWnd:UpdateServerAddressWnd()` shows the address / port fields when needed.
  - `UI.Login_ServerDockWnd`, `UI.Login_AddServerBtn`, `UI.Login_DefaultServerBtn` and `UI.Login_DeleteServerBtn` are the header dock and the inline buttons.
  - `UI.ComboBox1_ListSlot:F_OnMouseRButtonDown()` opens `UI.LoginWnd:ShowServerContextMenu()` on right-click.
  - `UI.ContextMenu_SlotWnd:UpdateForData()` / `Action()` add custom menu entries.
- **Persistence:** `_G.GetProfileTable()` + `Profile:Save()` after every add, delete or default change. The game's Lua has no `io` library, so the profile is the only place mod data can live.
- **Default auto-load:** at startup the default server is selected and `cvars.net_masterServerAddress` is set. Nothing connects until the player presses Play.
- **Dropdown overflow:** dropdowns inherit `ButtonsList3Wnd`, which pools `MAX_SLOTS + 1` slot windows and recycles them on scroll. Past `MAX_VISIBLE_RECORDS = 6`, `BaseListWnd:UpdateScrollBarVisibility()` binds the native vertical scrollbar.
- **Resolution changes:** a per-frame watcher on `UI.screenWidth/Height` re-runs `UpdateServerDockLayout()`, and the action buttons re-measure their `.sanim` frames.

---

## UI Overhaul internals

Star Conflict's UI engine (Targem, Lua 5.1) animates with static `.sanim` keyframe files and has no tweening of its own. The UI Overhaul adds Roblox-style libraries to the game's Lua: `TweenService` for animation and `RbxUI` for layout, styling and driving native windows. `login_tween_demo.lua` uses both to restyle the login screen.

### Login screen (`ui_overhaul/login_tween_demo.lua`)
- **Fade-in from black:** the background starts as opaque black (`0xFF000000` vertex tint, not alpha 0, which would show the 3D scene behind the login window). It eases to full colour while zooming out from 1.10× to 1.00× about the screen centre.
- **Staggered entrance:** after 0.35 s the logo bar, status texts, fields, Server Selector dock and the right-hand menu cascade in (`Back` / `Out`).
- **Locator-safe animation:** widgets leave their `.sanim` locators only while they animate and are re-linked afterwards. Bottom-anchored or ultrawide layouts and mid-session resolution changes therefore stay correct; `SnapToLinks()` runs on any `UI.screenWidth/Height` change.
- **Quick Play:** with "Remember me" and saved credentials, the form folds into the classic golden Play button (`UI.Login_SteamLogInBtn`, `login_enter_2.sanim`, re-labelled "Play") and an owner-drawn Welcome bar. *"Click here to change."* expands the form again and clears the saved credentials.
- **Hover:** buttons grow 4–5 % from their centre; the Play button also lifts 4 px. This uses the RbxUI bridge with `AnchorPoint = (0.5, 0.5)`, because effects scale about the window's top-left corner.
- **Typing:** E-mail / Password focus, selection and Tab order are left to the engine's own `EditWnd`. The mod adds click-away, Tab / Shift+Tab through all visible fields, and a custom caret. The caret is drawn at the engine's own caret position (its `CURSOR` layer rect), so it is exact after scrolling, in any font, and over the password mask.

### Engine facts the mods rely on
- `UI.<Wnd>.def` is cleared once a window is built. Read locator links at script load.
- Window tables with `def.prototype` get their prototype only when created, so hooks installed at load must call the inherited handler at run time (`getmetatable(self).__index[name]`) instead of capturing `prev = wnd.F_X`.
- Effect alpha is 0..255. A text layer linked to a `.sanim` object with `COLOR` / `ALPHA` ignores `effect:SetAlpha` and `SetColor`, which is why RbxUI draws faded labels itself.
- Never leave keyboard focus at `INVALID_UI_HANDLE` on a screen; keys then reach no window. Park it on the screen window.

---

## TweenService API

`ui_overhaul/tweenservice.lua`, modelled on Roblox's `TweenService`:

```lua
local info = TweenInfo.new(
    0.6,                        -- time (seconds)
    Enum.EasingStyle.Back,      -- Linear, Sine, Quad, Cubic, Quart, Quint, Exponential, Circular, Back, Elastic, Bounce
    Enum.EasingDirection.Out,   -- In, Out, InOut
    0,                          -- repeat count (-1 = forever)
    false,                      -- reverses
    0.35                        -- delay (seconds)
)

local tween = TweenService:Create(UI.Login_OptionsBtn, info, { Left = targetX, Transparency = 0 })
tween.Completed:Connect(function(state) end)   -- Enum.PlaybackState.Completed / Cancelled
tween:Play()                                   -- :Pause() :Cancel() :Destroy(); TweenService:Set(), :CancelAll()
```

| Target | Properties |
| :--- | :--- |
| Windows (`UI.SomeWnd`) | `Left`, `Top`, `Width`, `Height` (Rel 1024×768 units), `Position`, `Size`, `Rect`, `Transparency` (0..1: layers, effects, linked labels and child windows, via the RbxUI bridge) |
| Layers (`TweenService:Layer(wnd, idx)`) | `Color` (ARGB), `Transparency`, `Left`, `Top`, `Width`, `Height` |
| Effects (`UI:GetEffectFromLayer(wnd, idx)`) | `Scale`, `Position`, `Alpha` (0..255), `Transparency` (0..1), `Color`, `AnimTime` |
| RbxUI instances | any `UDim2`, `UDim`, `Vector2`, `Color3`, `ColorSequence`, `NumberSequence`, `NumberRange` or number property |
| Plain Lua tables | numbers, ARGB `*Color` fields, `{x, y}`; optional `OnChanged(self)` |

A new tween takes over the properties it shares with a running tween on the same target. Add property kinds with `TweenService:AddAdapter{ accepts, get, set, props }`.

---

## RbxUI toolkit

`ui_overhaul/rbxui.lua` brings a retained, Roblox-style GUI hierarchy to the game's immediate-mode renderer, and a bridge for driving the game's own windows.

### Building custom UI
- **Instances:**
  - Containers: `ScreenGui`, `Frame`, `CanvasGroup`, `ScrollingFrame`.
  - Elements: `TextLabel`, `TextButton`, `ImageLabel`, `ImageButton`.
  - Layout and styling: `UIListLayout`, `UIGridLayout`, `UIPadding`, `UIStroke`, `UICorner`, `UIScale`, `UISizeConstraint`, `UIAspectRatioConstraint`, `UIGradient`.
  - Value objects: `NumberValue` and the other `…Value` types.
- **Data types:** `UDim`, `UDim2`, `Vector2`, `Rect`, `Color3`, `ColorSequence`, `NumberSequence`, `NumberRange` (all tweenable through `:Lerp`).
- **Gradients and crossfades:** multi-stop `UIGradient` colour and transparency across frames, images, strokes and text. `RbxUI.Crossfade(fromGui, toGui, duration, directionAngle, softness)` crossfades or wipes between screens.
- **Input:** every visible button gets an invisible native hitbox window, so hover, press and click events work without blocking the controls underneath.
  ```lua
  local gui = Instance.new("ScreenGui")
  gui.ReferenceResolution = Vector2.new(1280, 720)
  local btn = Instance.new("TextButton", gui)
  btn.Position, btn.Size, btn.Text = UDim2.fromOffset(100, 200), UDim2.fromOffset(180, 36), "QUICK LOGIN"
  btn.Activated:Connect(function() UI.LoginWnd:StartLogin() end)
  ```

### Transforms reach children
- `GroupTransparency` (and `GroupColor3`) on any GuiObject applies to all its descendants.
- **`AnchorPoint` is the pivot**, as in Roblox. `Position` places the AnchorPoint, and size or `UIScale` changes grow around it: `(0, 0)` grows from the top-left, `(0.5, 0.5)` from the centre.
- `IgnoreParentTransforms = true` opts an element out of its ancestors' position, size, `UIScale`, transparency, tint and clipping (it lays out against the ScreenGui). It still follows `Visible` and is destroyed with its parent.

### Driving native windows: `RbxUI.Bridge(wnd)`
```lua
local play = RbxUI.Bridge(UI.Login_SteamLogInBtn)        -- one cached NativeFrame per window
play.Text = "Play"                                        -- "^key" strings are localized
play.TextColor3 = Color3.fromRGB(255, 210, 74)
play.GroupTransparency = 1                                -- frame, effects, label and child windows
play.AnchorPoint = Vector2.new(0.5, 0.5)
TweenService:Create(play, TweenInfo.new(0.1), { Scale = 1.05, Translation = Vector2.new(0, -4) }):Play()
play.Position = UDim2.new(0.5, 0, 1, -60)                 -- explicit placement takes it off its locator
play.Linked = true                                        -- …and this puts it back
```
- **Properties:** `Text`, `TextColor3`, `TextTransparency`, `GroupTransparency`, `IgnoreParentTransforms`, `Position` / `Size` (`UDim2` in the parent window), `ReferenceResolution` (offsets in, e.g., 1280×720 `.sanim` pixels), `AnchorPoint`, `Scale`, `Translation` (Rel units), `Visible`, `Linked`.
- **Methods:** `:Refresh()`, `:ResetTransform()`.
- **Transforms and locators:** `Scale` and `Translation` act about `AnchorPoint` on top of the window's placement. A window placed by a `.sanim` locator is borrowed while transformed and handed back at `Scale` 1 / `Translation` 0.
- **Transparency** reaches layers, effects, native child windows and their bridges. Labels that ignore alpha are hidden while faded and redrawn with the same font, rect and colour. Edit fields are never redrawn, because they may contain a password.
- **TweenService integration:** `TweenService` `Transparency` on any native window goes through its bridge automatically.

---

## Command-line patcher

```powershell
python patcher.py --install                 # auto-detects the game folder
python patcher.py --status
python patcher.py --uninstall
python patcher.py --game-dir "D:\SteamLibrary\steamapps\common\star conflict" --install
```

`patcher.py` handles the Server Selector only. Its `--uninstall` restores `loginwnd.lua.orig` when one exists, which removes **every** mod. To remove a single mod, use the graphical patcher. The UI Overhaul's command-line installer is `ui_overhaul/install.py` (`--install`, `--uninstall` strips only its own blocks, `--status`).

---

## Project structure

```
StarConflict_ServerSelector/
├── .github/workflows/release.yml   # builds the .exe and portable zip, publishes the release notes from CHANGELOG.md
├── StarConflict_Patcher.pyw        # graphical patcher (Omega UI)
├── omega_ui.py                     # Omega UI framework
├── Launch_Patcher.bat              # runs the .pyw (portable package)
├── patcher.py                      # command-line installer (Server Selector)
├── server_selector_mod.lua         # Server Selector mod source
├── ui_overhaul/                    # UI Overhaul (developed in SC_UIRenderer/mods)
│   ├── tweenservice.lua            #   TweenService
│   ├── rbxui.lua                   #   RbxUI toolkit and native bridge
│   ├── login_tween_demo.lua        #   login screen overhaul
│   └── install.py                  #   command-line installer
├── assets/                         # screenshots and GIFs for the README
├── validate_lua.py                 # Lua syntax / block-balance check
├── star_conflict.ico
├── README.md                       # player guide
├── TECHNICAL.md                    # this file
└── CHANGELOG.md
```

The UI Overhaul is developed and tested in the companion `SC_UIRenderer` project: a headless emulator of the game's UI that boots the real login screen, so changes can be checked at any resolution before they reach the game.
