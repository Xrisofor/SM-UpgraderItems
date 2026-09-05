import os
import numpy as np
from PIL import Image

def make_white_transparent(img, tolerance=240):
    img = img.convert("RGBA")
    data = np.array(img)
    r, g, b, a = data[:,:,0], data[:,:,1], data[:,:,2], data[:,:,3]
    
    white_areas = (r > tolerance) & (g > tolerance) & (b > tolerance)
    data[white_areas, 3] = 0
    
    return Image.fromarray(data)

def create_circular_mask(width, height, percentage):
    cx, cy = width / 2.0, height / 2.0
    x = np.arange(width) - cx
    y = np.arange(height) - cy
    xx, yy = np.meshgrid(x, y)
    
    angles = np.degrees(np.arctan2(xx, -yy)) % 360.0
    threshold_angle = (percentage / 100.0) * 360.0
    
    mask_data = np.where(angles <= threshold_angle, 255, 0).astype(np.uint8)
    
    return Image.fromarray(mask_data, mode='L')

def generate_frames(bg_path, fg_path, output_dir="circle_frames"):
    if not os.path.exists(bg_path) or not os.path.exists(fg_path):
        print(f"Files '{bg_path}' or '{fg_path}' not found.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    bg_img = Image.open(bg_path).convert("RGBA")
    fg_img = Image.open(fg_path)
    
    fg_img = make_white_transparent(fg_img)
    
    if fg_img.size != bg_img.size:
        fg_img = fg_img.resize(bg_img.size, Image.Resampling.LANCZOS)
        
    width, height = bg_img.size
    
    for pct in range(101):
        mask = create_circular_mask(width, height, pct)
        combined = Image.composite(fg_img, bg_img, mask)
        output_path = os.path.join(output_dir, f"circle_{pct:03d}.png")
        combined.save(output_path, "PNG")

if __name__ == "__main__":
    generate_frames("bg.png", "fg.png")