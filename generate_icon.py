#!/usr/bin/env python3
"""
Generate Gate Control app icon
Simple gate icon with blue background
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_gate_icon(size, output_path):
    """Create a gate icon with specified size"""
    # Create image with blue background
    img = Image.new('RGBA', (size, size), (33, 150, 243, 255))  # Material Blue
    draw = ImageDraw.Draw(img)
    
    # Gate dimensions
    margin = size * 0.15
    gate_width = size - (2 * margin)
    gate_height = size * 0.6
    
    # Gate position
    gate_x = margin
    gate_y = size - margin - gate_height
    
    # Draw gate bars (white)
    bar_color = (255, 255, 255, 255)
    bar_width = gate_width * 0.12
    num_bars = 5
    spacing = (gate_width - (num_bars * bar_width)) / (num_bars - 1)
    
    for i in range(num_bars):
        x = gate_x + i * (bar_width + spacing)
        draw.rectangle(
            [x, gate_y, x + bar_width, gate_y + gate_height],
            fill=bar_color
        )
    
    # Draw top bar (horizontal)
    draw.rectangle(
        [gate_x, gate_y, gate_x + gate_width, gate_y + bar_width],
        fill=bar_color
    )
    
    # Draw phone icon indicator (small)
    phone_size = size * 0.15
    phone_x = size - margin - phone_size
    phone_y = margin
    
    # Phone shape (rounded rectangle)
    draw.rounded_rectangle(
        [phone_x, phone_y, phone_x + phone_size, phone_y + phone_size * 1.5],
        radius=phone_size * 0.15,
        fill=(255, 255, 255, 255),
        outline=(33, 150, 243, 255),
        width=int(size * 0.01)
    )
    
    # Phone screen
    screen_margin = phone_size * 0.15
    draw.rounded_rectangle(
        [phone_x + screen_margin, phone_y + screen_margin, 
         phone_x + phone_size - screen_margin, phone_y + phone_size * 1.5 - screen_margin],
        radius=phone_size * 0.1,
        fill=(33, 150, 243, 255)
    )
    
    img.save(output_path, 'PNG')
    print(f"✓ Created icon: {output_path} ({size}x{size})")

def create_foreground_icon(size, output_path):
    """Create transparent foreground icon for adaptive icon"""
    # Create transparent image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Gate dimensions (larger for foreground)
    margin = size * 0.25
    gate_width = size - (2 * margin)
    gate_height = size * 0.5
    
    # Gate position (centered)
    gate_x = margin
    gate_y = (size - gate_height) / 2
    
    # Draw gate bars (white with shadow)
    bar_color = (255, 255, 255, 255)
    bar_width = gate_width * 0.12
    num_bars = 5
    spacing = (gate_width - (num_bars * bar_width)) / (num_bars - 1)
    
    for i in range(num_bars):
        x = gate_x + i * (bar_width + spacing)
        # Shadow
        draw.rectangle(
            [x + 2, gate_y + 2, x + bar_width + 2, gate_y + gate_height + 2],
            fill=(0, 0, 0, 100)
        )
        # Bar
        draw.rectangle(
            [x, gate_y, x + bar_width, gate_y + gate_height],
            fill=bar_color
        )
    
    # Draw top bar (horizontal)
    # Shadow
    draw.rectangle(
        [gate_x + 2, gate_y + 2, gate_x + gate_width + 2, gate_y + bar_width + 2],
        fill=(0, 0, 0, 100)
    )
    # Bar
    draw.rectangle(
        [gate_x, gate_y, gate_x + gate_width, gate_y + bar_width],
        fill=bar_color
    )
    
    img.save(output_path, 'PNG')
    print(f"✓ Created foreground icon: {output_path} ({size}x{size})")

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, 'assets', 'icon')
    
    # Create assets directory if it doesn't exist
    os.makedirs(assets_dir, exist_ok=True)
    
    # Generate main icon (1024x1024 for best quality)
    main_icon_path = os.path.join(assets_dir, 'gate_icon.png')
    create_gate_icon(1024, main_icon_path)
    
    # Generate foreground icon for adaptive icon
    foreground_icon_path = os.path.join(assets_dir, 'gate_icon_foreground.png')
    create_foreground_icon(1024, foreground_icon_path)
    
    print("\n✓ Icons generated successfully!")
    print("Run: flutter pub get")
    print("Then: dart run flutter_launcher_icons")
