"""Cut the For All The Dogs dog out of its black cover so it can sit over the video.
Strokes stay fully opaque (so the tower's red light doesn't show through) and the
crop matches data/dog_strokes.json, which is in this image's pixel space (1472 x 1828)."""
import sys
import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
a = np.array(Image.open(src).convert('RGB').resize((2000, 2000))).astype(float)
al = np.clip((a.max(axis=2) - 40) * 5.0, 0, 255)
alpha = Image.fromarray(al.astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
img = Image.fromarray(np.clip(a * 1.12, 0, 255).astype(np.uint8)).convert('RGBA')
img.putalpha(alpha)
img.crop((130, 20, 1602, 1848)).save(out)
print(out)
