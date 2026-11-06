"""Downloads album covers from the iTunes catalogue and prints one `Emblem --render-covers` spec per line.

    python3 tools/brand/covers.py <dir>

The player renders (docs/player-*.png) are made from these on a Mac:
    mapfile -t specs < <(python3 tools/brand/covers.py /tmp/covers)
    .build/release/Emblem --render-covers /tmp/players "${specs[@]}"
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# file name, brand id, song, artist line, album as the iTunes catalogue names it, album as shown
SONGS = [
    ("travis", "travis", "SICKO MODE", "Travis Scott", "ASTROWORLD", "ASTROWORLD"),
    ("weeknd", "xo", "Starboy", "The Weeknd", "Starboy", "Starboy"),
    ("drake", "ovo", "Champagne Poetry", "Drake", "Certified Lover Boy", "Certified Lover Boy"),
    ("kanye", "kanye", "Stronger", "Kanye West", "Graduation", "Graduation"),
    ("tyler", "tyler", "See You Again (feat. Kali Uchis)", "Tyler, The Creator", "Flower Boy", "Flower Boy"),
    # Born Sinner's well-known cover (the chrome head and gold crown) is filed as the deluxe edition on iTunes.
    ("cole", "cole", "Power Trip (feat. Miguel)", "J. Cole", "Born Sinner (Deluxe Version)", "Born Sinner"),
    ("kendrick", "kendrick", "Money Trees", "Kendrick Lamar", "good kid, m.A.A.d city", "good kid, m.A.A.d city"),
    ("billie", "billie", "WILDFLOWER", "Billie Eilish", "HIT ME HARD AND SOFT", "HIT ME HARD AND SOFT"),
    ("savage", "savage", "Brand New Draco", "21 Savage", "SAVAGE MODE II", "SAVAGE MODE II"),
    ("peep", "peep", "Falling Down - Bonus Track", "Lil Peep", "Come Over When You're Sober, Pt. 2", "Come Over When You're Sober, Pt. 2"),
    ("yachty", "yachty", "Lil Mega Minion", "Lil Yachty", "Lil Mega Minion", "Lil Mega Minion"),
    ("doom", "doom", "Doomsday", "MF DOOM", "Operation: Doomsday", "Operation: Doomsday"),
    ("wutang", "wutang", "C.R.E.A.M.", "Wu-Tang Clan", "Enter the Wu-Tang (36 Chambers)", "Enter the Wu-Tang (36 Chambers)"),
    ("pop-smoke", "pop-smoke", "The Woo (feat. 50 Cent & Roddy Ricch)", "Pop Smoke", "Shoot For The Stars Aim For The Moon", "Shoot For The Stars Aim For The Moon"),
]


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower().replace("’", "'"))


def get(url):
    # The iTunes API allows about 20 requests a minute, so pace them and retry when it says no.
    for attempt in range(6):
        time.sleep(3 if "itunes.apple.com" in url else 0)
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or attempt == 5:
                raise
            time.sleep(15 * (attempt + 1))


def cover_url(artist, album):
    q = urllib.parse.urlencode({"term": artist, "entity": "musicArtist", "limit": 5, "country": "US"})
    artists = json.loads(get("https://itunes.apple.com/search?" + q))["results"]
    match = [a for a in artists if norm(a["artistName"]) == norm(artist)]
    if not match:
        return None
    albums = json.loads(get(f"https://itunes.apple.com/lookup?id={match[0]['artistId']}&entity=album&limit=200&country=US"))["results"][1:]
    # Exact name first, then the deluxe or complete edition.
    exact = [a for a in albums if norm(a["collectionName"]) == norm(album)]
    close = [a for a in albums if norm(a["collectionName"]).startswith(norm(album))]
    pick = (exact or close or [None])[0]
    return pick and re.sub(r"/\d+x\d+bb\.", "/1000x1000bb.", pick["artworkUrl100"])


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for file, brand, song, artist, catalogue, shown in SONGS:
        url = cover_url(artist, catalogue)
        if not url:
            print(f"no cover for {artist} – {catalogue}", file=sys.stderr)
            continue
        path = os.path.join(out, file + ".jpg")
        with open(path, "wb") as f:
            f.write(get(url))
        print(f"{brand}={path}|{song}|{artist}|{shown}")


main()
