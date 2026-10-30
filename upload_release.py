import os
import sys
import subprocess
import requests
import json

APK_PATH = r"build/app/outputs/flutter-apk/app-release.apk"
BOT_TOKEN = "7977916547:AAET0iP-5DbTwlYlCAhBTtIwLS0e6ZAXdqM"
CHAT_ID = "424256757"
VERSION = "v3.6.30"

def main():
    if not os.path.exists(APK_PATH):
        print(f"Error: APK not found at {APK_PATH}")
        sys.exit(1)

    apk_size_mb = os.path.getsize(APK_PATH) / (1024 * 1024)
    print(f"APK found: {APK_PATH} ({apk_size_mb:.2f} MB)")

    links = {}

    # 1. Upload to Temp.sh
    try:
        print("Uploading to Temp.sh...")
        with open(APK_PATH, "rb") as f:
            resp = requests.post("https://temp.sh/upload", files={"file": (f"it-feels-{VERSION}.apk", f)}, timeout=180)
            if resp.status_code == 200:
                t_link = resp.text.strip()
                print("Temp.sh link:", t_link)
                links["Temp.sh (Fast Mirror)"] = t_link
    except Exception as e:
        print("Temp.sh upload failed:", e)

    # 2. Upload to Litterbox (Catbox 72h temporary)
    try:
        print("Uploading to Litterbox...")
        with open(APK_PATH, "rb") as f:
            resp = requests.post(
                "https://litterbox.catbox.moe/resources/internals/api.php",
                data={"reqtype": "fileupload", "time": "72h"},
                files={"fileToUpload": (f"it-feels-{VERSION}.apk", f)},
                timeout=180
            )
            if resp.status_code == 200 and resp.text.startswith("http"):
                l_link = resp.text.strip()
                print("Litterbox link:", l_link)
                links["Litterbox (Catbox Mirror)"] = l_link
    except Exception as e:
        print("Litterbox upload failed:", e)

    # 3. Create GitHub release if gh is available
    try:
        print("Creating GitHub release...")
        notes = (
            f"Release {VERSION} - Apple Neo Smartphone UI Suite, Curated Feed & Playback Architecture Hardening\n\n"
            "- Apple Neo UI Suite: Editorial Listen Now Feed, Unified Frosted Island Dock, The Living Player with Dynamic Ambient Mesh, Neo Search with iOS 18 Genre Cards, and Neo Library with Contextual Drawers\n"
            "- User Profile & Sign-In: Top-right header profile button navigates directly to Profile & Google/Cloud Authentication; duplicate settings removed\n"
            "- Playback & Decryption Hardening: Direct client-side TripleDES decryption, fast Saavn details fetch, resolved Addon stream contract, permanently removed cascade skipping\n"
            "- Curated Category Organization: Authentic language-specific hits, featured editorial playlists, and studio albums for Bollywood, Hollywood, Punjabi, Telugu, and Tamil\n"
            "- 100% Classic UI Preservation: Parallel dual-UI routing for mobile smartphones while tablets and desktops remain untouched\n"
            "- Zero static analysis issues across entire lib/ codebase (0 errors, 0 warnings)\n"
        )
        cmd = [
            "gh", "release", "create", VERSION,
            APK_PATH,
            "--title", f"IT Feels {VERSION}",
            "--notes", notes
        ]
        gh_proc = subprocess.run(cmd, capture_output=True, text=True)
        print("GH stdout:", gh_proc.stdout)
        print("GH stderr:", gh_proc.stderr)
        if gh_proc.returncode == 0:
            gh_link = f"https://github.com/Allrounder687/it-feels-android/releases/tag/{VERSION}"
            links["GitHub Releases"] = gh_link
    except Exception as e:
        print("GitHub release creation failed:", e)

    # 4. Dispatch links to Telegram
    msg_lines = [
        f"🚀 *IT Feels {VERSION} Release APK is Ready!*",
        f"📦 Size: {apk_size_mb:.1f} MB\n",
        "*Key Highlights:*",
        "• 🍏 *Apple Neo Smartphone UI Suite*: Editorial Listen Now Feed, Frosted Island Dock, The Living Player, Neo Search, and Neo Library",
        "• 👤 *Restored Profile Sign-In*: Instant profile navigation with user avatar, duplicate settings removed",
        "• 🎵 *Hardened Audio Core & JioSaavn Decryption*: Zero cascading skips, client-side TripleDES decryption, fixed Addon stream contract",
        "• 🗂️ *Curated Category Feeds*: Organized Bollywood, Hollywood, Punjabi, Telugu, and Tamil shelves with real hits, playlists, and albums",
        "• 🛡️ *100% Dual-UI Architecture*: Classic UI completely preserved for tablets and desktop\n",
        "*Direct Download Links:*"
    ]
    for name, url in links.items():
        msg_lines.append(f"• [{name}]({url})")

    tg_msg = "\n".join(msg_lines)
    try:
        print("Dispatching to Telegram...")
        tg_url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        resp = requests.post(tg_url, json={
            "chat_id": CHAT_ID,
            "text": tg_msg,
            "parse_mode": "Markdown",
            "disable_web_page_preview": False
        }, timeout=30)
        print("Telegram status:", resp.status_code, resp.text)
    except Exception as e:
        print("Telegram dispatch failed:", e)

if __name__ == "__main__":
    main()
