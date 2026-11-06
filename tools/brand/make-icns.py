"""Turns build/icon-1024.png (from render.mjs) into Resources/AppIcon.icns. Needs Pillow."""
from PIL import Image
img = Image.open("build/icon-1024.png").convert("RGBA")
img.save("Resources/AppIcon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
print("wrote Resources/AppIcon.icns")
