# Star Conflict UI Overhaul, Server Selector & RbxUI Toolkit — AI Model Handoff & Changelog

> **Purpose**: This document provides complete architectural and changelog context for all AI models (Claude, Gemini, etc.) and developers working across `Projects/SC_UIRenderer` and `Projects/StarConflict_ServerSelector`.

---

## 1. Repository & File Map

Both projects share the same Lua mod blocks installed into `<StarConflict>/data/ui/scripts/windows/loginwnd.lua`:

| File | Mirror in Patcher Repo | Marker Block in `loginwnd.lua` | Role |
|---|---|---|---|
| `Projects/SC_UIRenderer/mods/server_selector_mod.lua` | `Projects/StarConflict_ServerSelector/server_selector_mod.lua` (+ `EMBEDDED_MOD_LUA` in `StarConflict_Patcher.pyw`) | `-- BEGIN STAR CONFLICT SERVER SELECTOR MOD` … `-- END STAR CONFLICT SERVER SELECTOR MOD` | Community Server Selector panel (`UI.Login_ServerDockWnd`, `UI.Login_ServersComboBox`, Add/Default/Delete `EffectButtonWnd`s, profile persistence). |
| `Projects/SC_UIRenderer/mods/tweenservice.lua` | `Projects/StarConflict_ServerSelector/ui_overhaul/tweenservice.lua` | `-- BEGIN TWEENSERVICE` … `-- END TWEENSERVICE` | Roblox-style `TweenService` (`TweenInfo.new`, `Enum.EasingStyle`, `Enum.EasingDirection`, `TweenService:Create`, `TweenService:Layer`, `TweenService:ConnectHover`, `TweenService:BindToRenderStep`). |
| `Projects/SC_UIRenderer/mods/rbxui.lua` | `Projects/StarConflict_ServerSelector/ui_overhaul/rbxui.lua` | `-- BEGIN RBXUI` … `-- END RBXUI` | Roblox-style retained GUI & DataType toolkit (`Instance.new`, `ScreenGui`, `Frame`, `CanvasGroup`, `TextLabel`, `TextButton`, `ImageLabel`, `ImageButton`, `ScrollingFrame`, `UIListLayout`, `UIGridLayout`, `UIPadding`, `UIStroke`, `UICorner`, `UIScale`, `UISizeConstraint`, `UIAspectRatioConstraint`, `UIGradient`, `UDim`, `UDim2`, `Vector2`, `Rect`, `Color3`, `ColorSequence`, `NumberSequence`, `ValueBase`). |
| `Projects/SC_UIRenderer/mods/login_tween_demo.lua` | `Projects/StarConflict_ServerSelector/ui_overhaul/login_tween_demo.lua` | `-- BEGIN LOGIN_TWEEN_DEMO` … `-- END LOGIN_TWEEN_DEMO` | Cinematic Login Boot Sequence + interactive hover scale animations on the login screen. |
| `Projects/SC_UIRenderer/mods/install.py` | `Projects/StarConflict_ServerSelector/ui_overhaul/install.py` | *(CLI installer)* | Installs/uninstalls `TWEENSERVICE`, `RBXUI`, and `LOGIN_TWEEN_DEMO` blocks into `loginwnd.lua` with a `lupa` Lua 5.1 compile check. |
| `Projects/SC_UIRenderer/scui/` | *(Headless UI Renderer)* | — | Python + `lupa` (Lua 5.1) + Pillow headless emulator of `game.exe`'s UI subsystem (`engine.py`, `runtime.py`, `session.py`, `sanim.py`, `render.py`, `tpak.py`, `font.py`). |

> **IMPORTANT SYNC RULE**: Whenever you edit any file in `Projects/SC_UIRenderer/mods/`, always sync the changes to `Projects/StarConflict_ServerSelector/ui_overhaul/` (and `server_selector_mod.lua` + `EMBEDDED_MOD_LUA` in `StarConflict_Patcher.pyw` if modifying the Server Selector).

---

## 2. Chronological Summary of Bug Fixes & Features Added

### 2.1. Fix 1 — `UI.LoginWnd.def` Stripped After Window Build (Broken Intro Animations)
- **Symptom**: In `game.exe`, the login intro animations did not play and `PATCH_NAME` did not pulse, whereas `scui` originally played them.
- **Root Cause**: The C++ engine (or window creation flow) clears `.def` from window instances and prototypes after `CreateWnd`/`InheritWnd` finishes building a window. `login_tween_demo.lua` previously looked up widget `.sanim` locator links (`UI.LoginWnd.def[name].link`) at runtime inside `F_Show`, found `nil`, and safely skipped unlinking and animating.
- **Fix**:
  - `scui/runtime.py`: Updated the headless renderer to also clear `.def` on window tables and prototypes after window creation so `scui` faithfully reproduces `game.exe` behavior.
  - `login_tween_demo.lua`: Captures all `.sanim` locator link entries (`LINKS[name] = d.link`) **once at script-load time** while `UI.LoginWnd.def` is still populated.

### 2.2. Fix 2 — Mid-Game Resolution Changes & Server Selector Button Scaling Bug
- **Symptom 1**: Switching resolutions in-game (e.g. `1920x1080` ↔ `2560x1440`) left the Server Selector dock panel and `Add` / `Default` / `Delete` buttons sized and positioned for the old resolution.
- **Symptom 2**: Even without a resolution change, hovering or clicking the `Add` / `Default` / `Delete` buttons caused their `.sanim` frame (`login_simpleBtn` / `login_univer_btn.sanim`) to either disappear or balloon to a huge size!
- **Root Cause**:
  1. `UpdateServerDockLayout()` was only called on `F_Show` and `F_OnScreenPosChanged`, never after a D3D9 device reset (`UI.screenWidth` / `UI.screenHeight` change).
  2. When `EffectButtonWnd` switches states (`idle` -> `over` -> `press` -> `disable` via `SetVisualState` / `StartAnimation`), the C++ engine resets the `.sanim` effect instance's scale back to `(1, 1)`! Furthermore, `ScaleBtnToSlot` was measuring `eff:GetSize()` **while** `eff:SetScale(sx, sy)` was already applied—In `game.exe`, `eff:GetSize()` returns the **already-scaled** size (`base * scale`), unlike `scui` where `GetSize()` returned unscaled size. Re-measuring `GetSize()` on a scaled effect multiplied or divided the scale on every state change!
- **Fix (`server_selector_mod.lua` & `scui/runtime.py`)**:
  - Updated `scui/runtime.py` `SanimInstance.GetSize()` to multiply by `(self.scale_x, self.scale_y)` so `scui` matches `game.exe` (`GetSize()` returns scaled size).
  - In `ScaleBtnToSlot(btn, w, h)` (`server_selector_mod.lua`):
    - Resets `eff:SetScale(UI:Vec2(1, 1))` **before** calling `eff:GetSize()` whenever measuring `btn.baseSize`, guaranteeing an unscaled measurement.
    - Stores `btn.slotW, btn.slotH = w, h` and hooks `btn.SetVisualState` (`HookBtnRescale`) so every hover/press/disable state transition immediately re-applies `ScaleBtnToSlot(self, self.slotW, self.slotH)` after the engine starts the new `.sanim` animation.
  - Added a per-frame screen-dimension watcher in `UI.LoginWnd:F_OnNewFrame` that detects `UI.screenWidth` / `UI.screenHeight` changes, clears `btn.baseSize = nil`, and re-runs `self:UpdateServerDockLayout()`.

### 2.3. Feature 1 — Menu Button Hover Animation Adjustment
- **Change (`login_tween_demo.lua` & `tweenservice.lua`)**:
  - Reduced hover animation duration on the 8 right-hand side menu buttons (`SIDE`) by half (`0.18s` → `0.09s`) and switched from horizontal slide (`dx`) to a subtle centered scale-up (`scale = 1.05`, growing 5% from center and returning to `1.0` on mouse-out).
  - Extended `TweenService:ConnectHover(wnd, spec)` to accept `scale = <factor>` (computing centered `Left`, `Top`, `Width`, `Height` goals around the widget's rest center and restoring exact rest rect on `F_OnMouseOut`).

### 2.4. Feature 2 — Cinematic Login Boot Sequence
- **Design (`login_tween_demo.lua`, `server_selector_mod.lua`, `scui/engine.py`)**:
  - **Seamless Transition from Loading Screen**:
    - Background `.sanim` layers (`BG_EFFECT` and `BG2_EFFECT`) start with vertex color `0xFF000000` (pure opaque black, `Alpha = 255`) rather than `Alpha = 0`. Why? Because in `game.exe`, setting `BG_EFFECT` alpha to `0` makes the login background transparent, revealing the uninitialized 3D scene behind `LoginWnd` instead of black! Using opaque black vertex tint (`0xFF000000` → `0xFFFFFFFF` over `1.15s` `Sine.Out`) guarantees a true fade-from-black in both `game.exe` and `scui`.
    - Updated `scui/engine.py` `_draw_effect` to apply `inst.color` RGB vertex tinting to `.sanim` quads so `scui` renders `eff:SetColor(0xFF000000)` identically to `game.exe`.
  - **Centered Background Zoom-Out**:
    - `BG_EFFECT` and `BG2_EFFECT` start zoomed in at `1.10x` (`BG_START_SCALE = 1.10`) and smoothly zoom out to `1.00x` over `2.20s` (`Cubic.Out`), keeping the `1024x768` center pinned via `Position = Vec2(512 * (1 - s), 384 * (1 - s))`.
  - **Delayed & Staggered UI Entrance (`UI_START_DELAY = 0.35s`)**:
    - All UI chrome (`BG3_EFFECT`, `TEXT_LAYERS`, `WARNING` `MetaText` layer via a `LW.F_DrawLayer` hook, `FIELDS`, `SERVER_UI`, `ACCOUNT_EFFECT`, `PASSWORD_EFFECT`, `PATCH_NAME`, and `SIDE` buttons) starts hidden (`Transparency = 1`) for the first `0.35s` while the background emerges from black, then fades/slides in with staggered delays.
    - Added `self.introAlpha` support to `UI.Login_ServerDockWnd:F_DrawLayer` in `server_selector_mod.lua` so the owner-drawn Server Selector dock plate and header text fade in smoothly with the rest of the login form.

### 2.5. Feature 3 — Expanded Roblox-Style UI Toolkit (`rbxui.lua`)
- **Motivation**: Working with Star Conflict's native `.sanim`-linked `UI.Wnd` widgets is finicky for custom UI because `.sanim` object locators fight manual positioning, `.def` tables are stripped after creation, and native widgets lack automatic layouts, corners, strokes, or gradients.
- **Architecture of `rbxui.lua`**:
  - **Retained-Mode Roblox DOM over Immediate-Mode `UI.drawer`**:
    - Modders build interfaces using standard Roblox API (`Instance.new("ScreenGui")`, `Frame`, `CanvasGroup`, `TextLabel`, `TextButton`, `ImageLabel`, `ImageButton`, `ScrollingFrame`, `UIListLayout`, `UIGridLayout`, `UIPadding`, `UIStroke`, `UICorner`, `UIScale`, `UISizeConstraint`, `UIAspectRatioConstraint`, `UIGradient`, `NumberValue`, etc.).
    - Each `ScreenGui` mounts a single full-screen (`1024x768` Rel), click-through (`WS_NOT_MOUSE_REACT + WS_NOT_KB_REACT`), owner-drawn (`WLS_OWNERDRAW`) `UI.Wnd` onto `UI.LoginWnd` (or any custom `HostWnd`).
    - Because the canvas window has `WS_NOT_MOUSE_REACT`, empty space in a `ScreenGui` never blocks native Star Conflict controls (`ComboBox`, `EditWnd`, native buttons) underneath!
  - **Hybrid Native Hitbox `ButtonWnd`s for Interactive Elements**:
    - For every visible `GuiButton` (`TextButton`, `ImageButton`) or `GuiObject` with `Active = true`, `RbxUI` automatically spawns and syncs a lightweight, invisible `UI.ButtonWnd` child (`UI["RbxHit_<id>"]`, `layers = {}`) matching the element's `AbsolutePosition` and `AbsoluteSize`.
    - Native C++ hit-testing dispatches mouse enter/leave/move/down/up/click/wheel directly to the `GuiObject`'s `RBXScriptSignal`s (`Activated`, `MouseButton1Click`, `MouseButton1Down`, `MouseButton1Up`, `MouseButton2Click`, `MouseEnter`, `MouseLeave`, `MouseMoved`, `MouseWheelForward`, `MouseWheelBackward`, `InputBegan`, `InputEnded`), and updates `GuiState` (`Idle`, `Hover`, `Press`) for automatic `AutoButtonColor` / `HoverColor3` / `PressColor3` feedback.
    - Linking a custom button to any native Star Conflict function is a one-liner:
      ```lua
      playBtn.Activated:Connect(function()
          UI.LoginWnd:StartLogin()
      end)
      ```
  - **Seamless `TweenService` Integration & Gradient / Crossfade Support**:
    - `tweenservice.lua` `lerpValue` checks `if type(a) == "table" and type(a.Lerp) == "function" then return a:Lerp(b, t) end` first, so `TweenService:Create(instance, tweenInfo, goal)` natively interpolates `UDim2`, `UDim`, `Vector2`, `NumberRange`, `Color3`, `ColorSequence`, and `NumberSequence` properties (`Position`, `Size`, `BackgroundColor3`, `TextColor3`, `ImageColor3`, `BackgroundTransparency`, `GroupTransparency`, `UIGradient.Color`, `UIGradient.Transparency`, `UIGradient.Offset`, `UIGradient.Rotation`).
    - **Multi-Stop Color Ranges & Alpha Gradients**:
      - `ColorSequence.new(c0, c1)` / `ColorSequence.fromColors(c1, c2, c3, ...)` / `ColorRange` supports any number of color keypoints and `:Lerp(goalSeq, alpha)` for live morphing gradients.
      - `NumberSequence.new(t0, t1)` / `NumberSequence.fromValues(...)` / `NumberSequence.fromAlpha(a0, a1, ...)` (accepts `0..1` or `0..255` alpha values and converts to transparency) / `NumberSequence.crossfade(progress, softness, reverse)` / `NumberRange.new(min, max)`.
      - `UIGradient` applies across `Frame`/`GuiObject` backgrounds (respecting `UICorner` rounded corners), `ImageLabel`/`ImageButton` textures (via UV-sliced `DrawImagedRect`), `UIStroke` borders (via a child `UIGradient` on the `UIStroke`), and `TextLabel`/`TextButton` text (via clip-rect band slicing).
      - `RbxUI.Crossfade(fromGui, toGui, duration, directionAngle, softness, easingStyle, callback)` performs either a uniform alpha crossfade (`directionAngle = nil`) or a directional alpha-gradient wipe crossfade (`directionAngle = 0` Left→Right, `90` Top→Bottom, `45` Diagonal, etc.).

### 2.6. Feature 4 — Classic Golden MMO Play Button & "Remember Me" Quick-Play Mode
- **Origin & Historical Discovery**:
  - In earlier official MMO versions of Star Conflict, the login screen featured a prominent golden Play button (`UI.Login_SteamLogInBtn`, located at `"enter_2"` in `login_main.sanim`, 150×40). It uses `login_steamLogInBtn` (`common_effects.txt#L435-L437`), rendering `ui\graphics\login_screen\login_enter_2.sanim` with `hangar.tif` UVs `(0.00195, 0.18652)`..`(0.19824, 0.22266)`, font `"Large_outl"`, and gold text colors (`0xffff9100` idle, `0xffffda02` bright gold hover/press).
  - In private/community servers, non-Steam players previously only saw the utilitarian E-mail/Password form and small generic buttons (`Login_LogInBtn`), while the golden button was only shown for Steam accounts (`IsSteamAccount()`).
- **Design & Behavior (`login_tween_demo.lua`)**:
  - **Auto-Boot Detection**:
    - On login screen boot, `hasRememberedAccount()` checks whether credentials exist in `_G.GetProfileTable().lastAccount` and `RememberCheckBox:IsChecked()`.
    - If remembered credentials exist, the login screen initializes directly in **Quick-Play Mode**: the input fields remain hidden, and the Golden Play Button appears prominently with the custom Welcome Bar positioned directly beneath it.
  - **Dynamic Welcome Bar (`UI.Login_WelcomeBarBtn`)**:
    - A custom owner-drawn interactive button widget (`UI.ButtonWnd`) centered directly beneath `UI.Login_SteamLogInBtn`.
    - Dynamic multi-segment text layout: `"Welcome, "` (silver `0xffa0b0c0`), `#Username#` (gold `0xffffd24a`), `" | "` (slate `0xff506070`), and `"Click here to change."` (sky-blue `0xff66b2ff` idle, smoothly morphs to bright gold `0xffffda44` with underline on hover via owner-drawn quad line).
    - Polled hover state with smooth tweening (`hoverMix` 0..1 over `0.09s` `Quad.Out`).
  - **Live Toggle & Transitions**:
    - **Checking "Remember me" on the form**: If both username and password are entered, checking "Remember me" saves authorization data, collapses the form fields upward/out (`Transparency = 1`, `dx = -20`), and slides down/fades in the Golden Play Button (`0.52s` `Back.Out`, `dy = -26 -> 0`) and Welcome Bar (`0.46s` `Cubic.Out`).
    - **Switching Accounts**: Clicking `"Click here to change."` immediately triggers `demo.ExpandToForm(true)`: unchecks "Remember me", calls `LoginWnd:ClearSavedAuthorizationData()` (wrapped in `pcall`), animates the Golden Play Button and Welcome Bar upward/out, smoothly fades the form fields back in, and focuses `UI.Login_AccountEditWnd`.
  - **Tactile Hover Scaling**:
    - The Golden Play Button is hooked to `TweenService` hover scaling (`scale = 1.05`, `0.075s` `Quad.Out`) matching the responsive feel of the side menu buttons.
- **Engine Quirks & Bug Fixes Resolved During Implementation**:
  1. **`FONT.TF_HCENTER` vs `FONT.TF_CENTER`**:
     - Star Conflict's Targem C++ font engine exposes `FONT.TF_HCENTER` (`0x2`), not `FONT.TF_CENTER`. Calling `FONT.TF_CENTER` returned `nil`, breaking bitwise addition in Lua 5.1. Always use `(FONT.TF_HCENTER or 2) + (FONT.TF_VCENTER or 32) + FONT.TF_SINGLELINE + FONT.TF_NOCLIP`.
  2. **`UI:GetUiScale` Expects Resolution Table**:
     - `UI:GetUiScale(baseResolution)` crashes if passed a scalar number. It requires a table with `.x` and `.y` (e.g. `RES_720 = { x = 1280, y = 720 }`).
  3. **`Profile.Save()` Mock for Headless Emulation**:
     - In `scui`, clearing credentials calls `Profile:Save()`. Global `Profile` was uninitialized in `scui/env_defaults.lua`, causing headless tests to fail. Added fallback mock in `scui/env_defaults.lua` and defensive `pcall` in `login_tween_demo.lua`.
  4. **Base Alpha Capture Guard in `TweenService`**:
     - If a widget or effect starts with alpha `0`, capturing `eff:GetAlpha()` returned `0`, locking future tweens from ever restoring opacity (`0 * factor = 0`). Updated `captureAlpha` to enforce `a > 0 and a or 255`.
  5. **Golden Play Button Bottom-Center Locator Anchoring & "Play" Labeling**:
     - The Golden Play Button (`UI.Login_SteamLogInBtn`) is anchored via locator `"enter_2"` with `anchor "BC"` (Bottom Center) in `login_main.sanim`.
     - Unlinking the button entirely to manually position it breaks widescreen/ultrawide dynamic bottom alignment in `game.exe`, causing the button to float to the middle of the screen at 1080p/1440p.
     - The button is re-linked via `relinkWnd("UI.Login_SteamLogInBtn", playBtn)` upon transition completion and during rest, letting the engine dynamically compute bottom-center alignment across all aspect ratios.
     - The text is cleanly customized to `"Play"` via `playBtn:SetText("Play", playBtn.layers.TEXT)`.
     - Native size `150×40` is preserved.
     - **Pure Vertical Lift on Hover**: `login_enter_2.sanim` has `alignment "CM"` (Center-Middle), which naturally scales outward symmetrically from its center. Shifting `Left` during hover caused unsightly diagonal up/left drift. `hookHover` now applies a pure vertical lift (`PLAY_HOVER_LIFT = SY(4)`, `dx = 0`) so the button slides straight UP on hover and glides back down on mouseout with zero horizontal movement.
  6. **`ButtonWnd` vs `Wnd` for Owner-Drawn Widgets & `UI:Vec2` `.z` Engine Exception**:
     - In Targem C++, defining a window with `className = "ButtonWnd"` without standard button appearance states throws `Wnd::LoadLayersFromScript - empty 0 appearance with not zero numLayers specified` and fails object construction, suppressing all `F_DrawLayer` calls.
     - Custom owner-drawn widgets (such as `UI.Login_WelcomeBarBtn`) must use `className = "Wnd"` with a base transparent texture layer (layer 0) and an owner-drawn text layer (layer 1, `UI.WLS_OWNERDRAW + UI.WLS_RESIZABLE`), matching `UI.Login_ServerDockWnd`.
     - Mouse hover on `Wnd` is handled via `F_OnMouseIn` and `F_OnMouseOut`, and clicking via `F_OnMouseLButtonDown`.
     - In `tweenservice.lua`, checking `.z` on a 2D `UI:Vec2` userdata throws `bad property name 'z'` in Star Conflict C++. Vector component lookups now safely guard `.z` with `pcall`.
     - `TweenService:Create` was updated to support custom numeric properties (such as `hoverMix`) on table and window targets.

---

## 3. Critical Engine Gotchas (Must Read Before Editing Lua Mods)

1. **`UI:Vec2` / `UI:Vec3` / `UI:Quat` Ring Buffer (20-Slot Limit)**:
   - `uimanager.lua` recycles userdata from a 20-slot ring buffer (`UI.tempBufs`). **Never** store the return value of `UI:Vec2(...)` or `UI:Quat(...)` across frames. Use `RbxUI`'s pure-Lua `Vector2.new`, `UDim2.new`, `Rect.new`, and `Color3.fromRGB`, and only call `UI:Quat` / `UI:Vec2` transiently inside draw or C++ setter calls.
2. **Lua 5.1 200-Local Variable Limit**:
   - Every mod block appended to `loginwnd.lua` shares the top-level chunk's 200-local limit unless wrapped in `do ... end`. Always wrap mod blocks in `do ... end` (and sub-modules inside `rbxui.lua` in nested `do ... end` blocks), and always run `python Projects/SC_UIRenderer/mods/install.py --install` to verify compilation with `lupa` (Lua 5.1).
3. **`UI.LoginWnd.def` is `nil` at Runtime**:
   - In `game.exe`, `.def` is cleared after window construction. Any code that needs `UI.LoginWnd.def` metadata must capture it at script-load time, not inside `F_Show` or `F_OnNewFrame`.
4. **Effect Alpha vs. Layer Color**:
   - `.sanim` effects use `eff:SetAlpha(0..255)` for opacity and `eff:SetColor(0xAARRGGBB)` for RGB vertex tinting. Window layers use `wnd:SetColor(0xAARRGGBB, layerIdx)`.
5. **No `io` or `os` Library in `game.exe`**:
   - Persistence must use `GetProfileTable()` and `Profile:Save()`.
6. **Font Alignment Flags (`FONT.TF_HCENTER`)**:
   - Targem UI font flags define horizontal centering as `FONT.TF_HCENTER` (`0x2`). Do NOT use `FONT.TF_CENTER` (which is `nil`).
7. **Resolution Scaling Vectors**:
   - `UI:GetUiScale(baseRes)` requires a table with `{ x = ..., y = ... }` (e.g. `{ x = 1280, y = 720 }`). Passing a numeric scalar causes a runtime Lua crash: `attempt to index local 'baseResolution' (a number value)`.
8. **Engine Locator Anchoring (`anchor "BC"`) vs Manual Positioning**:
   - Locators defined in `.sanim` files can have anchors (e.g. `anchor "BC"` for Bottom Center). The C++ engine dynamically recalculates the linked window's Y position relative to the screen bottom for widescreen/ultrawide displays. Unlinking a bottom-anchored window permanently breaks widescreen positioning in `game.exe`; always re-link the window (`relinkWnd`) once transition tweens complete so the engine maintains proper viewport anchoring.
9. **`UI:Vec2` Has No `.z` Property**:
   - Indexing `v.z` on a `UI:Vec2` C++ userdata throws a fatal runtime exception `bad property name 'z'`. Always guard vector component accesses with `pcall` or use pure-Lua vector structures.
10. **`ButtonWnd` Requires Appearance States**:
    - In `def.className = "ButtonWnd"`, C++ requires appearance state maps for its button animations. For custom owner-drawn HUD plates or bars without button graphics, use `className = "Wnd"`, where `WLS_OWNERDRAW` layers dispatch `F_DrawLayer` cleanly.
