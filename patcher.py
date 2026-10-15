#!/usr/bin/env python3
"""
Star Conflict Community Server Selector Patcher
Installs / Uninstalls the Server Selector Mod into data/ui/scripts/windows/loginwnd.lua
"""

import os
import sys
import shutil
import argparse
import winreg

MOD_BEGIN_MARKER = "-- BEGIN STAR CONFLICT SERVER SELECTOR MOD"
MOD_END_MARKER   = "-- END STAR CONFLICT SERVER SELECTOR MOD"

COMMON_PATHS = [
    r"G:\SteamLibrary\steamapps\common\star conflict",
    r"C:\Program Files (x86)\Steam\steamapps\common\star conflict",
    r"C:\Program Files\Steam\steamapps\common\star conflict",
    r"D:\SteamLibrary\steamapps\common\star conflict",
    r"E:\SteamLibrary\steamapps\common\star conflict",
    r"F:\SteamLibrary\steamapps\common\star conflict",
]

def find_steam_libraries():
    """Attempt to discover Steam library folders from Windows registry."""
    found_paths = []
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam_path, _ = winreg.QueryValueEx(key, "SteamPath")
            if steam_path:
                steam_path = os.path.normpath(steam_path)
                found_paths.append(os.path.join(steam_path, "steamapps", "common", "star conflict"))
                vdf_path = os.path.join(steam_path, "steamapps", "libraryfolders.vdf")
                if os.path.isfile(vdf_path):
                    with open(vdf_path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            line = line.strip()
                            if '"path"' in line:
                                parts = line.split('"path"')
                                if len(parts) > 1:
                                    lib = parts[1].replace('"', '').strip()
                                    lib = os.path.normpath(lib)
                                    found_paths.append(os.path.join(lib, "steamapps", "common", "star conflict"))
    except Exception:
        pass
    return found_paths

def detect_game_dir(explicit_path=None):
    """Locate the Star Conflict installation directory."""
    if explicit_path:
        cand = os.path.abspath(explicit_path)
        target = os.path.join(cand, "data", "ui", "scripts", "windows", "loginwnd.lua")
        if os.path.isfile(target):
            return cand
        # Maybe the user pointed directly to data/ or loginwnd.lua
        if os.path.isfile(cand) and os.path.basename(cand).lower() == "loginwnd.lua":
            # Go up 4 levels to game root
            return os.path.abspath(os.path.join(cand, "..", "..", "..", ".."))

    # Environment variable check
    env_dir = os.environ.get("STAR_CONFLICT_DIR")
    if env_dir and os.path.isdir(env_dir):
        target = os.path.join(env_dir, "data", "ui", "scripts", "windows", "loginwnd.lua")
        if os.path.isfile(target):
            return os.path.abspath(env_dir)

    # Search common drive paths + registry paths
    search_dirs = COMMON_PATHS + find_steam_libraries()
    for cand in search_dirs:
        target = os.path.join(cand, "data", "ui", "scripts", "windows", "loginwnd.lua")
        if os.path.isfile(target):
            return os.path.abspath(cand)

    return None

def get_mod_code():
    """Load the Lua mod source code from file or fallback."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    lua_file = os.path.join(script_dir, "server_selector_mod.lua")
    if os.path.isfile(lua_file):
        with open(lua_file, "r", encoding="utf-8") as f:
            return f.read()
    raise FileNotFoundError(f"server_selector_mod.lua not found in {script_dir}")

def get_target_file(game_dir):
    return os.path.join(game_dir, "data", "ui", "scripts", "windows", "loginwnd.lua")

def get_backup_file(game_dir):
    return os.path.join(game_dir, "data", "ui", "scripts", "windows", "loginwnd.lua.orig")

def check_status(game_dir):
    """Check mod installation and backup status."""
    target_file = get_target_file(game_dir)
    backup_file = get_backup_file(game_dir)

    if not os.path.isfile(target_file):
        return {"exists": False, "installed": False, "has_backup": False}

    with open(target_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    installed = (MOD_BEGIN_MARKER in content) and (MOD_END_MARKER in content)
    has_backup = os.path.isfile(backup_file)

    return {
        "exists": True,
        "installed": installed,
        "has_backup": has_backup,
        "target_file": target_file,
        "backup_file": backup_file,
    }

def install_mod(game_dir):
    """Install the mod into loginwnd.lua."""
    target_file = get_target_file(game_dir)
    backup_file = get_backup_file(game_dir)

    if not os.path.isfile(target_file):
        print(f"[ERROR] Target file not found: {target_file}")
        return False

    with open(target_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    if MOD_BEGIN_MARKER in content:
        print("[INFO] Mod is already installed. Reinstalling with latest version...")
        # Strip existing mod block first
        prefix = content.split(MOD_BEGIN_MARKER)[0].rstrip()
        suffix = ""
        if MOD_END_MARKER in content:
            suffix = content.split(MOD_END_MARKER)[1].lstrip("\r\n")
        content = (prefix + "\n\n" + suffix).strip() + "\n"

    # Create backup if not already present
    if not os.path.isfile(backup_file):
        print(f"[INFO] Creating clean backup: {backup_file}")
        shutil.copy2(target_file, backup_file)
    else:
        print(f"[INFO] Existing backup found: {backup_file}")

    mod_code = get_mod_code()
    mod_block = f"\n\n{MOD_BEGIN_MARKER}\n{mod_code.strip()}\n{MOD_END_MARKER}\n"

    new_content = content.rstrip() + mod_block

    with open(target_file, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"[SUCCESS] Successfully installed Server Selector Mod into:\n          {target_file}")
    return True

def uninstall_mod(game_dir):
    """Uninstall the mod and restore original loginwnd.lua."""
    target_file = get_target_file(game_dir)
    backup_file = get_backup_file(game_dir)

    if not os.path.isfile(target_file):
        print(f"[ERROR] Target file not found: {target_file}")
        return False

    # Prefer restoring from backup
    if os.path.isfile(backup_file):
        print(f"[INFO] Restoring clean backup from: {backup_file}")
        shutil.copy2(backup_file, target_file)
        print("[SUCCESS] Successfully restored original loginwnd.lua from backup.")
        return True

    # Fallback: strip markers
    with open(target_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    if MOD_BEGIN_MARKER in content and MOD_END_MARKER in content:
        print("[INFO] No backup file found. Stripping mod block from loginwnd.lua...")
        prefix = content.split(MOD_BEGIN_MARKER)[0].rstrip()
        suffix = content.split(MOD_END_MARKER)[1].lstrip("\r\n")
        cleaned = (prefix + "\n\n" + suffix).strip() + "\n"
        with open(target_file, "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("[SUCCESS] Successfully stripped mod block from loginwnd.lua.")
        return True

    print("[INFO] Mod was not installed in loginwnd.lua. No changes made.")
    return True

def print_status_report(game_dir):
    print("=" * 65)
    print("  STAR CONFLICT SERVER SELECTOR MOD - STATUS REPORT")
    print("=" * 65)
    print(f"Game Directory : {game_dir}")
    stat = check_status(game_dir)
    print(f"loginwnd.lua   : {'Found' if stat['exists'] else 'NOT FOUND'}")
    print(f"Mod Status     : {'[INSTALLED]' if stat['installed'] else '[NOT INSTALLED]'}")
    print(f"Backup (.orig) : {'Present' if stat['has_backup'] else 'Not Present'}")
    print("=" * 65)

def interactive_menu(game_dir):
    while True:
        print()
        print_status_report(game_dir)
        print("\nOptions:")
        print("  1. Install / Update Mod")
        print("  2. Uninstall Mod (Restore Original)")
        print("  3. View Status")
        print("  4. Exit")
        choice = input("\nEnter choice [1-4]: ").strip()

        if choice == "1":
            install_mod(game_dir)
        elif choice == "2":
            uninstall_mod(game_dir)
        elif choice == "3":
            pass # Loop reprints status
        elif choice in ("4", "q", "quit", "exit"):
            print("Exiting.")
            break
        else:
            print("Invalid choice, please enter 1, 2, 3, or 4.")

def main():
    parser = argparse.ArgumentParser(
        description="Star Conflict Community Server Selector Patcher"
    )
    parser.add_argument(
        "-g", "--game-dir",
        help="Path to Star Conflict installation folder",
        default=None
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-i", "--install",
        action="store_true",
        help="Install the server selector mod"
    )
    group.add_argument(
        "-u", "--uninstall",
        action="store_true",
        help="Uninstall the mod and restore backup"
    )
    group.add_argument(
        "-s", "--status",
        action="store_true",
        help="Check installation status"
    )

    args = parser.parse_args()

    game_dir = detect_game_dir(args.game_dir)
    if not game_dir:
        print("[ERROR] Could not automatically find Star Conflict directory.")
        print("Please specify it with: python patcher.py --game-dir \"<path-to-star-conflict>\"")
        sys.exit(1)

    if args.install:
        success = install_mod(game_dir)
        sys.exit(0 if success else 1)
    elif args.uninstall:
        success = uninstall_mod(game_dir)
        sys.exit(0 if success else 1)
    elif args.status:
        print_status_report(game_dir)
        sys.exit(0)
    else:
        # Interactive mode when no flag provided
        interactive_menu(game_dir)

if __name__ == "__main__":
    main()
