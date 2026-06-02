from PIL import Image, ImageDraw

def process_logo(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    
    # L'image originale a une grosse bordure grise autour du bouton central.
    # On va rogner pour ne garder que le bouton central.
    # D'après l'image, la marge est d'environ 15-18% de chaque côté.
    margin = int(width * 0.16)
    
    left = margin
    top = margin
    right = width - margin
    bottom = height - margin
    
    # Rogner l'image
    cropped = img.crop((left, top, right, bottom))
    c_width, c_height = cropped.size
    
    # Appliquer un masque avec des coins arrondis lisses pour enlever ce qui dépasse
    mask = Image.new("L", (c_width, c_height), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(c_width * 0.25) # Arrondi doux
    draw.rounded_rectangle((0, 0, c_width, c_height), radius=radius, fill=255)
    
    cropped.putalpha(mask)
    cropped.save(output_path)
    print(f"Logo recadré sauvegardé sous {output_path}")

if __name__ == "__main__":
    input_file = r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\icone_512x512.png"
    output_file = r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\cropped_logo.png"
    process_logo(input_file, output_file)
