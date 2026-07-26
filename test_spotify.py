import re
with open('spotify_test.html', 'r', encoding='utf-8') as f:
    html = f.read()
match = re.findall(r'<meta property="music:song"', html)
if match:
    print('Found songs:', len(match))
else:
    print('No songs in meta tags')

match_title = re.findall(r'<meta property="og:title" content="(.*?)"', html)
if match_title:
    print('Title:', match_title[0])

match_desc = re.findall(r'<meta name="description" content="(.*?)"', html)
if match_desc:
    print('Description:', match_desc[0])
