import sys
from PIL import Image

def analyze(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    
    unique_colors = set()
    non_dark = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a > 0:
                unique_colors.add((r, g, b))
                if r > 10 or g > 10 or b > 10:
                    non_dark += 1

    print(f"File: {path}")
    print(f"Dimensions: {w}x{h}")
    print(f"unique_rgb: {len(unique_colors)}")
    print(f"non_dark_pixels: {non_dark}")

analyze(sys.argv[1])
analyze(sys.argv[2])
