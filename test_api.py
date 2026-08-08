import urllib.request
import json
import urllib.parse

url = 'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&p=1&n=20&api_version=4&ctx=web6dot0&q=Arijit%20Singh'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        if 'results' in data:
            print('results is a List. Length:', len(data['results']))
        else:
            print('keys:', data.keys())
            if 'songs' in data:
                print('songs type:', type(data['songs']))
                if isinstance(data['songs'], dict) and 'data' in data['songs']:
                    print('songs.data length:', len(data['songs']['data']))
except Exception as e:
    print(e)
