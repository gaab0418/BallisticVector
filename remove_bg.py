from PIL import Image

def remove_bg(p, out):
    img = Image.open(p).convert('RGBA')
    data = img.getdata()
    new_data = []
    for d in data:
        if d[0] > 240 and d[1] > 240 and d[2] > 240:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(d)
    img.putdata(new_data)
    img.save(out)
    print('Saved', out)

remove_bg(r'C:\Users\Gab\.gemini\antigravity-cli\brain\54e1a6c8-392f-4420-9fd7-34b85c330aa6\steampunk_tank_1782519014923.jpg', r'C:\Files\Faculdade\PAC#1_Godot\BallisticVector\assets\sprites\tank_player.png')
remove_bg(r'C:\Users\Gab\.gemini\antigravity-cli\brain\54e1a6c8-392f-4420-9fd7-34b85c330aa6\steampunk_airplane_1782519029244.jpg', r'C:\Files\Faculdade\PAC#1_Godot\BallisticVector\assets\sprites\airplane_enemy.png')
