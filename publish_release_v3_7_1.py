import os
import sys
import subprocess
import requests

VERSION = "v3.7.1"
APK_PATH = r"releases/IT_Feels_v3.7.1.apk"
EXE_PATH = r"releases/IT_Feels_Music_v3.7.1_Setup.exe"
NOTES_FILE = "release_notes_v3_7_1.md"
BOT_TOKEN = "7977916547:AAET0iP-5DbTwlYlCAhBTtIwLS0e6ZAXdqM"
CHAT_ID = "424256757"

def upload_file_temp_sh(path, filename):
    print(f"Uploading {filename} to Temp.sh...")
    try:
        with open(path, "rb") as f:
            resp = requests.post("https://temp.sh/upload", files={"file": (filename, f)}, timeout=240)
            if resp.status_code == 200 and resp.text.strip().startswith("http"):
                link = resp.text.strip()
                print(f"Temp.sh link for {filename}: {link}")
                return link
    except Exception as e:
        print(f"Temp.sh upload failed for {filename}: {e}")
    return None

def upload_file_litterbox(path, filename):
    print(f"Uploading {filename} to Litterbox...")
    try:
        with open(path, "rb") as f:
            resp = requests.post(
                "https://litterbox.catbox.moe/resources/internals/api.php",
                data={"reqtype": "fileupload", "time": "72h"},
                files={"fileToUpload": (filename, f)},
                timeout=240
            )
            if resp.status_code == 200 and resp.text.strip().startswith("http"):
                link = resp.text.strip()
                print(f"Litterbox link for {filename}: {link}")
                return link
    except Exception as e:
        print(f"Litterbox upload failed for {filename}: {e}")
    return None

def main():
    if not os.path.exists(APK_PATH):
        print(f"Error: APK not found at {APK_PATH}")
        sys.exit(1)
    if not os.path.exists(EXE_PATH):
        print(f"Error: Inno Setup executable not found at {EXE_PATH}")
        sys.exit(1)

    apk_size_mb = os.path.getsize(APK_PATH) / (1024 * 1024)
    exe_size_mb = os.path.getsize(EXE_PATH) / (1024 * 1024)

    print(f"Artifacts ready:")
    print(f"  Windows: {EXE_PATH} ({exe_size_mb:.2f} MB)")
    print(f"  Android: {APK_PATH} ({apk_size_mb:.2f} MB)")

    gh_release_url = None
    # 1. Create GitHub release via gh CLI
    try:
        print("Creating GitHub release via gh CLI...")
        cmd = [
            "gh", "release", "create", VERSION,
            APK_PATH,
            EXE_PATH,
            "--target", "feature/next-gen-ui",
            "--title", f"IT Feels {VERSION} — Sleek UX Overhaul & Playback Resilience",
            "--notes-file", NOTES_FILE
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        print("GH stdout:", proc.stdout)
        print("GH stderr:", proc.stderr)
        if proc.returncode == 0:
            gh_release_url = f"https://github.com/Allrounder687/it-feels-android/releases/tag/{VERSION}"
            print(f"GitHub release created: {gh_release_url}")
        else:
            print(f"GH release returned non-zero code {proc.returncode}")
    except Exception as e:
        print("GitHub release creation failed:", e)

    # 2. Upload to Fast Direct Mirrors
    apk_temp_link = upload_file_temp_sh(APK_PATH, f"IT-Feels-{VERSION}.apk")
    exe_temp_link = upload_file_temp_sh(EXE_PATH, f"IT_Feels_Music_{VERSION}_Setup.exe")
    apk_litter_link = upload_file_litterbox(APK_PATH, f"IT-Feels-{VERSION}.apk")
    exe_litter_link = upload_file_litterbox(EXE_PATH, f"IT_Feels_Music_{VERSION}_Setup.exe")

    # 3. Format Telegram Announcement
    lines = [
        f"🚀 *IT Feels {VERSION} Production Release is Live!*",
        "",
        "📦 *Release Artifacts:*",
        f"• 🪟 *Windows Setup:* `IT_Feels_Music_{VERSION}_Setup.exe` ({exe_size_mb:.1f} MB)",
        f"• 📱 *Android APK:* `IT_Feels_{VERSION}.apk` ({apk_size_mb:.1f} MB)",
        "",
        "✨ *Key Highlights:*",
        "• 🎵 *Playback Resilience & Zero-Stall Pipeline*: Configured AudioSession with interruption recovery, replaced unbounded stream cache with 2-hour TTL & proactive 403-eviction, and added a 12s socket watchdog to eliminate random unplayable track freezes.",
        "• 🎨 *Sleek Modern UX & Anti-Bloat*: Replaced bulky text pills with a unified Spotify-grade action bar (circular glass controls + glowing circular Play FAB), eliminated permanent ugly filter text boxes with on-demand search toggles, and compacted the library screen.",
        "• 📱 *Responsive Title Fitting On All Screens*: Dynamic 2-line title wrapping, constrained 32px hit targets, and streamlined padding completely eliminate truncated song titles on compact mobile and desktop displays.",
        "• 📥 *Download Management*: One-tap deletion with obsidian confirmation modal, swipe-to-delete, and protection against startup auto-scanning.",
        "",
        "🔗 *Download Links:*"
    ]

    if gh_release_url:
        lines.append(f"• 🌐 [GitHub Releases Page]({gh_release_url})")
        lines.append(f"  └ 🪟 [Windows Setup (GitHub Direct)]({gh_release_url}/download/{os.path.basename(EXE_PATH)})")
        lines.append(f"  └ 📱 [Android APK (GitHub Direct)]({gh_release_url}/download/{os.path.basename(APK_PATH)})")

    if exe_temp_link or apk_temp_link:
        lines.append("")
        lines.append("*⚡ Direct High-Speed Mirrors (Temp.sh):*")
        if exe_temp_link:
            lines.append(f"• 🪟 [Windows Inno Installer ({exe_size_mb:.1f} MB)]({exe_temp_link})")
        if apk_temp_link:
            lines.append(f"• 📱 [Android APK ({apk_size_mb:.1f} MB)]({apk_temp_link})")

    if exe_litter_link or apk_litter_link:
        lines.append("")
        lines.append("*🐱 Catbox / Litterbox Mirrors:*")
        if exe_litter_link:
            lines.append(f"• 🪟 [Windows Setup Mirror]({exe_litter_link})")
        if apk_litter_link:
            lines.append(f"• 📱 [Android APK Mirror]({apk_litter_link})")

    tg_message = "\n".join(lines)

    # 4. Dispatch to Telegram Bot
    print("\nDispatching announcement to Telegram Bot...")
    try:
        tg_url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        resp = requests.post(tg_url, json={
            "chat_id": CHAT_ID,
            "text": tg_message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": False
        }, timeout=30)
        print("Telegram API response status:", resp.status_code)
        if resp.status_code == 200:
            print("Telegram dispatch successful!")
        else:
            print("Telegram API returned error:", resp.text)
    except Exception as e:
        print("Telegram dispatch failed with exception:", e)

if __name__ == "__main__":
    main()
