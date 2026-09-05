import os
from PIL import Image

def generate_rotated_arrow(image_path, output_dir="arrow_frames", start_from_bottom=True):
    if not os.path.exists(image_path):
        print(f"File '{image_path}' not found.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    arrow_img = Image.open(image_path).convert("RGBA")
    
    for pct in range(101):
        progress_angle = (pct / 100.0) * 360.0

        if start_from_bottom:
            total_angle = 180.0 + progress_angle
        else:
            total_angle = progress_angle

        rotation_angle = -total_angle
        
        rotated_img = arrow_img.rotate(
            rotation_angle, 
            resample=Image.Resampling.BICUBIC,
            center=None
        )
        
        output_path = os.path.join(output_dir, f"arrow_{pct:03d}.png")
        rotated_img.save(output_path, "PNG")

if __name__ == "__main__":
    generate_rotated_arrow("arrow.png", start_from_bottom=True)