#!/usr/bin/env python3

# based on raymond ma's imageconverter.py (https://github.com/ma-ray/Going-To-MARS/blob/main/imageconverter.py)
from PIL import Image
import sys

def xy_to_index(x, y, width=64):
    return (y * width + x) * 4

def img2asm(img_path):
    # buksan ang image
    im = Image.open(img_path)

    sad_yarn = {}
    
    for y in range(im.height):
        for x in range(im.width):
            pix = im.getpixel((x, y))
            # gawing 0xRRGGBB
            pix = (pix[0] << 16) | (pix[1] << 8) | pix[2]
            if pix == 0x000000:
                continue
            if pix not in sad_yarn:
                sad_yarn[pix] = [xy_to_index(x, y, im.width)]
            else:
                sad_yarn[pix].append(xy_to_index(x, y, im.width))

    print("\tla $t0, BASE_ADDRESS")

    mga_may_utang = list(sad_yarn.keys())

    while len(mga_may_utang) > 0:
        for i in range(min(9, len(mga_may_utang))):
            print(f"\tli $t{i+1}, {mga_may_utang[i]}")

        for key in sad_yarn:
            if key in mga_may_utang:
                idx = mga_may_utang.index(key)
                if idx < 9:
                    for i in sad_yarn[key]:
                        print(f"\tsw $t{idx+1}, {i}($t0)")

        mga_may_utang = mga_may_utang[9:]

    print("\tjr $ra")


if __name__ == "__main__":
    # kunin ang path ng image
    img_path = sys.argv[1]
    img2asm(img_path)
