"""Fill page_template.html with logo data and write work/page/index.html.
Usage: python3 renderer/build_page.py   (run from concepts/cn-tower-background)"""
import json, re, os
here = os.path.dirname(os.path.abspath(__file__)); root = os.path.dirname(here)
repo = os.path.dirname(os.path.dirname(root))
page = os.path.join(root, 'work', 'page'); os.makedirs(page, exist_ok=True)

def paths(svg): return re.findall(r' d="([^"]+)"', open(svg).read())
def viewbox(svg): return [float(v) for v in re.search(r'viewBox="([^"]+)"', open(svg).read()).group(1).split()]

six = os.path.join(page, 'sixgod.svg')
fill = {
    'OWL': paths(os.path.join(repo, 'Artists/ovo/logo.svg')),
    'XO': paths(os.path.join(repo, 'Artists/xo/logo.svg')),
    'COLS': json.load(open(os.path.join(root, 'data/pod_colors.json'))),
    'SIX': paths(six) if os.path.exists(six) else [],
    'SXV': viewbox(six) if os.path.exists(six) else [0, 0, 1, 1],
    'DOGS': json.load(open(os.path.join(root, 'data/dog_strokes.json'))),
    # Dropped from the rotation (Raptors ball, NOCTA, Jordan); left empty.
    'BALL': [], 'NOC': [], 'NV': [0, 0, 1, 1], 'JM': [], 'JV': [0, 0, 1, 1],
}
s = open(os.path.join(here, 'page_template.html')).read()
for k, v in fill.items(): s = s.replace('__%s__' % k, json.dumps(v))
s = s.replace('__BALLPATHS__', '')
open(os.path.join(page, 'index.html'), 'w').write(s)
print(os.path.join(page, 'index.html'))
