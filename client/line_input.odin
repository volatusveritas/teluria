package client

import "vendor:raylib"
import "core:strings"

LINE_INPUT_HEIGHT : i32 : FONT_SIZE + 2 * TEXT_PADDING
LINE_INPUT_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
LINE_INPUT_X      : i32 : PADDING
LINE_INPUT_Y      : i32 : SCREEN_HEIGHT - LINE_INPUT_HEIGHT - PADDING
LINE_INPUT_ROUND  : f32 : 16.0
LINE_INPUT_RADIUS : f32 : LINE_INPUT_ROUND / f32(LINE_INPUT_HEIGHT)
LINE_INPUT_SEGS   : i32 : 16

LineInput :: struct
{
    text: strings.Builder,
    offset: i32,
    silent: bool,
    active_prompt: ^Prompt,
}

line_input_make :: proc() -> LineInput
{
    line_input := LineInput {
        text = strings.builder_make(),
        offset = 0,
        silent = false,
        active_prompt = nil,
    }

    strings.write_rune(&line_input.text, 0)

    return line_input
}

line_input_destroy :: proc(li: ^LineInput)
{
    strings.builder_destroy(&li.text)
}

line_input_reset :: proc(line_input: ^LineInput)
{
    strings.builder_reset(&line_input.text)
    strings.write_rune(&line_input.text, 0)
}

line_input_remake :: proc(line_input: ^LineInput)
{
    line_input_reset(line_input)
    prompt_destroy(line_input.active_prompt)
    line_input.active_prompt = nil

    line_input.silent = false
}

line_input_get_text_width :: proc(li: ^LineInput, font: raylib.Font) -> f32
{
    return raylib.MeasureTextEx(
        font,
        line_input_to_cstring(li),
        f32(FONT_SIZE),
        0.0,
    ).x
}

line_input_handle_control :: proc(screen: ^Screen)
{
    #partial switch raylib.GetKeyPressed()
    {
        case raylib.KeyboardKey.U:
            line_input_reset(&screen.line_input)
        case raylib.KeyboardKey.C:
            monitor_append_line(&screen.monitor, "Input cancelled by the user.")
            line_input_remake(&screen.line_input)
    }
}

line_input_handle_input :: proc(
    screen: ^Screen,
    font: raylib.Font,
    sound_engine: ^SoundEngine,
)
{
    // TODO: make this work with delta instead of ticks
    @(static) deletion_ticks: int = 0

    modified := false
    defer if modified
    {
        strings.write_rune(&screen.line_input.text, 0)
    }

    if (
        raylib.IsKeyDown(raylib.KeyboardKey.BACKSPACE)
        && strings.builder_len(screen.line_input.text) > 1
    )
    {
        strings.pop_rune(&screen.line_input.text)
        modified = true

        if raylib.IsKeyPressed(raylib.KeyboardKey.BACKSPACE)
        {
            strings.pop_rune(&screen.line_input.text)
            sound_engine_play(sound_engine, "kb_delete")
        }

        deletion_ticks += 1

        if deletion_ticks >= DELETION_THRESHOLD + DELETION_DELAY {
            strings.pop_rune(&screen.line_input.text)
            deletion_ticks -= DELETION_DELAY
            sound_engine_play(sound_engine, "kb_delete")
        }

        // TODO: improve this, this is hard to read and probably unclear
        screen.line_input.offset -= 1

        for (
            line_input_get_text_width(&screen.line_input, font) < f32(MAX_INPUT_WIDTH)
            && screen.line_input.offset >= 0
        )
        {
            screen.line_input.offset -= 1
        }

        screen.line_input.offset += 1

        return
    }

    deletion_ticks = 0

    if (
        raylib.IsKeyDown(raylib.KeyboardKey.LEFT_CONTROL)
        || raylib.IsKeyDown(raylib.KeyboardKey.RIGHT_CONTROL)
    )
    {
        line_input_handle_control(screen)
        return
    }

    c: rune = raylib.GetCharPressed()

    if c != 0
    {
        strings.pop_rune(&screen.line_input.text)
        modified = true

        if c == ' '
        {
            sound_engine_play(sound_engine, "kb_space")
        }
        else
        {
            sound_engine_play(sound_engine, "kb_type")
        }
    }

    for ; c != 0; c = raylib.GetCharPressed()
    {
        strings.write_rune(&screen.line_input.text, c)
    }

    for line_input_get_text_width(&screen.line_input, font) >= f32(MAX_INPUT_WIDTH)
    {
        screen.line_input.offset += 1
    }
}

line_input_to_cstring :: proc(li: ^LineInput) -> cstring
{
    return cstring(raw_data(strings.to_string(li.text))[li.offset:])
}

line_input_draw :: proc(li: ^LineInput, font: raylib.Font)
{
    using raylib

    @(static) cursor_offset: f32 = 0.0

    DrawRectangleRounded(
        {
            f32(LINE_INPUT_X),
            f32(LINE_INPUT_Y),
            f32(LINE_INPUT_WIDTH),
            f32(LINE_INPUT_HEIGHT),
        },
        LINE_INPUT_RADIUS,
        LINE_INPUT_SEGS,
        COLOR_TEXTBOX,
    )

    if !li.silent
    {
        DrawTextEx(
            font,
            line_input_to_cstring(li),
            {
                f32(LINE_INPUT_X + TEXT_PADDING),
                f32(LINE_INPUT_Y + TEXT_PADDING),
            },
            f32(FONT_SIZE),
            FONT_SPACING,
            COLOR_TEXT,
        )

        cursor_offset += (
            (line_input_get_text_width(li, font) - cursor_offset)
            * GetFrameTime()
            * CURSOR_SPEED
        )
    }
    else
    {
        cursor_offset += (
            (0 - cursor_offset)
            * GetFrameTime()
            * CURSOR_SPEED
        )
    }

    DrawLineEx(
        {
            f32(LINE_INPUT_X + TEXT_PADDING) + cursor_offset,
            f32(LINE_INPUT_Y + TEXT_PADDING),
        },
        {
            f32(LINE_INPUT_X + TEXT_PADDING) + cursor_offset,
            f32(LINE_INPUT_Y + TEXT_PADDING + FONT_SIZE),
        },
        CURSOR_WIDTH,
        COLOR_CURSOR,
    )
}
