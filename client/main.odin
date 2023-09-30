package client

import "core:strings"
import "core:fmt"
import "core:mem"

import enet "vendor:ENet"
import "vendor:raylib"
// import lua "vendor:lua/5.4"

SCREEN_WIDTH  : i32 : 1138
SCREEN_HEIGHT : i32 : 640
SCREEN_TITLE  : cstring : "Teluria Window"
SCREEN_FPS    : i32 : 60

COLOR_BACKGROUND : raylib.Color : raylib.LIGHTGRAY
COLOR_TEXTBOX    : raylib.Color : raylib.RAYWHITE
COLOR_CURSOR     : raylib.Color : raylib.GRAY
COLOR_OFFSET_BOX : raylib.Color : raylib.BLUE
COLOR_TEXT       : raylib.Color : raylib.BLACK

FONT_SIZE    : i32 : 16
FONT_SPACING : f32 = 0.0

PADDING      : i32 : FONT_SIZE / 3
TEXT_PADDING : i32 : FONT_SIZE / 4

LINE_INPUT_HEIGHT : i32 : FONT_SIZE + 2 * TEXT_PADDING
LINE_INPUT_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
LINE_INPUT_X      : i32 : PADDING
LINE_INPUT_Y      : i32 : SCREEN_HEIGHT - LINE_INPUT_HEIGHT - PADDING
LINE_INPUT_ROUND  : f32 : 16.0
LINE_INPUT_RADIUS : f32 : LINE_INPUT_ROUND / f32(LINE_INPUT_HEIGHT)
LINE_INPUT_SEGS   : i32 : 16

MONITOR_HEIGHT : i32 : SCREEN_HEIGHT - 3 * PADDING - LINE_INPUT_HEIGHT
MONITOR_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
MONITOR_X      : i32 : PADDING
MONITOR_Y      : i32 : PADDING
MONITOR_ROUND  : f32 : 16.0
MONITOR_RADIUS : f32 : MONITOR_ROUND / f32(MONITOR_HEIGHT)
MONITOR_SEGS   : i32 : 16

CURSOR_WIDTH : f32 : f32(FONT_SIZE) / 16.0
CURSOR_SPEED : f32 : 16.0

DELETION_THRESHOLD : int : 30
DELETION_DELAY     : int : 2

MAX_INPUT_WIDTH : i32 : LINE_INPUT_WIDTH - 2 * TEXT_PADDING

SFX_TYPE_VOLUME : f32 : 0.20
SFX_TYPE_POLYPHONY : int : 5

SFX_DELETE_VOLUME : f32 : 0.10
SFX_DELETE_POLYPHONY : int : 5

SFX_SPACE_VOLUME : f32 : 0.20
SFX_SPACE_POLYPHONY : int : 1

Monitor :: struct
{
    lines: [dynamic]cstring,
    colors: [dynamic]raylib.Color,
}

monitor_make :: proc() -> Monitor
{
    return Monitor { {}, {} }
}

monitor_destroy :: proc(m: ^Monitor)
{
    delete(m.lines)
    delete(m.colors)
}

monitor_append_line :: proc(
    m: ^Monitor,
    line: cstring,
    color: raylib.Color = COLOR_TEXT
)
{
    append(&m.lines, line)
    append(&m.colors, color)
}

monitor_draw :: proc(m: ^Monitor, font: raylib.Font)
{
    using raylib

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

    for i in 0..<len(m.lines)
    {
        DrawTextEx(
            font,
            m.lines[i],
            {
                f32(MONITOR_X + TEXT_PADDING),
                f32(MONITOR_Y + TEXT_PADDING + i32(i) * FONT_SIZE),
            },
            f32(FONT_SIZE),
            FONT_SPACING,
            m.colors[i]
        )
    }
}

LineInput :: struct
{
    text: strings.Builder,
    offset: i32,
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

line_input_handle_input :: proc(li: ^LineInput, font: raylib.Font)
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
        }

        deletion_ticks += 1

        if deletion_ticks >= DELETION_THRESHOLD + DELETION_DELAY {
            strings.pop_rune(&li.text)
            deletion_ticks -= DELETION_DELAY
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

line_input_draw :: proc(li: ^LineInput, font: raylib.Font)
{
    using raylib

    @(static) cursor_offset: f32 = 0.0

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
        font,
        line_input_to_cstring(li),
        {
            f32(LINE_INPUT_X + TEXT_PADDING),
            f32(LINE_INPUT_Y + TEXT_PADDING)
        },
        f32(FONT_SIZE),
        FONT_SPACING,
        COLOR_TEXT
    )

    cursor_offset += (
        (line_input_get_text_width(li, font) - cursor_offset)
        * GetFrameTime()
        * CURSOR_SPEED
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

    SetTargetFPS(SCREEN_FPS)

    serif_font := LoadFontEx("assets/font/s_regular.ttf", FONT_SIZE, nil, 0)
    defer UnloadFont(serif_font)

    monitor := monitor_make()
    defer monitor_destroy(&monitor)

    line_input := line_input_make()
    defer line_input_destroy(&line_input)

    sound_engine, ok := sound_engine_make()

    if !ok
    {
        fmt.println("Could not initialize the Sound Engine.")
        return
    }

    defer sound_engine_destroy(&sound_engine)

    ok = sound_engine_register_sound(
        &sound_engine, "kb_type", "assets/sfx/kb_type.mp3"
    )

    if !ok
    {
        fmt.println("Failed to lead KB_TYPE.")
        return
    }

    ok = sound_engine_register_sound(
        &sound_engine, "kb_space", "assets/sfx/kb_space.mp3"
    )

    if !ok
    {
        fmt.println("Failed to lead KB_SPACE.")
        return
    }

    ok = sound_engine_register_sound(
        &sound_engine, "kb_delete", "assets/sfx/kb_delete.mp3"
    )

    if !ok
    {
        fmt.println("Failed to lead KB_DELETE.")
        return
    }

    if enet.initialize() != 0
    {
        fmt.println("Could not initialize ENet.")
        return
    }

    defer enet.deinitialize()

    client := enet.host_create(nil, 1, 2, 0, 0)

    if client == nil
    {
        fmt.println("Could not create the client.")
        return
    }

    defer enet.host_destroy(client)

    address := enet.Address{}

    if enet.address_set_host(&address, "127.0.0.1") != 0
    {
        fmt.println("Could not resolve the host address.")
        return
    }

    address.port = 25565

    peer := enet.host_connect(client, &address, 2, 0)

    if peer == nil
    {
        fmt.println("Could not connect to the foreign host.")
        return
    }

    event := enet.Event{}

    network_time: f32 = 0.0
    connecting := false
    connected := false

    monitor_append_line(&monitor, "Connecting...")

    for !WindowShouldClose() {
        network_time += GetFrameTime()

        if enet.host_service(client, &event, 0) < 0
        {
            fmt.println("Could not poll events.")
            enet.peer_reset(peer)
            return
        }

        if event.type == .CONNECT
        {
            connected = true
            connecting = false
            monitor_append_line(&monitor, "Successfully connected.")
        }

        if connecting && !connected && network_time >= 5.0
        {
            enet.peer_reset(peer)
            connecting = false
            monitor_append_line(&monitor, "Connection failed.")
        }

        line_input_handle_input(&line_input, serif_font)

        BeginDrawing()
        defer EndDrawing()

        ClearBackground(COLOR_BACKGROUND)

        monitor_draw(&monitor, serif_font)

        line_input_draw(&line_input, serif_font)
    }
}
