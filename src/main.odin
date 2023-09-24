package teluria

import "core:strings"

import "vendor:raylib"
// import lua "vendor:lua/5.4"

SCREEN_WIDTH  : i32 : 1138
SCREEN_HEIGHT : i32 : 640
SCREEN_TITLE  : cstring : "Teluria Window"
SCREEN_FPS    : i32 : 60

COLOR_BACKGROUND : raylib.Color : raylib.LIGHTGRAY
COLOR_TEXTBOX    : raylib.Color : raylib.RAYWHITE
COLOR_TEXT       : raylib.Color : raylib.BLACK

FONT_SIZE : i32 : 32

PADDING      : i32 : FONT_SIZE / 3
TEXT_PADDING : i32 : FONT_SIZE / 6

LINE_INPUT_HEIGHT : i32 : FONT_SIZE + 2 * TEXT_PADDING
LINE_INPUT_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
LINE_INPUT_X      : i32 : PADDING
LINE_INPUT_Y      : i32 : SCREEN_HEIGHT - LINE_INPUT_HEIGHT - PADDING

MONITOR_HEIGHT : i32 : SCREEN_HEIGHT - 3 * PADDING - LINE_INPUT_HEIGHT
MONITOR_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
MONITOR_X      : i32 : PADDING
MONITOR_Y      : i32 : PADDING

LineInput :: struct
{
    text: strings.Builder,
}

line_input_make :: proc() -> LineInput
{
    line_input := LineInput {
        strings.builder_make(),
    }

    strings.write_rune(&line_input.text, 0)

    return line_input
}

line_input_destroy :: proc(line_input: ^LineInput)
{
    strings.builder_destroy(&line_input.text)
}

line_input_capture_input :: proc(line_input: ^LineInput)
{
    using raylib

    modified := false
    defer if modified
    {
        strings.write_rune(&line_input.text, 0)
    }

    c: rune = GetCharPressed()

    if c != 0
    {
        strings.pop_rune(&line_input.text)
        modified = true
    }

    for ; c != 0; c = GetCharPressed()
    {
        strings.write_rune(&line_input.text, c)
    }
}

line_input_to_cstring :: proc(line_input: ^LineInput) -> cstring
{
    return cstring(raw_data(strings.to_string(line_input.text)))
}

main :: proc()
{
    using raylib

    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE)
    defer CloseWindow()

    SetTargetFPS(SCREEN_FPS)

    serif_font := LoadFontEx("assets/font/s_regular.ttf", FONT_SIZE, nil, 0)
    defer UnloadFont(serif_font)

    line_input := line_input_make()
    defer line_input_destroy(&line_input)

    for !WindowShouldClose() {
        line_input_capture_input(&line_input)

        BeginDrawing()
        defer EndDrawing()

        ClearBackground(COLOR_BACKGROUND)

        DrawRectangle(
            MONITOR_X,
            MONITOR_Y,
            MONITOR_WIDTH,
            MONITOR_HEIGHT,
            COLOR_TEXTBOX
        )

        DrawRectangle(
            LINE_INPUT_X,
            LINE_INPUT_Y,
            LINE_INPUT_WIDTH,
            LINE_INPUT_HEIGHT,
            COLOR_TEXTBOX
        )

        DrawTextEx(
            serif_font,
            line_input_to_cstring(&line_input),
            {
                f32(LINE_INPUT_X + TEXT_PADDING),
                f32(LINE_INPUT_Y + TEXT_PADDING)
            },
            f32(FONT_SIZE),
            0.0,
            COLOR_TEXT
        )
    }
}
