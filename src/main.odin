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
COLOR_CURSOR     : raylib.Color : raylib.GRAY

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

CURSOR_WIDTH : f32 : 1.5

DELETION_THRESHOLD : int : 30
DELETION_DELAY     : int : 2

MAX_INPUT_WIDTH : i32 : LINE_INPUT_WIDTH - 2 * TEXT_PADDING

LineInput :: struct
{
    text: strings.Builder,
    offset: i32
}

line_input_make :: proc() -> LineInput
{
    line_input := LineInput {
        strings.builder_make(),
        0
    }

    strings.write_rune(&line_input.text, 0)

    return line_input
}

line_input_destroy :: proc(line_input: ^LineInput)
{
    strings.builder_destroy(&line_input.text)
}

line_input_get_text_width :: proc(
    line_input: ^LineInput,
    font: raylib.Font
) -> f32
{
    return raylib.MeasureTextEx(
        font,
        line_input_to_cstring(line_input),
        f32(FONT_SIZE),
        0.0
    ).x
}

line_input_capture_input :: proc(line_input: ^LineInput, font: raylib.Font)
{
    using raylib

    // TODO: make this work with delta instead of ticks
    @(static) deletion_ticks: int = 0

    modified := false
    defer if modified
    {
        strings.write_rune(&line_input.text, 0)
    }

    if (
        IsKeyDown(KeyboardKey.BACKSPACE)
        && strings.builder_len(line_input.text) > 0
    )
    {
        strings.pop_rune(&line_input.text)
        modified = true

        if IsKeyPressed(KeyboardKey.BACKSPACE)
        {
            strings.pop_rune(&line_input.text)
        }

        deletion_ticks += 1

        if deletion_ticks >= DELETION_THRESHOLD + DELETION_DELAY {
            strings.pop_rune(&line_input.text)
            deletion_ticks -= DELETION_DELAY
        }

        for (
            line_input_get_text_width(line_input, font) < f32(MAX_INPUT_WIDTH)
            && line_input.offset > 0
        )
        {
            line_input.offset -= 1
        }

        return
    }

    deletion_ticks = 0

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

    for line_input_get_text_width(line_input, font) >= f32(MAX_INPUT_WIDTH)
    {
        line_input.offset += 1
    }
}

line_input_to_cstring :: proc(line_input: ^LineInput) -> cstring
{
    return cstring(raw_data(strings.to_string(line_input.text))[line_input.offset:])
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
        line_input_capture_input(&line_input, serif_font)

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

        line_input_text_width := line_input_get_text_width(
            &line_input,
            serif_font
        )
        
        // TODO: make this non-static
        // @(static) cursor_target_offset = line_input_text_width
        @(static) cursor_offset: f32 = 0.0

        cursor_offset += (
            (line_input_text_width - cursor_offset) * GetFrameTime() * 16.0
        )

        DrawLineEx(
            {
                f32(LINE_INPUT_X + TEXT_PADDING) + cursor_offset,
                f32(LINE_INPUT_Y + TEXT_PADDING)
            },
            {
                f32(LINE_INPUT_X + TEXT_PADDING) + cursor_offset,
                f32(LINE_INPUT_Y + TEXT_PADDING + FONT_SIZE)
            },
            CURSOR_WIDTH,
            COLOR_CURSOR
        )
    }
}
