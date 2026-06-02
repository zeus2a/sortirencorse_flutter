import urllib.request
from PIL import Image, ImageDraw, ImageFont
import qrcode
from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.moduledrawers.pil import RoundedModuleDrawer
from qrcode.image.styles.colormasks import VerticalGradiantColorMask

def extract_inner_rounded_box(img_path):
    img = Image.open(img_path).convert("RGBA")
    margin = 76
    box = (margin, margin, 512 - margin, 512 - margin)
    cropped = img.crop(box)
    size = cropped.size[0]
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * 0.22)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    cropped.putalpha(mask)
    return cropped

def generate_android_final_qr(url, logo_path, output_path):
    qr = qrcode.QRCode(
        version=6, 
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=30, 
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)

    color_mask = VerticalGradiantColorMask(
        back_color=(255, 255, 255), 
        top_color=(255, 100, 0),
        bottom_color=(0, 150, 255)
    )

    qr_img = qr.make_image(
        image_factory=StyledPilImage,
        module_drawer=RoundedModuleDrawer(),
        color_mask=color_mask
    ).convert("RGBA")

    logo = extract_inner_rounded_box(logo_path)
    qr_width, qr_height = qr_img.size
    
    logo_size = int(qr_width * 0.33)
    logo = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    pos = ((qr_width - logo_size) // 2, (qr_height - logo_size) // 2)
    
    protection_mask = Image.new("RGBA", qr_img.size, (0,0,0,0))
    prot_draw = ImageDraw.Draw(protection_mask)
    prot_radius = int(logo_size * 0.22) + 4
    prot_draw.rounded_rectangle((pos[0]-6, pos[1]-6, pos[0]+logo_size+6, pos[1]+logo_size+6), radius=prot_radius, fill=(255,255,255,255))
    qr_img = Image.alpha_composite(qr_img, protection_mask)

    qr_img.paste(logo, pos, mask=logo)

    bg_color = (15, 23, 42) 
    final_width = qr_width + 200
    final_height = qr_height + 250
    final_img = Image.new("RGBA", (final_width, final_height), bg_color)
    
    qr_bg_size = qr_width + 40
    qr_bg = Image.new("RGBA", (qr_bg_size, qr_bg_size), (0,0,0,0))
    qr_bg_draw = ImageDraw.Draw(qr_bg)
    qr_bg_draw.rounded_rectangle((0, 0, qr_bg_size, qr_bg_size), radius=40, fill=(255,255,255,255))
    
    qr_bg_pos = ((final_width - qr_bg_size) // 2, 100)
    final_img.paste(qr_bg, qr_bg_pos, mask=qr_bg)
    
    qr_pos = (qr_bg_pos[0] + 20, qr_bg_pos[1] + 20)
    final_img.paste(qr_img, qr_pos, mask=qr_img)

    draw = ImageDraw.Draw(final_img)
    try:
        font_title = ImageFont.truetype("segoeuib.ttf", 90)
        font_sub = ImageFont.truetype("segoeuib.ttf", 45) # En gras pour Google Play
    except:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # Calculer les dimensions du texte
    text = "Sortir en Corse"
    bbox = draw.textbbox((0, 0), text, font=font_title)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Charger le badge Google Play
    badge_path = r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\google_play_badge.png"
    try:
        badge = Image.open(badge_path).convert("RGBA")
        
        # Redimensionner le badge pour qu'il fasse à peu près la même hauteur que le texte (environ 90px)
        badge_target_height = 90
        badge_ratio = badge_target_height / badge.size[1]
        badge_width = int(badge.size[0] * badge_ratio)
        badge = badge.resize((badge_width, badge_target_height), Image.Resampling.LANCZOS)
        
        # Calculer la largeur totale du groupe (Texte + Espace + Badge)
        spacing = 40
        total_width = text_width + spacing + badge_width
        
        # Calculer le point de départ X pour centrer le groupe
        start_x = (final_width - total_width) // 2
        text_y = qr_bg_pos[1] + qr_bg_size + 60
        
        # Dessiner le texte (avec son ombre)
        draw.text((start_x+3, text_y+3), text, fill=(255, 100, 0, 150), font=font_title)
        draw.text((start_x, text_y), text, fill=(255, 255, 255, 255), font=font_title)
        
        # Coller le badge à côté du texte
        badge_x = start_x + text_width + spacing
        # On ajuste légèrement le Y pour l'aligner parfaitement avec le texte
        badge_y = text_y + (text_height - badge_target_height) // 2 + 10
        final_img.paste(badge, (badge_x, badge_y), mask=badge)
        
    except Exception as e:
        print("Erreur badge:", e)
        text_x = (final_width - text_width) // 2
        text_y = qr_bg_pos[1] + qr_bg_size + 60
        draw.text((text_x+3, text_y+3), text, fill=(255, 100, 0, 150), font=font_title)
        draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font_title)

    final_img = final_img.convert("RGB")
    final_img.save(output_path, quality=100)
    print(f"Visuel Android généré sous : {output_path}")

if __name__ == "__main__":
    # URL vers le serveur PHP de ZEUS HUB
    app_url = "https://api.corsemusicevents.fr/track_qr.php?source=flyer_officiel"
    logo_file = r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\icone_512x512.png"
    output_file = r"C:\Users\Zeus\Desktop\Zeus_Projects\app\playstore_images\qr_code_android_officiel_tracked.png"
    
    generate_android_final_qr(app_url, logo_file, output_file)
