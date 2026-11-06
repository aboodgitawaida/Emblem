// Renders Emblem's brand images from the artist folders:
//   docs/banner.png     README header
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

// Order the banner's logo row by how recognisable the mark is, then anything new alphabetically.
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
// The players are the app's own renders (docs/player-*.png, 2× of the 308 × 140pt player), shown at 1:1.
const shot = (name) => "data:image/png;base64," + fs.readFileSync(path.join(root, "docs", name + ".png")).toString("base64");
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
  .players{position:absolute;right:64px;top:0;bottom:120px;width:420px}
  .players img{position:absolute;width:308px;height:140px;filter:drop-shadow(0 24px 40px rgba(0,0,0,.55))}
  .logos{position:absolute;left:0;right:0;bottom:56px;display:flex;justify-content:center;gap:34px;padding:0 60px;
         -webkit-mask-image:linear-gradient(90deg,transparent,#000 12%,#000 88%,transparent)}
  .logos div{width:40px;height:40px;opacity:.5}
  .logos div.on{opacity:1}
</style></head><body>
  ${aurora()}<div class="grain"></div>
  <div class="content">
    <div class="brand"><div class="m">${mark()}</div><span>Emblem</span></div>
    <h1>Your music,<br><em>in your menu bar.</em></h1>
    <p>The Now Playing icon that turns into the logo of whoever's playing.</p>
  </div>
  <div class="players">
    <img src="${shot("player-drake")}" style="right:0;top:52px;opacity:.9;transform:scale(.94)">
    <img src="${shot("player-weeknd")}" style="right:96px;top:196px;opacity:.95;transform:scale(.97)">
    <img src="${shot("player-travis")}" style="right:16px;top:340px">
  </div>
  <div class="logos">${ring.map((a) => `<div class="${a.id === "travis" ? "on" : ""}">${logo(a)}</div>`).join("")}</div>
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
await shoot(iconHTML, path.join(root, "build/icon-1024.png"), 1024, 1024, 1, true);
await browser.close();
