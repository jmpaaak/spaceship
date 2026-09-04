import sys, math
from PIL import Image

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGBA")
    pixels = im.load()
    w, h = im.size
    cx, cy = w/2, h/2
    
    # Simple color threshold for background: if it's very dark or matching corner
    bg_color = pixels[0,0]
    
    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx + 0.5, y - cy + 0.5)
            # Make corners absolutely transparent
            if x in (0, w-1) and y in (0, h-1):
                pixels[x, y] = (0, 0, 0, 0)
            elif dist > 15:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                # also make it transparent if it's close to the original bg_color
                # wait, the original bg_color might have been overwritten to (0,0,0,0) already
                pass
                
    im.save(path)
    print(f"Masked {path}")
