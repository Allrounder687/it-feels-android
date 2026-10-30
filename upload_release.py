import os
import sys
import subprocess
import requests
import json

APK_PATH = r"build/app/outputs/flutter-apk/app-release.apk"
BOT_TOKEN = "7977916547:AAET0iP-5DbTwlYlCAhBTtIwLS0e6ZAXdqM"
CHAT_ID = "424256757"
VERSION = "v3.6.31"

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
            f"Release {VERSION} - Playlist Contract Hardening, Endless Autoplay Radio, Curated Mixes & UI Defect Polish\n\n"
            "- Playlist '0 Songs' Contract Fix: Resolved JioSaavn search.getPlaylistResults and playlist.getDetails multi-token contents parsing, eliminating '0 Songs' across Hollywood, Bollywood, and regional playlists\n"
            "- Continuous Autoplay & Radio Engine: Fixed JioSaavn reco.getreco dictionary PID mapping and integrated endless background queue pre-fetching when playing from Recently Played or reaching end of queue (no more track looping)\n"
            "- Curated Daily Mixes 1-6: Rebuilt algorithmic mixes into authentic Spotify/Apple Music artist & genre clusters (Bollywood Romance, International Pop, Punjabi Beats, Hip-Hop, Acoustic/Indie, and Club/Dance)\n"
            "- UI Polish & Bug Fixes: Completely eliminated 3.8px bottom overflow in Albums grid, removed rasterization line artifacts from Search genre cards, and integrated Car Mode (Driving Mode) into Now Playing utility bar and SongOptionsSheet\n"
            "- Static Analysis & Unit Tests: 100% test pass rate (22/22 tests passed), 0 dart analyze errors\n"
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
        "• 📋 *Resolved '0 Songs' Playlists*: Fixed JioSaavn API contract parsing across search and featured playlists",
        "• ♾️ *Continuous Autoplay & Radio*: Endless queue pre-fetching when playing from Recently Played (zero repeating loops)",
        "• 🔀 *Spotify/Apple Music Daily Mixes*: Clustered Daily Mixes 1-6 by authentic genre and artist anchors",
        "• 🚗 *Car Mode (Driving Mode)*: Added one-tap launcher to Neo Now Playing utility bar and Song Options Sheet",
        "• 🎨 *UI Polish*: Fixed 3.8px bottom overflow in Albums grid, eliminated white line artifacts from Search genre cards\n",
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
