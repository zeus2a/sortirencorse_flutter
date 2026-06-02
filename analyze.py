from PIL import Image

def analyze(img_path):
    img = Image.open(img_path).convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    bg_color = pixels[0, 0]
    print(f"Background color: {bg_color}")
    
    min_x, min_y, max_x, max_y = width, height, 0, 0
    
    # Tolerance for background
    tol = 5
    
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if abs(r - bg_color[0]) > tol or abs(g - bg_color[1]) > tol or abs(b - bg_color[2]) > tol:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    print(f"Bounding box of inner content: ({min_x}, {min_y}) to ({max_x}, {max_y})")
    print(f"Width: {max_x - min_x}, Height: {max_y - min_y}")

if __name__ == "__main__":
    analyze(r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\icone_512x512.png")
