import urllib.request
import json

BASE_URL = 'https://it-feels-proxy.cleverfox687.workers.dev'
SECRET = 'development_secret_123'

QUERIES = [
    "Trending Today",
    "Top Hindi Hits",
    "Arijit Singh",
    "Shreya Ghoshal",
    "Global Top 50",
    "Taylor Swift",
    "The Weeknd",
    "Punjabi Hits",
    "Sidhu Moose Wala",
    "Lofi Chill"
]

print(f"Starting massive seed to {BASE_URL}...")
req = urllib.request.Request(
    f"{BASE_URL}/api/v1/native/seed/saavn",
    data=json.dumps({"queries": QUERIES, "limitPerQuery": 50}).encode('utf-8'),
    headers={'Content-Type': 'application/json', 'X-Feels-Secret': SECRET},
    method='POST'
)

try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        print(f"Seeding Complete! Added: {data.get('importedCount', 0)} new songs.")
        print(f"Total songs now permanently in your database: {data.get('totalCatalogSize', 0)}")
except Exception as e:
    print(f"Seeding failed: {e}")
