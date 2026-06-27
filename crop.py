from PIL import Image
import os

img_path = r'C:\Files\Faculdade\PAC#1_Godot\BallisticVector\assets\sprites\missles.png'
out_dir = r'C:\Files\Faculdade\PAC#1_Godot\BallisticVector\assets\sprites'

img = Image.open(img_path).convert('RGBA')
width, height = img.size

# Find all bounding boxes by doing a simple scan
# We'll split the image into 4 quadrants for now to see if the missiles are one in each quadrant
w2, h2 = width//2, height//2

q1 = img.crop((0, 0, w2, h2)).crop(img.crop((0, 0, w2, h2)).getbbox())
q2 = img.crop((w2, 0, width, h2)).crop(img.crop((w2, 0, width, h2)).getbbox())
q3 = img.crop((0, h2, w2, height)).crop(img.crop((0, h2, w2, height)).getbbox())
q4 = img.crop((w2, h2, width, height)).crop(img.crop((w2, h2, width, height)).getbbox())

idx = 1
for q in (q1, q2, q3, q4):
    if q and q.size[0] > 0 and q.size[1] > 0:
        q.save(os.path.join(out_dir, f'missile_{idx}.png'))
        print(f'Saved missile_{idx}.png')
        idx += 1
