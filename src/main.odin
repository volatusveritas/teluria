package teluria

import "core:strings"
import "core:fmt"

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

FONT_SIZE : i32 : 24

PADDING      : i32 : FONT_SIZE / 3
TEXT_PADDING : i32 : FONT_SIZE / 4

LINE_INPUT_HEIGHT : i32 : FONT_SIZE + 2 * TEXT_PADDING
LINE_INPUT_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
LINE_INPUT_X      : i32 : PADDING
LINE_INPUT_Y      : i32 : SCREEN_HEIGHT - LINE_INPUT_HEIGHT - PADDING
LINE_INPUT_RADIUS : f32 : 16.0 / f32(LINE_INPUT_HEIGHT)
LINE_INPUT_SEGS   : i32 : 16

MONITOR_HEIGHT : i32 : SCREEN_HEIGHT - 3 * PADDING - LINE_INPUT_HEIGHT
MONITOR_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
MONITOR_X      : i32 : PADDING
MONITOR_Y      : i32 : PADDING
MONITOR_RADIUS : f32 : 16.0 / f32(MONITOR_HEIGHT)
MONITOR_SEGS   : i32 : 16

CURSOR_WIDTH : f32 : f32(FONT_SIZE) / 16.0

DELETION_THRESHOLD : int : 30
DELETION_DELAY     : int : 2

MAX_INPUT_WIDTH : i32 : LINE_INPUT_WIDTH - 2 * TEXT_PADDING

SFX_TYPE_VOLUME : f32 : 0.20
SFX_TYPE_POLYPHONY : int : 5

SFX_DELETE_VOLUME : f32 : 0.10
SFX_DELETE_POLYPHONY : int : 5

SFX_SPACE_VOLUME : f32 : 0.20
SFX_SPACE_POLYPHONY : int : 1

MultiSoundPlayer :: struct
{
    sounds: [dynamic]raylib.Sound,
    polyphony: int,
    next: int
}

multi_sound_player_make :: proc(
    file_name: cstring,
    volume: f32,
    polyphony: int
) -> MultiSoundPlayer
{
    msp := MultiSoundPlayer { {}, polyphony, 0 }

    reserve(&msp.sounds, polyphony)

    for i in 0..<polyphony
    {
        append(&msp.sounds, raylib.LoadSound(file_name))
        raylib.SetSoundVolume(msp.sounds[i], volume)
    }

    return msp
}

multi_sound_player_unload :: proc(msp: ^MultiSoundPlayer)
{
    for sound in msp.sounds
    {
        raylib.UnloadSound(sound)
    }
}

multi_sound_player_play :: proc(msp: ^MultiSoundPlayer)
{
    if msp.next >= msp.polyphony - 1
    {
        msp.next = 0
    }

    raylib.PlaySound(msp.sounds[msp.next])

    msp.next += 1
}

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

line_input_destroy :: proc(li: ^LineInput)
{
    strings.builder_destroy(&li.text)
}

line_input_reset :: proc(li: ^LineInput)
{
    line_input_destroy(li)
    li^ = line_input_make()
}

line_input_get_text_width :: proc(li: ^LineInput, font: raylib.Font) -> f32
{
    return raylib.MeasureTextEx(
        font,
        line_input_to_cstring(li),
        f32(FONT_SIZE),
        0.0
    ).x
}

line_input_handle_control :: proc(li: ^LineInput)
{
    using raylib

    #partial switch GetKeyPressed()
    {
        case KeyboardKey.U:
            line_input_reset(li)
    }
}

line_input_handle_input :: proc(
    li: ^LineInput,
    font: raylib.Font,
    msp_type: ^MultiSoundPlayer,
    msp_delete: ^MultiSoundPlayer,
    msp_space: ^MultiSoundPlayer
)
{
    using raylib

    // TODO: make this work with delta instead of ticks
    @(static) deletion_ticks: int = 0

    modified := false
    defer if modified
    {
        strings.write_rune(&li.text, 0)
    }

    if (
        IsKeyDown(KeyboardKey.BACKSPACE)
        && strings.builder_len(li.text) > 1
    )
    {
        strings.pop_rune(&li.text)
        modified = true

        if IsKeyPressed(KeyboardKey.BACKSPACE)
        {
            strings.pop_rune(&li.text)
            multi_sound_player_play(msp_delete)
        }

        deletion_ticks += 1

        if deletion_ticks >= DELETION_THRESHOLD + DELETION_DELAY {
            strings.pop_rune(&li.text)
            deletion_ticks -= DELETION_DELAY
            multi_sound_player_play(msp_delete)
        }

        // TODO: improve this, this is hard to read and probably unclear
        li.offset -= 1

        for (
            line_input_get_text_width(li, font) < f32(MAX_INPUT_WIDTH)
            && li.offset >= 0
        )
        {
            li.offset -= 1
        }

        li.offset += 1

        return
    }

    deletion_ticks = 0

    if (
        IsKeyDown(KeyboardKey.LEFT_CONTROL) || IsKeyDown(KeyboardKey.RIGHT_CONTROL)
    )
    {
        line_input_handle_control(li)
        return
    }

    c: rune = GetCharPressed()

    if c != 0
    {
        strings.pop_rune(&li.text)
        modified = true

        switch c
        {
            case ' ':
                multi_sound_player_play(msp_space)
            case:
                multi_sound_player_play(msp_type)
        }
    }

    for ; c != 0; c = GetCharPressed()
    {
        strings.write_rune(&li.text, c)
    }

    for line_input_get_text_width(li, font) >= f32(MAX_INPUT_WIDTH)
    {
        li.offset += 1
    }
}

line_input_to_cstring :: proc(li: ^LineInput) -> cstring
{
    return cstring(raw_data(strings.to_string(li.text))[li.offset:])
}

handle_command :: proc(cmd: cstring)
{
    // TODO: handle the error here
    sections := strings.split(string(cmd), " ")

    switch sections[0]
    {
        case "say":
        case:
            // Look into the Lua custom commands
    }
}

main :: proc()
{
    using raylib

    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE)
    defer CloseWindow()

    InitAudioDevice()
    defer CloseAudioDevice()

    SetTargetFPS(SCREEN_FPS)

    serif_font := LoadFontEx("assets/font/s_regular.ttf", FONT_SIZE, nil, 0)
    defer UnloadFont(serif_font)

    msp_type := multi_sound_player_make(
        "assets/sfx/keyboard_type.mp3",
        SFX_TYPE_VOLUME,
        SFX_TYPE_POLYPHONY
    )
    defer multi_sound_player_unload(&msp_type)

    msp_delete := multi_sound_player_make(
        "assets/sfx/keyboard_delete.mp3",
        SFX_DELETE_VOLUME,
        SFX_DELETE_POLYPHONY
    )
    defer multi_sound_player_unload(&msp_delete)

    msp_space := multi_sound_player_make(
        "assets/sfx/keyboard_space.mp3",
        SFX_SPACE_VOLUME,
        SFX_SPACE_POLYPHONY
    )
    defer multi_sound_player_unload(&msp_space)

    line_input := line_input_make()
    defer line_input_destroy(&line_input)

    for !WindowShouldClose() {
        line_input_handle_input(
            &line_input,
            serif_font,
            &msp_type,
            &msp_delete,
            &msp_space
        )

        BeginDrawing()
        defer EndDrawing()

        ClearBackground(COLOR_BACKGROUND)

        DrawRectangleRounded(
            {
                f32(MONITOR_X),
                f32(MONITOR_Y),
                f32(MONITOR_WIDTH),
                f32(MONITOR_HEIGHT)
            },
            MONITOR_RADIUS,
            MONITOR_SEGS,
            COLOR_TEXTBOX
        )

        DrawRectangleRounded(
            {
                f32(LINE_INPUT_X),
                f32(LINE_INPUT_Y),
                f32(LINE_INPUT_WIDTH),
                f32(LINE_INPUT_HEIGHT)
            },
            LINE_INPUT_RADIUS,
            LINE_INPUT_SEGS,
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
        // cursor_target_offset := line_input_text_width
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
