// Renders Emblem's brand images from the artist folders:
//   docs/banner.png     README header
//   docs/lineup.png     every artist's logo, name and colour
//   build/icon-1024.png the app icon (scripts/make-icon.py turns it into Resources/AppIcon.icns)
// Run from the repo root: node tools/brand/render.mjs  (needs Playwright and the Inter font).
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require("playwright")); } catch { ({ chromium } = require(require("node:child_process").execSync("npm root -g").toString().trim() + "/playwright")); }
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const artistsDir = path.join(root, "Artists");

// Order the lineup by how recognisable the mark is, then anything new alphabetically.
const preferred = ["ovo", "travis", "xo", "kanye", "tyler", "cole", "kendrick", "billie",
  "savage", "peep", "yachty", "doom", "wutang", "pop-smoke"];
const ids = fs.readdirSync(artistsDir).filter((d) => fs.existsSync(path.join(artistsDir, d, "artist.json")));
ids.sort((a, b) => {
  const ia = preferred.indexOf(a), ib = preferred.indexOf(b);
  return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b);
});

const artists = ids.map((id) => {
  const meta = JSON.parse(fs.readFileSync(path.join(artistsDir, id, "artist.json"), "utf8"));
  const svg = fs.readFileSync(path.join(artistsDir, id, meta.logo?.file ?? "logo.svg"), "utf8");
  const viewBox = svg.match(/viewBox="([^"]+)"/)[1];
  const paths = [...svg.matchAll(/<path[^>]*\sd="([^"]+)"/g)].map((m) => m[1]);
  const rule = meta.logo?.fill === "nonZero" ? "nonzero" : "evenodd";
  return { id, name: meta.name, accent: meta.colors?.accent ?? "#ffffff", viewBox, paths, rule };
});

const logo = (a, color = "#fff") =>
  `<svg viewBox="${a.viewBox}" preserveAspectRatio="xMidYMid meet"><path fill="${color}" fill-rule="${a.rule}" d="${a.paths.join(" ")}"/></svg>`;

// Emblem's own mark: the idle menu bar icon, a play button in a ring.
const mark = (stroke = "#fff", ring = stroke) => `
<svg viewBox="0 0 100 100">
  <defs><linearGradient id="rg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#F6DA94"/><stop offset=".55" stop-color="#F28C8C"/><stop offset="1" stop-color="#E5A3DA"/>
  </linearGradient></defs>
  <circle cx="50" cy="50" r="40" fill="none" stroke="${ring}" stroke-width="9"/>
  <path d="M41 32.5 Q38 30.8 38 34.3 V65.7 Q38 69.2 41 67.5 L67.5 52.2 Q70.5 50 67.5 47.8 Z" fill="${stroke}"/>
</svg>`;

// Soft glows in album colours: ASTROWORLD gold, After Hours red, IGOR pink, Views blue, Blohsh green.
const aurora = (scale = 1) => `
  <div class="glow" style="--c:#D7B563; left:${-8 * scale}%; top:${-30 * scale}%; width:55%; height:90%"></div>
  <div class="glow" style="--c:#E2323C; right:${-10 * scale}%; bottom:${-35 * scale}%; width:55%; height:95%"></div>
  <div class="glow" style="--c:#ECB4CC; right:6%; top:-40%; width:40%; height:80%; opacity:.5"></div>
  <div class="glow" style="--c:#5B7FD6; left:18%; bottom:-55%; width:45%; height:90%; opacity:.55"></div>`;

const base = `
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:transparent;font-family:"Inter Display","Inter",system-ui,sans-serif;color:#fff;-webkit-font-smoothing:antialiased}
  .glow{position:absolute;border-radius:50%;background:radial-gradient(closest-side,var(--c),transparent);filter:blur(40px);opacity:.42}
  .grain{position:absolute;inset:0;opacity:.07;mix-blend-mode:overlay;background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>")}
  svg{display:block;width:100%;height:100%}
`;

// ---------- App icon (1024 × 1024, macOS grid: 824pt body, 100pt margin) ----------
const iconHTML = `<!doctype html><html><head><style>${base}
  body{width:1024px;height:1024px}
  .body{position:absolute;left:100px;top:100px;width:824px;height:824px;border-radius:186px;overflow:hidden;
        background:#0a0a0d;box-shadow:0 22px 40px rgba(0,0,0,.35), 0 4px 10px rgba(0,0,0,.25)}
  .body .glow{filter:blur(70px);opacity:1}
  .shade{position:absolute;inset:0;background:radial-gradient(circle at 50% 50%,rgba(6,6,8,.72) 22%,rgba(0,0,0,.05) 70%)}
  .rim{position:absolute;inset:0;border-radius:186px;box-shadow:inset 0 2px 0 rgba(255,255,255,.18), inset 0 0 0 2px rgba(255,255,255,.06)}
  .mark{position:absolute;left:212px;top:212px;width:400px;height:400px;filter:drop-shadow(0 10px 30px rgba(0,0,0,.45))}
</style></head><body>
  <div class="body">${aurora(1.4)}<div class="shade"></div><div class="grain"></div>
    <div class="mark">${mark("#fff", "url(#rg)")}</div><div class="rim"></div></div>
</body></html>`;

// ---------- Banner (1280 × 640) ----------
const ring = artists.slice(0, 14);
const bannerHTML = `<!doctype html><html><head><style>${base}
  body{width:1280px;height:640px;position:relative;overflow:hidden;background:#060608}
  .content{position:absolute;left:88px;top:92px;width:640px}
  .brand{display:flex;align-items:center;gap:14px;margin-bottom:44px}
  .brand .m{width:34px;height:34px}
  .brand span{font-size:26px;font-weight:700;letter-spacing:-.02em}
  h1{font-size:84px;line-height:.98;font-weight:800;letter-spacing:-.045em}
  h1 em{font-style:normal;background:linear-gradient(90deg,#F4D58A,#F28C8C 55%,#E9A8D6);-webkit-background-clip:text;color:transparent}
  p{margin-top:28px;font-size:23px;line-height:1.4;color:rgba(255,255,255,.62);font-weight:500;letter-spacing:-.01em;max-width:560px}
  .bar{position:absolute;right:72px;top:118px;width:400px;height:44px;border-radius:14px;
       background:rgba(255,255,255,.08);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,.1);
       display:flex;align-items:center;justify-content:flex-end;gap:22px;padding:0 20px;font-size:17px;font-weight:600;color:rgba(255,255,255,.9)}
  .bar .pill{width:52px;height:32px;border-radius:10px;background:rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center}
  .bar .pill div{width:24px;height:24px}
  .bar .dim{color:rgba(255,255,255,.55);font-weight:500}
  .card{position:absolute;right:72px;top:178px;width:400px;height:150px;border-radius:22px;overflow:hidden;
        background:linear-gradient(135deg,rgba(215,181,99,.35),rgba(80,60,20,.35));border:1px solid rgba(255,255,255,.12);
        box-shadow:0 30px 60px rgba(0,0,0,.45)}
  .card .cover{position:absolute;left:18px;top:18px;width:114px;height:114px;border-radius:12px;
        background:radial-gradient(circle at 40% 35%,#f1d58a,#9c7a2c 45%,#3b2b0e);box-shadow:0 8px 20px rgba(0,0,0,.35)}
  .card .cover div{position:absolute;inset:22px;opacity:.9}
  .card .t{position:absolute;left:150px;top:26px;font-size:19px;font-weight:700}
  .card .a{position:absolute;left:150px;top:52px;font-size:15px;font-weight:500;color:#E9C97A}
  .card .track{position:absolute;left:150px;right:22px;top:104px;height:5px;border-radius:3px;background:rgba(0,0,0,.35)}
  .card .track i{position:absolute;left:0;top:0;bottom:0;width:62%;border-radius:3px;background:#E9C97A}
  .card .fm{position:absolute;right:18px;top:20px;width:26px;height:26px}
  .logos{position:absolute;left:0;right:0;bottom:56px;display:flex;justify-content:center;gap:34px;padding:0 60px;
         -webkit-mask-image:linear-gradient(90deg,transparent,#000 12%,#000 88%,transparent)}
  .logos div{width:40px;height:40px;opacity:.5}
  .logos div.on{opacity:1}
</style></head><body>
  ${aurora()}<div class="grain"></div>
  <div class="content">
    <div class="brand"><div class="m">${mark()}</div><span>Emblem</span></div>
    <h1>Your music,<br><em>in your menu bar.</em></h1>
    <p>The Now Playing icon that turns into the logo of whoever's on in Spotify.</p>
  </div>
  <div class="bar"><div class="pill"><div>${logo(artists.find((a) => a.id === "travis") ?? artists[0])}</div></div><span class="dim">Fri 9:41 PM</span></div>
  <div class="card">
    <div class="cover"><div>${logo(artists.find((a) => a.id === "travis") ?? artists[0], "rgba(60,40,8,.55)")}</div></div>
    <div class="t">SICKO MODE</div><div class="a">Travis Scott</div>
    <div class="fm">${logo(artists.find((a) => a.id === "travis") ?? artists[0], "#E9C97A")}</div>
    <div class="track"><i></i></div>
  </div>
  <div class="logos">${ring.map((a) => `<div class="${a.id === "travis" ? "on" : ""}">${logo(a)}</div>`).join("")}</div>
</body></html>`;

// ---------- Lineup (1280 wide, 5 columns) ----------
const tiles = artists.map((a) => `
  <div class="tile" style="--a:${a.accent}">
    <div class="tint"></div>
    <div class="lg">${logo(a)}</div>
    <div class="nm">${a.name}</div>
  </div>`).join("") + `
  <div class="tile add"><div class="plus">+</div><div class="nm">Add your own</div></div>`;
const rows = Math.ceil((artists.length + 1) / 5);
const lineupHTML = `<!doctype html><html><head><style>${base}
  body{width:1280px;height:${150 + rows * 228}px;position:relative;overflow:hidden;background:#060608}
  .head{position:absolute;left:64px;top:52px;right:64px;display:flex;align-items:baseline;justify-content:space-between}
  .head h2{font-size:40px;font-weight:800;letter-spacing:-.035em}
  .head span{font-size:18px;color:rgba(255,255,255,.5);font-weight:500}
  .grid{position:absolute;left:64px;right:64px;top:128px;display:grid;grid-template-columns:repeat(5,1fr);gap:16px}
  .tile{position:relative;height:212px;border-radius:24px;overflow:hidden;background:#101014;border:1px solid rgba(255,255,255,.07)}
  .tint{position:absolute;inset:0;background:radial-gradient(120% 90% at 50% 0%,color-mix(in srgb,var(--a) 38%,transparent),transparent 70%)}
  .lg{position:absolute;left:50%;top:40px;width:96px;height:96px;transform:translateX(-50%);filter:drop-shadow(0 6px 18px rgba(0,0,0,.4))}
  .nm{position:absolute;left:0;right:0;bottom:24px;text-align:center;font-size:17px;font-weight:600;letter-spacing:-.01em}
  .tile::after{content:"";position:absolute;left:50%;bottom:12px;width:18px;height:3px;margin-left:-9px;border-radius:2px;background:var(--a)}
  .add{background:transparent;border:1.5px dashed rgba(255,255,255,.18)}
  .add::after{display:none}
  .plus{position:absolute;left:50%;top:44px;transform:translateX(-50%);font-size:76px;font-weight:300;line-height:88px;color:rgba(255,255,255,.4)}
  .add .nm{color:rgba(255,255,255,.55)}
</style></head><body>
  ${aurora(0.6)}<div class="grain"></div>
  <div class="head"><h2>The lineup</h2><span>${artists.length} artists · more on the way</span></div>
  <div class="grid">${tiles}</div>
</body></html>`;

const browser = await chromium.launch();
const shoot = async (html, out, w, h, scale, transparent = false) => {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
  await page.setContent(html, { waitUntil: "load" });
  await page.evaluate(() => document.fonts.ready);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  await page.screenshot({ path: out, omitBackground: transparent });
  await page.close();
  console.log("wrote", path.relative(root, out));
};
await shoot(bannerHTML, path.join(root, "docs/banner.png"), 1280, 640, 2);
await shoot(lineupHTML, path.join(root, "docs/lineup.png"), 1280, 150 + rows * 228, 2);
await shoot(iconHTML, path.join(root, "build/icon-1024.png"), 1024, 1024, 1, true);
await browser.close();
