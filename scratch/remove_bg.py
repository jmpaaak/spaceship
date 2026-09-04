from PIL import Image, ImageDraw
import sys

def remove_bg(path):
    img = Image.open(path).convert("RGBA")
    
    # Create a mask by floodfilling from corners
    mask = Image.new("L", img.size, 0)
    
    # We need to map the image to L mode or RGB to flood fill.
    # Actually ImageDraw.floodfill works on the image itself.
    # So we copy the image, fill with a weird color, then compare.
    img_copy = img.convert("RGB")
    ImageDraw.floodfill(img_copy, (0, 0), (255, 0, 255), thresh=30)
    ImageDraw.floodfill(img_copy, (img.width-1, 0), (255, 0, 255), thresh=30)
    ImageDraw.floodfill(img_copy, (0, img.height-1), (255, 0, 255), thresh=30)
    ImageDraw.floodfill(img_copy, (img.width-1, img.height-1), (255, 0, 255), thresh=30)
    
    datas = img.getdata()
    copy_datas = img_copy.getdata()
    
    new_data = []
    for i, item in enumerate(datas):
        if copy_datas[i] == (255, 0, 255):
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(path, "PNG")

for p in sys.argv[1:]:
    remove_bg(p)
