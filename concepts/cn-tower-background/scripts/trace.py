import sys, numpy as np, potrace
from PIL import Image
src, out, thr = sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 110
a = np.array(Image.open(src).convert('RGBA')).astype(float)
alpha = a[..., 3] / 255; lum = a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11
ink = (alpha > 0.5) & (lum < thr)
ys, xs = np.where(ink)
path = potrace.Bitmap(~ink).trace(turdsize=6, alphamax=1.0, opticurve=True, opttolerance=0.2)
d = []
for c in path:
    s = c.start_point; d.append(f"M{s.x:.1f},{s.y:.1f}")
    for seg in c.segments:
        if seg.is_corner: d.append(f"L{seg.c.x:.1f},{seg.c.y:.1f}L{seg.end_point.x:.1f},{seg.end_point.y:.1f}")
        else: d.append(f"C{seg.c1.x:.1f},{seg.c1.y:.1f} {seg.c2.x:.1f},{seg.c2.y:.1f} {seg.end_point.x:.1f},{seg.end_point.y:.1f}")
    d.append("Z")
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max(); p = 4
open(out, 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0-p} {y0-p} {x1-x0+2*p} {y1-y0+2*p}"><path fill-rule="evenodd" d="{"".join(d)}"/></svg>')
print(out, d[0])
