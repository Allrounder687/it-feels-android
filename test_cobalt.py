import urllib.request
import json

def test_api():
    try:
        req = urllib.request.Request(
            'https://co.wuk.sh/api/json',
            data=json.dumps({
                "url": "https://www.youtube.com/watch?v=2Vv-BfVoq4g",
                "vQuality": "max"
            }).encode(),
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json"
            }
        )
        res = urllib.request.urlopen(req)
        print("Cobalt instance (co.wuk.sh) response:", res.status)
        data = json.loads(res.read().decode())
        print(json.dumps(data, indent=2))
        return
    except Exception as e:
        print("Cobalt instance (co.wuk.sh) failed:", e)

    try:
        req = urllib.request.Request(
            'https://api.cobalt.tools/api/json',
            data=json.dumps({
                "url": "https://www.youtube.com/watch?v=2Vv-BfVoq4g",
                "vQuality": "max"
            }).encode(),
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json"
            }
        )
        res = urllib.request.urlopen(req)
        print("Cobalt official response:", res.status)
        data = json.loads(res.read().decode())
        print(json.dumps(data, indent=2))
        return
    except Exception as e:
        print("Cobalt official failed:", e)

test_api()
