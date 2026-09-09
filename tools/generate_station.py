import os
from PIL import Image, ImageDraw

def generate_station():
    # Size 64x64
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw central hub
    draw.ellipse((20, 20, 44, 44), fill=(180, 180, 180, 255), outline=(100, 100, 100, 255))
    
    # Draw solar panels
    draw.rectangle((2, 28, 20, 36), fill=(50, 50, 150, 255), outline=(100, 100, 100, 255))
    draw.rectangle((44, 28, 62, 36), fill=(50, 50, 150, 255), outline=(100, 100, 100, 255))
    
    # Grid lines on panels
    draw.line((6, 28, 6, 36), fill=(100, 100, 200, 255))
    draw.line((14, 28, 14, 36), fill=(100, 100, 200, 255))
    draw.line((50, 28, 50, 36), fill=(100, 100, 200, 255))
    draw.line((58, 28, 58, 36), fill=(100, 100, 200, 255))
    
    # Draw docking port
    draw.rectangle((30, 44, 34, 52), fill=(150, 150, 150, 255), outline=(50, 50, 50, 255))
    
    os.makedirs("assets/station", exist_ok=True)
    img.save("assets/station/station.png")

if __name__ == "__main__":
    generate_station()
