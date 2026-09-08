import json
import sys
import os
import hashlib
import urllib.request
from datetime import datetime, timezone, timedelta
from PIL import Image

def main():
    if len(sys.argv) < 3:
        print("Usage: python call_pixel_perfect.py <input_jpg> <planet_id>")
        sys.exit(1)
        
    input_jpg = sys.argv[1]
    planet_id = sys.argv[2]
    
    img = Image.open(input_jpg)
    original_dims = img.size
    
    img = img.resize((1024, 1024), Image.LANCZOS).convert("RGBA")
    data = list(img.getdata())
    flat_data = []
    for r, g, b, a in data:
        flat_data.extend([r, g, b, a])
        
    req_data = {
        "image": {
            "width": 1024,
            "height": 1024,
            "data": flat_data
        },
        "targetWidth": 512,
        "targetHeight": 512,
        "pixelBlock": 4,
        "backgroundTolerance": 28,
        "paletteLimit": 64
    }
    
    json_bytes = json.dumps(req_data).encode("utf-8")
    payload_sha256 = hashlib.sha256(json_bytes).hexdigest()
    payload_bytes = len(json_bytes)
    
    kst = timezone(timedelta(hours=9))
    requested_at = datetime.now(kst).isoformat(timespec='seconds')
    
    log_dir = f"docs/assets/runs/{planet_id}"
    os.makedirs(log_dir, exist_ok=True)
    
    req_log = {
        "requested_at": requested_at,
        "endpoint": "http://127.0.0.1:4176/api/pixel-perfect",
        "method": "POST",
        "content_type": "application/json",
        "source_path": input_jpg,
        "source_dimensions": original_dims,
        "input_preparation": {
            "resize": [1024, 1024],
            "resampling": "Pillow LANCZOS",
            "mode": "RGBA"
        },
        "parameters": {
            "targetWidth": 512,
            "targetHeight": 512,
            "pixelBlock": 4,
            "backgroundTolerance": 28,
            "paletteLimit": 64
        },
        "payload_sha256": payload_sha256,
        "payload_bytes": payload_bytes,
        "note": "payload hash covers the exact compact JSON body, including RGBA input data; raw pixels are reproducible from the preserved source and input_preparation"
    }
    
    with open(f"{log_dir}/request.json", "w") as f:
        json.dump(req_log, f, indent=2)
    
    req = urllib.request.Request("http://127.0.0.1:4176/api/pixel-perfect", data=json_bytes, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as response:
            resp_bytes = response.read()
            resp_sha256 = hashlib.sha256(resp_bytes).hexdigest()
            http_status = response.getcode()
            
            resp_data = json.loads(resp_bytes)
            out_img = resp_data["image"]
            out_width = out_img["width"]
            out_height = out_img["height"]
            out_pixels = out_img["data"]
            
            img_out = Image.new("RGBA", (out_width, out_height))
            pixels = []
            for i in range(0, len(out_pixels), 4):
                pixels.append(tuple(out_pixels[i:i+4]))
            img_out.putdata(pixels)
            
            image_rgba_bytes = b''.join([bytes(p) for p in pixels])
            image_rgba_sha256 = hashlib.sha256(image_rgba_bytes).hexdigest()
            
            # Save the JSON response (without raw data)
            resp_log = resp_data.copy()
            del resp_log["image"]
            with open(f"{log_dir}/response.json", "w") as f:
                json.dump(resp_log, f, indent=2)
                
            master_path = f"docs/assets/masters/planet/{planet_id}_master.png"
            os.makedirs(os.path.dirname(master_path), exist_ok=True)
            img_out.save(master_path, "PNG")
            
            runtime_img = img_out.resize((128, 128), Image.NEAREST)
            runtime_path = f"assets/planet/studio/{planet_id}.png"
            os.makedirs(os.path.dirname(runtime_path), exist_ok=True)
            runtime_img.save(runtime_path, "PNG")
            
            master_sha = hashlib.sha256(open(master_path, "rb").read()).hexdigest()
            runtime_sha = hashlib.sha256(open(runtime_path, "rb").read()).hexdigest()
            
            print("DONE.")
            print(f"master: {master_sha}")
            print(f"runtime: {runtime_sha}")
            print(f"body_sha256: {resp_sha256}")
            print(f"image_rgba_sha256: {image_rgba_sha256}")
            print(f"payload_sha256: {payload_sha256}")
            
    except Exception as e:
        print(f"Error: {e}")
        
if __name__ == '__main__':
    main()
