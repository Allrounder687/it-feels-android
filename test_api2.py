import urllib.request
import json
import urllib.parse

url = 'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&p=1&n=20&api_version=4&ctx=web6dot0&q=Arijit%20Singh'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        if 'results' in data:
            results = data['results']
            print('results length:', len(results))
            ids = [item.get('id') for item in results]
            titles = [item.get('title') for item in results]
            for i, (id, title) in enumerate(zip(ids, titles)):
                print(f"{i}: ID={id}, Title={title}")
except Exception as e:
    print(e)
