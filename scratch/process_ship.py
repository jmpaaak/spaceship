import sys
import subprocess
from PIL import Image
import os

def process_ship(asset_path, prompt, width=512, height=512):
    print(f"Generating {asset_path}...")
    full_prompt = f"top-down small silver spaceship, pixel art, black background, {prompt}"
    cmd = [
        "python3", "tools/comfyui_asset_pipeline.py",
        "--asset-path", asset_path,
        "--prompt", full_prompt,
        "--width", str(width),
        "--height", str(height)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Failed to generate {asset_path}:\n{res.stdout}\n{res.stderr}")
        return False
        
    print(f"Post-processing {asset_path}...")
    img = Image.open(asset_path).convert("RGBA")
    
    # Remove black background (assuming pixels with R<30, G<30, B<30 are background)
    data = img.getdata()
    new_data = []
    for item in data:
        if item[0] < 30 and item[1] < 30 and item[2] < 30:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    
    # Crop to bounding box
    bbox = img.getbbox()
    if not bbox:
        print(f"Image is fully transparent?")
        return False
    
    img_cropped = img.crop(bbox)
    
    # Target size for the ship is ~60% of 64x64, so around 38x38
    target_ship_size = 38
    
    # Calculate resize ratio
    w, h = img_cropped.size
    ratio = min(target_ship_size / w, target_ship_size / h)
    new_w = int(w * ratio)
    new_h = int(h * ratio)
    
    img_resized = img_cropped.resize((new_w, new_h), Image.Resampling.NEAREST)
    
    # Paste into 64x64 transparent background
    final_img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    offset_x = (64 - new_w) // 2
    offset_y = (64 - new_h) // 2
    final_img.paste(img_resized, (offset_x, offset_y))
    
    final_img.save(asset_path)
    print(f"Saved {asset_path}")
    return True

if __name__ == "__main__":
    if process_ship("assets/ship/ship_default.png", "standard basic symmetric shape, balanced"):
        if process_ship("assets/ship/ship_scout.png", "sleek, fast, aerodynamic, swept wings"):
            print("Done!")
            sys.exit(0)
    sys.exit(1)
