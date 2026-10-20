#!/usr/bin/env python3
"""Installs TweenService (+ the login tween demo) into Star Conflict's loginwnd.lua.

    python install.py --install            library + demo
    python install.py --install --no-demo  library only
    python install.py --uninstall          removes only these blocks
    python install.py --status
    python install.py --game-dir "D:/SteamLibrary/steamapps/common/star conflict" --install

Coexists with other loginwnd.lua mods (e.g. the Server Selector):
- Each part is one marker-delimited block (-- BEGIN TWEENSERVICE ... -- END TWEENSERVICE,
  -- BEGIN LOGIN_TWEEN_DEMO ... -- END LOGIN_TWEEN_DEMO). Reinstalling replaces them;
  uninstalling strips only them and never restores loginwnd.lua.orig (that would also
  remove other mods).
- loginwnd.lua.orig is created only if absent (same convention as the Server Selector),
  and every run that writes also saves the previous file as loginwnd.lua.tween-prev.
- The result is compiled with Lua 5.1 (via lupa) before anything is written; if it does
  not compile, nothing changes. Encoding (UTF-8) and CRLF line endings are preserved.
"""

import argparse
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET_REL = os.path.join("data", "ui", "scripts", "windows", "loginwnd.lua")

# (marker name, source file), in load order: the libraries must come before the demo
BLOCKS = [
    ("TWEENSERVICE", "tweenservice.lua"),
    ("RBXUI", "rbxui.lua"),
    ("LOGIN_TWEEN_DEMO", "login_tween_demo.lua"),
]

COMMON_PATHS = [
    r"G:\SteamLibrary\steamapps\common\star conflict",
    r"C:\Program Files (x86)\Steam\steamapps\common\star conflict",
    r"C:\Program Files\Steam\steamapps\common\star conflict",
    r"D:\SteamLibrary\steamapps\common\star conflict",
    r"E:\SteamLibrary\steamapps\common\star conflict",
    r"F:\SteamLibrary\steamapps\common\star conflict",
]


def steam_libraries():
    out = []
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam = os.path.normpath(winreg.QueryValueEx(key, "SteamPath")[0])
        out.append(os.path.join(steam, "steamapps", "common", "star conflict"))
        vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            for m in re.finditer(r'"path"\s+"([^"]+)"', open(vdf, encoding="utf-8", errors="ignore").read()):
                out.append(os.path.join(os.path.normpath(m.group(1).replace("\\\\", "\\")),
                                        "steamapps", "common", "star conflict"))
    except Exception:
        pass
    return out


def find_game_dir(explicit=None):
    cands = ([explicit] if explicit else []) + [os.environ.get("STAR_CONFLICT_DIR") or ""] + COMMON_PATHS + steam_libraries()
    for c in cands:
        if c and os.path.isfile(os.path.join(c, TARGET_REL)):
            return os.path.abspath(c)
    return None


def markers(name):
    return f"-- BEGIN {name}", f"-- END {name}"


def strip_block(text, name):
    """Removes one marker block (and the blank lines before it). Returns (text, found)."""
    begin, end = markers(name)
    i = text.find(begin)
    if i < 0:
        return text, False
    j = text.find(end, i)
    if j < 0:
        raise ValueError(f"{begin} without {end}: fix loginwnd.lua by hand or restore a backup")
    j += len(end)
    return text[:i].rstrip() + "\n" + text[j:].lstrip("\n"), True


def block_source(name, fname):
    src = open(os.path.join(HERE, fname), encoding="utf-8").read().replace("\r\n", "\n").strip()
    begin, end = markers(name)
    if not (src.startswith(begin) and src.endswith(end)):
        raise ValueError(f"{fname} must start with '{begin}' and end with '{end}'")
    return src


def compile_check(text):
    """(ok, message). Compiles the whole file with Lua 5.1; this also catches Lua's
    200-local / upvalue limits, which an appended mod shares with loginwnd.lua."""
    try:
        import lupa.lua51 as lua51
    except ImportError:
        return None, "lupa not installed (pip install lupa): skipped the Lua compile check"
    rt = lua51.LuaRuntime(encoding="latin-1")
    f = rt.eval("function(src) local f, err = loadstring(src, '=loginwnd.lua'); return f ~= nil, err end")
    ok, err = f(text.encode("utf-8").decode("latin-1"))
    return bool(ok), (err or "compiles under Lua 5.1")


def read_target(path):
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw[3:].decode("utf-8") if bom else raw.decode("utf-8")   # loginwnd.lua is UTF-8
    crlf = b"\r\n" in raw
    return text.replace("\r\n", "\n"), bom, crlf


def write_target(path, text, bom, crlf):
    data = text.replace("\n", "\r\n") if crlf else text
    shutil.copy2(path, path + ".tween-prev")
    with open(path, "wb") as f:
        f.write((b"\xef\xbb\xbf" if bom else b"") + data.encode("utf-8"))


def status(game_dir):
    path = os.path.join(game_dir, TARGET_REL)
    text, _, _ = read_target(path)
    print(f"Game directory : {game_dir}")
    for name, _ in BLOCKS:
        print(f"{name:<15}: {'installed' if markers(name)[0] in text else 'not installed'}")
    others = sorted(set(re.findall(r"^-- BEGIN (.+)$", text, re.M)) - {n for n, _ in BLOCKS})
    print(f"Other mods     : {', '.join(others) if others else 'none'}")
    print(f"Backup .orig   : {'present' if os.path.isfile(path + '.orig') else 'absent'}")


def install(game_dir, with_demo=True):
    path = os.path.join(game_dir, TARGET_REL)
    text, bom, crlf = read_target(path)
    for name, _ in reversed(BLOCKS):
        text, _ = strip_block(text, name)
    parts = [block_source(n, f) for n, f in BLOCKS if with_demo or n != "LOGIN_TWEEN_DEMO"]
    new = text.rstrip() + "\n\n" + "\n\n".join(parts) + "\n"
    ok, msg = compile_check(new)
    if ok is False:
        print(f"[ERROR] the patched loginwnd.lua would not compile: {msg}\n        Nothing was changed.")
        return False
    if ok is None:
        print(f"[WARN] {msg}")
    if not os.path.isfile(path + ".orig"):
        shutil.copy2(path, path + ".orig")
        print(f"[INFO] created clean backup {path}.orig")
    write_target(path, new, bom, crlf)
    print(f"[OK] installed {' + '.join(n for n, _ in BLOCKS if with_demo or n != 'LOGIN_TWEEN_DEMO')} "
          f"into {path} ({msg})")
    return True


def uninstall(game_dir):
    path = os.path.join(game_dir, TARGET_REL)
    text, bom, crlf = read_target(path)
    found = False
    for name, _ in reversed(BLOCKS):
        text, f = strip_block(text, name)
        found |= f
    if not found:
        print("[INFO] TweenService is not installed; nothing to do.")
        return True
    ok, msg = compile_check(text)
    if ok is False:
        print(f"[ERROR] loginwnd.lua would not compile after removal: {msg}\n        Nothing was changed.")
        return False
    write_target(path, text.rstrip() + "\n", bom, crlf)
    print(f"[OK] removed TweenService blocks from {path}; other mods untouched.")
    return True


def main(argv=None):
    ap = argparse.ArgumentParser(description="Install TweenService (+ login demo) into Star Conflict")
    ap.add_argument("-g", "--game-dir")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("-i", "--install", action="store_true")
    g.add_argument("-u", "--uninstall", action="store_true")
    g.add_argument("-s", "--status", action="store_true")
    ap.add_argument("--no-demo", action="store_true", help="install only the TweenService library")
    a = ap.parse_args(argv)
    game_dir = find_game_dir(a.game_dir)
    if not game_dir:
        print("[ERROR] Star Conflict not found; pass --game-dir")
        return 1
    if a.status:
        status(game_dir)
        return 0
    ok = install(game_dir, not a.no_demo) if a.install else uninstall(game_dir)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
