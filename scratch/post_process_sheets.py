import sys
from PIL import Image

def process(in_path, out_path):
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    # Expect 4 horizontal frames
    frame_w = h
    frame_h = h
    num_frames = w // frame_w
    if num_frames != 4:
        print(f"Warning: {in_path} has {num_frames} frames instead of 4")
    
    out_img = Image.new("RGBA", (frame_w, frame_h * num_frames))
    for i in range(num_frames):
        frame = img.crop((i * frame_w, 0, (i + 1) * frame_w, frame_h))
        out_img.paste(frame, (0, i * frame_h))
    
    out_img.save(out_path)
    print(f"Saved {out_path}")

if __name__ == "__main__":
    process(*sys.argv[1:3])
