"""Separa o cano do casco em assets/sprites/tank_player.png.

Gera tank_hull.png (o tanque sem o cano) e tank_barrel.png (so o cano), para a
arena girar o cano em torno do munhao e o angulo da HUD ficar visivel no proprio
tanque. Rode da raiz do projeto, uma vez, se o sprite original mudar:

    python3 tools/split_tank_sprite.py

Requer Pillow. As coordenadas abaixo sao do PNG original (676x369).
"""

from PIL import Image

SRC = "assets/sprites/tank_player.png"
BARREL_BOX = (414, 118, 641, 158)  # cano + freio de boca, saindo do mantelete

im = Image.open(SRC).convert("RGBA")
im.crop(BARREL_BOX).save("assets/sprites/tank_barrel.png")

hull = im.copy()
hull.paste((0, 0, 0, 0), BARREL_BOX)
hull.save("assets/sprites/tank_hull.png")
print("ok: tank_hull.png e tank_barrel.png")
