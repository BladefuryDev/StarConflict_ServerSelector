# Star Conflict Community Server Selector

[![Release](https://img.shields.io/github/v/release/BladefuryDev/StarConflict_ServerSelector?color=0ea5e9&label=Release)](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://github.com/BladefuryDev/StarConflict_ServerSelector)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Play Star Conflict on community and private servers without retyping addresses every time.

This small patcher adds a **server list** to the game's login screen. Save your servers once, pick one from a dropdown, and set a favourite that's ready every time you launch. If you'd like the login screen to look a bit nicer too, the optional **UI Overhaul** adds a smooth animated intro and a one-click **Play** button.

![Login screen with the UI Overhaul](assets/quickplay_showcase.gif)

---

## What you get

| Mod | What it does |
| :--- | :--- |
| **Server Selector** (the main one) | A server dropdown on the login screen. Add, save, delete and switch between servers, and mark one as your default so it's picked automatically at launch. |
| **UI Overhaul** (optional) | A cinematic fade-in for the login screen, buttons that react when you hover them, and a golden **Play** button: once you tick "Remember me", logging in is a single click. |

Install either one, or both. Each has its own tab in the patcher and can be removed on its own.

---

## Install in 3 steps

1. **Download** `StarConflict_Patcher.exe` from the [latest release](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest).
2. **Run it.** It finds your Star Conflict folder automatically. If it can't, click **⚙ Browse** and pick the game folder (the one with `data` inside, for example `...\steamapps\common\star conflict`).
3. **Click ⚡ Install Server Selector.** Want the UI Overhaul too? Switch to its tab and click **⚡ Install UI Overhaul**. Then start the game.

> **Windows says "Windows protected your PC"?** That warning appears for any app that isn't signed by a big publisher. Click **More info → Run anyway**. Prefer not to run an .exe? Grab `StarConflict_Patcher_Portable.zip` instead and double-click `Launch_Patcher.bat` (needs [Python](https://www.python.org/downloads/) 3.8 or newer).

---

## Prefer not to run anything? Install by hand

The mods are plain text that gets added to the end of one game file. You can do that yourself with Notepad and nothing else, and read every line before it goes in.

**1. Get the mod files.** Download the source code of the [latest release](https://github.com/BladefuryDev/StarConflict_ServerSelector/releases/latest) (*Source code (zip)*) and unzip it. You need:
- `server_selector_mod.lua` for the Server Selector.
- `ui_overhaul/tweenservice.lua`, `ui_overhaul/rbxui.lua` and `ui_overhaul/login_tween_demo.lua` for the UI Overhaul. All three are needed, in that order.

**2. Back up the game file.** Go to your game folder, then `data\ui\scripts\windows\`. Copy `loginwnd.lua` and name the copy `loginwnd.lua.orig`.

**3. Open `loginwnd.lua` in Notepad** and press **Ctrl+End** to jump to the very end. Press **Enter** once to start a new line.

**4. Paste the mods at the end**, each starting on its own line:
- **Server Selector:** type this line first:
  ```
  -- BEGIN STAR CONFLICT SERVER SELECTOR MOD
  ```
  then paste the whole of `server_selector_mod.lua`, then type this line:
  ```
  -- END STAR CONFLICT SERVER SELECTOR MOD
  ```
- **UI Overhaul:** paste the whole of `tweenservice.lua`, then `rbxui.lua`, then `login_tween_demo.lua`. These already begin with `-- BEGIN …` and end with `-- END …` lines, so add nothing.

You can install either mod on its own. If you install both, put the Server Selector first.

**5. Save.** Use **File → Save As**, keep the name `loginwnd.lua`, and set **Encoding** to **UTF-8** (not "UTF-8 with BOM"). Then start the game.

**To remove a mod**, delete everything from its `-- BEGIN …` line to its matching `-- END …` line, or put your `loginwnd.lua.orig` back. **To update**, remove the old blocks and paste the new files the same way. **If the login screen looks broken**, restore `loginwnd.lua.orig`; the usual cause is a block that wasn't pasted completely.

Mods installed this way use the same markers as the patcher, so you can still switch to the patcher later.

---

## Using it in-game

**Add a server**
1. Click **Add** next to the server dropdown on the login screen.
2. Type the address (for example `play.example.net` or `192.168.1.100`) and the port. Leave the port empty to use `3801`, or paste `address:port` into the address box.
3. Click **Save**. The server is added and selected.

**Switch servers.** Pick one from the dropdown, then log in as usual.

**Set a default.** Select a server and click **Default** (or right-click it in the list → *Set as Default*). It's marked `[Default]` and selected for you every time the game starts. Nothing connects until you press Play.

**Remove a server.** Select it and click **Delete** (or right-click → *Delete Server*).

**Quick Play (UI Overhaul).** Tick **Remember me** after entering your details. The form folds away into a golden **Play** button with "Welcome, *your name*" underneath. Click **Play** to log in, or click *"Click here to change."* to switch accounts.

Your servers are stored in your normal Star Conflict pilot profile, so they survive restarts and game updates.

---

## Updating, removing, fixing

- **Updating:** the patcher tells you when a new version is out. Download it, then click **↻ Reinstall / Update** on each tab. Your saved servers are kept.
- **After a game update:** the game may replace the patched file. If the server list disappears, run the patcher and install again.
- **Removing a mod:** click **↺ Uninstall** on its tab. The other mod keeps working.
- **Something looks broken?** Click **↺ Restore original** in the patcher. It puts back the game's untouched login screen file (backed up on first install) and removes every mod. You can reinstall afterwards.

---

## Questions

**Does it change anything besides the login screen?**
No. It edits a single login-screen script (`data/ui/scripts/windows/loginwnd.lua`) and keeps a backup of the original next to it.

**Where are my servers saved?**
In your Star Conflict pilot profile. There's no extra file to look after.

**Can I use it with just one of the two mods?**
Yes. The Server Selector works on its own, and so does the UI Overhaul.

---

## More

- [CHANGELOG.md](CHANGELOG.md): what changed in each version.
- [TECHNICAL.md](TECHNICAL.md): how it works under the hood, the Lua libraries (TweenService, RbxUI) for modders, the command-line patcher and the project layout.

## Credits

- **Alan Hexfury**: UI development, UX design for the patcher, and mod layout.
- **Claude & Gemini**: Reverse-engineering, the headless UI renderer, the UI Overhaul libraries, and mapping the Star Conflict UI engine.
