package client

import "core:fmt"
import "core:strings"

import "vendor:raylib"
import enet "vendor:ENet"

import "../shared"

SCREEN_WIDTH  : i32 : 1138
SCREEN_HEIGHT : i32 : 640
SCREEN_TITLE  : cstring : "Teluria Window"
SCREEN_FPS    : i32 : 60

COLOR_BACKGROUND : raylib.Color : raylib.LIGHTGRAY
COLOR_TEXTBOX    : raylib.Color : raylib.RAYWHITE
COLOR_CURSOR     : raylib.Color : raylib.GRAY
COLOR_OFFSET_BOX : raylib.Color : raylib.BLUE
COLOR_TEXT       : raylib.Color : raylib.BLACK

COLOR_MSG_ERR     : raylib.Color : raylib.RED
COLOR_MSG_SUCCESS : raylib.Color : raylib.GREEN

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
    color: raylib.Color = COLOR_TEXT,
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
            f32(MONITOR_HEIGHT),
        },
        MONITOR_RADIUS,
        MONITOR_SEGS,
        COLOR_TEXTBOX,
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
            m.colors[i],
        )
    }
}

cmd_connect :: proc(
    host: cstring,
    port: u16,
    monitor: ^Monitor,
    network: ^Network,
)
{
    peer, err := net_client_connect(network.client, host, port)

    network.peer = peer

    switch err
    {
        case .SUCCESS:
            network.status = .CONNECTING
        case .RESOLVE_HOST:
            monitor_append_line(
                monitor,
                "Failed to resolve the host.",
                COLOR_MSG_ERR,
            )
        case .ATTEMPT_CONNECTION:
            monitor_append_line(
                monitor,
                "Failed to make a connection attempt.",
                COLOR_MSG_ERR,
            )
    }
}

builtin_command_connect :: proc(
    cmd: ^shared.Command,
    monitor: ^Monitor,
    network: ^Network,
)
{
    USAGE_MSG :: "Usage: connect {host} {port}"

    if !shared.command_has_next(cmd)
    {
        monitor_append_line(
            monitor,
            "Command syntax error: missing arguments {host}, {port}.",
            COLOR_MSG_ERR,
        )
        monitor_append_line(monitor, USAGE_MSG)
        return
    }

    host := shared.command_get_string(cmd)

    if !shared.command_has_next(cmd)
    {
        monitor_append_line(
            monitor,
            "Command syntax error: missing argument {port}.",
            COLOR_MSG_ERR,
        )
        monitor_append_line(monitor, USAGE_MSG)
        return
    }

    port, ok := shared.command_get_u16(cmd)

    if !ok
    {
        monitor_append_line(
            monitor,
            "Command syntax error: port must be a number between 0 and 65535.",
            COLOR_MSG_ERR,
        )
        monitor_append_line(monitor, USAGE_MSG)
        return
    }

    if network.status != .STALLED
    {
        monitor_append_line(monitor, "Cancelling ongoing connection...")
        enet.peer_reset(network.peer)
    }

    monitor_append_line(monitor, "Connecting...")
    cmd_connect(strings.clone_to_cstring(host), port, monitor, network)
}

handle_command :: proc(
    line_input: ^LineInput,
    monitor: ^Monitor,
    network: ^Network,
)
{
    strings.pop_rune(&line_input.text)
    command := shared.command_make(strings.to_string(line_input.text))

    switch shared.command_get_next(&command)
    {
        case "connect":
            builtin_command_connect(&command, monitor, network)
        case:
            strings.write_rune(&line_input.text, 0)

            packet := enet.packet_create(
                rawptr(raw_data(strings.to_string(line_input.text))),
                uint(strings.builder_len(line_input.text)),
                .RELIABLE,
            )

            enet.peer_send(network.peer, NETWORK_SERVER_CHANNEL, packet)
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
        0,
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
        0.0,
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
    monitor: ^Monitor,
    sound_engine: ^SoundEngine,
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
            sound_engine_play(sound_engine, "kb_delete")
        }

        deletion_ticks += 1

        if deletion_ticks >= DELETION_THRESHOLD + DELETION_DELAY {
            strings.pop_rune(&li.text)
            deletion_ticks -= DELETION_DELAY
            sound_engine_play(sound_engine, "kb_delete")
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
        IsKeyDown(KeyboardKey.LEFT_CONTROL)
        || IsKeyDown(KeyboardKey.RIGHT_CONTROL)
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

        if c == ' '
        {
            sound_engine_play(sound_engine, "kb_space")
        }
        else
        {
            sound_engine_play(sound_engine, "kb_type")
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
        &sound_engine, "kb_type", "assets/sfx/kb_type.mp3",
    )

    if !ok
    {
        fmt.println("Failed to lead KB_TYPE.")
        return
    }

    ok = sound_engine_register_sound(
        &sound_engine, "kb_space", "assets/sfx/kb_space.mp3",
    )

    if !ok
    {
        fmt.println("Failed to lead KB_SPACE.")
        return
    }

    ok = sound_engine_register_sound(
        &sound_engine, "kb_delete", "assets/sfx/kb_delete.mp3",
    )

    if !ok
    {
        fmt.println("Failed to lead KB_DELETE.")
        return
    }

    if !net_make()
    {
        fmt.eprintln("Failed to initialize the networking engine.")
        return
    }

    defer net_destroy()

    network: Network

    network.client = net_client_make()

    if network.client == nil
    {
        fmt.eprintln("Failed to initialize the network client.")
        return
    }

    defer net_client_destroy(&network, network.client)

    defer if network.status != .STALLED
    {
    }

    for !WindowShouldClose()
    {
        if network.status == .CONNECTING
        {
            network.connection_time += GetFrameTime()
        }

        switch network_poll(&network)
        {
            case .NO_EVENT:

            case .EVENT:
                switch network.event.type
                {
                    case .NONE:

                    case .CONNECT:
                        network.status = .CONNECTED
                        network.connection_time = 0.0
                        monitor_append_line(
                            &monitor,
                            "Successfully connected.",
                            COLOR_MSG_SUCCESS,
                        )
                    case .DISCONNECT:
                        network.status = .STALLED
                        monitor_append_line(
                            &monitor,
                            "Disconnected from the server.",
                        )
                    case .RECEIVE:
                        pk_text := strings.string_from_ptr(
                            network.event.packet.data,
                            int(network.event.packet.dataLength),
                        )

                        new_line := strings.clone_to_cstring(pk_text)

                        monitor_append_line(&monitor, new_line)

                        enet.packet_destroy(network.event.packet)
                }
            case .FAILURE:
                monitor_append_line(
                    &monitor,
                    "An error ocurred while trying to poll events.",
                    COLOR_MSG_ERR,
                )
        }

        if network.status == .CONNECTING && network.connection_time >= 5.0
        {
            enet.peer_reset(network.peer)
            network.status = .STALLED
            network.connection_time = 0.0
            monitor_append_line(
                &monitor,
                "Connection failed.",
                COLOR_MSG_ERR,
            )
        }

        if IsKeyPressed(KeyboardKey.ENTER)
        {
            handle_command(&line_input, &monitor, &network)
            line_input_reset(&line_input)
        }
        else
        {
            line_input_handle_input(
                &line_input, serif_font, &monitor, &sound_engine,
            )
        }

        BeginDrawing()
        defer EndDrawing()

        ClearBackground(COLOR_BACKGROUND)

        monitor_draw(&monitor, serif_font)

        line_input_draw(&line_input, serif_font)
    }
}
