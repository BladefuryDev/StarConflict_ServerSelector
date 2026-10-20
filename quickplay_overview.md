# Classic Golden MMO Play Button & "Remember Me" Quick-Play Mode

This update restores the classic gold MMO play button (`UI.Login_SteamLogInBtn` / `login_enter_2.sanim`) for community and private servers, introducing a streamlined **Quick-Play mode** with Roblox-style animations, bottom-anchored engine locator support, and responsive tactile feedback.

---

## 1. Visual Walkthrough & State Comparison

````carousel
![Full End-to-End Showcase (Boot Sequence -> Resting Quick-Play -> Pure Vertical Hover Lift -> Form Expand -> Re-check)](quickplay_showcase.gif)
<!-- slide -->
![Boot Keyframe 1: Pure Black Cinematic Boot (t=0.0s)](quickplay_boot_0s.png)
<!-- slide -->
![Boot Keyframe 2: Space Zoom & Side Buttons Entering (Center Empty) (t=0.67s)](quickplay_boot_side_buttons.png)
<!-- slide -->
![Boot Keyframe 3: Golden Play Button Dropping in Last (t=1.00s)](quickplay_boot_play_enter.png)
<!-- slide -->
![Boot Keyframe 4: Fully Settled Quick-Play Resting State (t=1.67s)](quickplay_boot_settled.png)
<!-- slide -->
![Quick-Play Minimized Mode (Standard Golden Play Button)](quickplay_minimized.png)
<!-- slide -->
![Expanded Login Form Mode](quickplay_expanded.png)
<!-- slide -->
![Transition Animation](quickplay_transition.gif)
````

### Key UI Features
1. **Cinematic Boot Choreography ("Ideally Last")**:
   - **Initial Black Fade**: During the initial zoom-out and black fade-in (`0.0s - 0.8s`), the Golden Play Button and Welcome Bar are completely hidden (`Transparency = 1`, `effAlpha = 0`, unlinked). No UI elements leak onto the dark screen.
   - **Staggered Menu Cascade**: Side buttons cascade in from right to left (`0.40s - 0.78s`).
   - **Centerpiece Arrival**: The Golden Play Button drops in last at `0.83s` with a punchy `Back.Out` drop (`-26px` to rest), followed by the Welcome Bar at `0.95s` (`Cubic.Out`). Everything settles cleanly by `~1.35s`.
2. **Tactile Hover Dynamics**:
   - **Golden Play Button**: Pure vertical lift (`dy = -SY(4)`) with centered scale (`1.05x`) without any horizontal drift.
   - **Welcome Bar**: Smooth color transition into login gold with an animated underline morph on hover.
3. **Standard Native Geometry & "Play" Label**:
   - The golden button uses its native `150×40` geometry and maintains its link to the engine locator (`enter_2` with `anchor "BC"`), guaranteeing precise bottom-center alignment across all screen resolutions and aspect ratios (1080p, 1440p, 4K, ultrawide).
   - The button text is relabeled from `"Login"` to `"Play"` using the engine's glowing gold text layer (`UI.Login_SteamLogInBtn.layers.TEXT`).
4. **Interactive Welcome Bar (`UI.Login_WelcomeBarBtn`)**:
   - Centered directly beneath the Golden Play Button with responsive vertical spacing (`+6px`).
   - Segmented multi-run text layout:
     - `"Welcome, "` (silver `0xFFA0B0C0`)
     - `#Username#` (login accent gold `0xFFFFD24A`)
     - `" | "` (slate separator `0xFF506070`)
     - `"Click here to change."` (sky-blue `0xFF66B2FF`, morphs to bright gold `0xFFFFDA44` with an underline on hover)
5. **Instant Account Switching & Form Transitions**:
   - Clicking `"Click here to change."` unchecks Remember Me, clears stored authorization data, slides the Golden Play Button and Welcome Bar upward/out, and restores the full E-mail/Password form with auto-focus on the account text input.
   - Checking "Remember me" on the form collapses the input fields upward and smoothly returns to Quick-Play mode.

---

## 2. Technical Details & Engine Quirks Resolved

| Quirk / Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Play Button Visible in Black Phase** | Boot initialization previously called `MinimizeToPlayBtn(false)` before the intro ran, setting `Transparency = 0` immediately. | Enforced `tr = demo.played and 0 or 1` and initialized `eff:SetAlpha(0)` and text alpha to 0; Quick-Play elements remain 100% invisible until their entrance. |
| **Entrance Timing** | Play button previously entered at `0.49s` while the background was still dark and before side buttons finished. | Staggered entrance: Play button starts at `UI_START_DELAY + 0.48s = 0.83s`, Welcome Bar at `0.95s`. Drops in last as the centerpiece. |
| **Diagonal Hover Drift** | Play hover animation previously used `dx = -0.5 * bw * 0.05` alongside `dy = -SY(4)`, resulting in diagonal movement. | Removed horizontal shift (`dx = 0`); button lifts strictly vertically. |
| **Welcome Bar Invisibility in Live Game** | `ButtonWnd` in Targem C++ UI engine expects an appearance state map for all layers, causing text layer 1 to not render. | Switched `UI.Login_WelcomeBarBtn` to `className = "Wnd"` with layer 0 as texture and layer 1 as `WLS_OWNERDRAW`. |
| **`bad property name 'z'` on `Vec2`** | `TweenService` checked `a.z ~= nil` on userdata vectors; engine `UI:Vec2` throws C++ error on missing property access. | Wrapped property lookup with defensive `pcall`. |
| **Locator Anchoring (`anchor "BC"`)** | `login_main.sanim` uses `anchor "BC"` (Bottom Center) for `"enter_2"`. Unlinking the button removes engine anchor calculation, breaking widescreen positioning in `game.exe`. | Re-linked button to `"enter_2"` on transition completion and rest; engine maintains bottom-center positioning dynamically across all resolutions. |

---

## 3. Verification & Sync Status

- [x] **Headless UI Renderer**: Passed end-to-end recording in `Projects/SC_UIRenderer/tools/record_showcase.py` (138 frames, verified t=0.0s pure black, empty center during cascade, Play button dropping in last at ~0.83s, hover lift, expand form, and remember me re-check).
- [x] **Lua 5.1 Compilation**: Verified via `lupa` across all mod blocks (`TWEENSERVICE`, `RBXUI`, `LOGIN_TWEEN_DEMO`).
- [x] **Live Game Install**: Installed into `G:\SteamLibrary\steamapps\common\star conflict\data\ui\scripts\windows\loginwnd.lua`.
- [x] **Mirror Sync**: All Lua files verified bit-for-bit identical across `Projects/SC_UIRenderer/mods/` and `Projects/StarConflict_ServerSelector/ui_overhaul/`.
