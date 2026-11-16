import os
import sys
import subprocess
import requests

VERSION = "v3.7.5"
APK_PATH = r"releases/IT_Feels_v3.7.5.apk"
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

    apk_size_mb = os.path.getsize(APK_PATH) / (1024 * 1024)

    print(f"Artifact ready:")
    print(f"  Android: {APK_PATH} ({apk_size_mb:.2f} MB)")

    gh_release_url = None
    # 1. Create GitHub release via gh CLI if available
    try:
        print("Creating GitHub release via gh CLI...")
        cmd = [
            "gh", "release", "create", VERSION,
            APK_PATH,
            "--target", "feature/next-gen-ui",
            "--title", f"IT Feels {VERSION} — Android Dedicated Release",
            "--notes", f"IT Feels {VERSION} Android Dedicated Production Release with enhanced connected music performance, session-granted audio negotiation, and background playback resilience."
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
    apk_litter_link = upload_file_litterbox(APK_PATH, f"IT-Feels-{VERSION}.apk")

    # 3. Format Telegram Announcement
    lines = [
        f"📱 *IT Feels {VERSION} Android Dedicated Release is Live!*",
        "",
        "📦 *Release Artifact:*",
        f"• 📱 *Android APK:* `IT_Feels_{VERSION}.apk` ({apk_size_mb:.1f} MB)",
        "",
        "✨ *Highlights:*",
        "• 🎵 *Connected Music Performance*: Replaced full YouTube background SPA loads with lightweight reader, serialized concurrent readers, and transferred changed track deltas.",
        "• 🎧 *Session-Granted Audio Negotiation*: Added session audio negotiation inside YouTube addon, robust addon result handling, and signed-URL cache expiry.",
        "• 🛡️ *Background Playback & Lifecycle Resilience*: Preserved background audio service on Android when leaving the app to home screen with self-healing player recovery.",
        "• 📂 *Atomic Disk Cache*: Bounded 32-entry / 32 MB atomic playlist snapshot cache with per-service cleanup.",
        "",
        "🔗 *Download Links:*"
    ]

    if gh_release_url:
        lines.append(f"• 🌐 [GitHub Releases Page]({gh_release_url})")
        lines.append(f"  └ 📱 [Android APK (GitHub Direct)]({gh_release_url}/download/{os.path.basename(APK_PATH)})")

    if apk_temp_link:
        lines.append("")
        lines.append(f"• ⚡ [Temp.sh Direct APK Download ({apk_size_mb:.1f} MB)]({apk_temp_link})")

    if apk_litter_link:
        lines.append(f"• 🐱 [Litterbox / Catbox Mirror]({apk_litter_link})")

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
