import sys
from PIL import Image

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGBA")
    pixels = im.load()
    w, h = im.size
    
    def color_dist(c1, c2):
        return sum(abs(a - b) for a, b in zip(c1[:3], c2[:3]))
        
    corners = [(0,0), (w-1,0), (0,h-1), (w-1,h-1)]
    visited = set()
    
    for cx, cy in corners:
        bg_color = pixels[cx, cy]
        # Ignore if already transparent
        if bg_color[3] == 0:
            continue
            
        stack = [(cx, cy)]
        while stack:
            x, y = stack.pop()
            if (x, y) in visited:
                continue
            visited.add((x, y))
            
            if color_dist(pixels[x, y], bg_color) < 60:
                pixels[x, y] = (0, 0, 0, 0)
                
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        stack.append((nx, ny))
                        
    im.save(path)
    print(f"Made {path} transparent")
