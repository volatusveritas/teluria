package client

import "core:fmt"

import "vendor:raylib"

FONT_SIZE : i32 : 16
FONT_SPACING : f32 = 0.0
FONT_DIR :: "assets/font"
FONT_SANS_FILENAME :: "regular.ttf"
FONT_SERIF_FILENAME :: "s_regular.ttf"

Fonts :: struct
{
    sans: raylib.Font,
    serif: raylib.Font,
}

fonts_make :: proc() -> Fonts
{
    sans_font_path := fmt.caprintf("%v/%v", FONT_DIR, FONT_SANS_FILENAME)
    defer delete(sans_font_path)
    serif_font_path := fmt.caprintf("%v/%v", FONT_DIR, FONT_SERIF_FILENAME)
    defer delete(serif_font_path)

    return Fonts {
        sans = raylib.LoadFontEx(sans_font_path, FONT_SIZE, nil, 0),
        serif = raylib.LoadFontEx(serif_font_path, FONT_SIZE, nil, 0),
    }
}

fonts_destroy :: proc(fonts: ^Fonts)
{
    raylib.UnloadFont(fonts.sans)
    raylib.UnloadFont(fonts.serif)
}
