package client

import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"

import "vendor:raylib"
import enet "vendor:ENet"

import "../shared"

SCREEN_WIDTH  : i32 : 1138
SCREEN_HEIGHT : i32 : 640
SCREEN_TITLE  : cstring : "Teluria Window"
SCREEN_FPS    : i32 : 60

COLOR_BACKGROUND  : raylib.Color : raylib.LIGHTGRAY
COLOR_TEXTBOX     : raylib.Color : raylib.RAYWHITE
COLOR_CURSOR      : raylib.Color : raylib.GRAY
COLOR_OFFSET_BOX  : raylib.Color : raylib.BLUE
COLOR_TEXT        : raylib.Color : raylib.BLACK
COLOR_MSG_ERR     : raylib.Color : raylib.RED
COLOR_MSG_SUCCESS : raylib.Color : raylib.GREEN

PADDING      : i32 : FONT_SIZE / 3
TEXT_PADDING : i32 : FONT_SIZE / 4

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

Screen :: struct
{
    should_exit: bool,
    monitor: Monitor,
    line_input: LineInput,
}

cmd_connect :: proc(
    host: cstring,
    port: u16,
    monitor: ^Monitor,
    network: ^Network,
)
{
    monitor_append_line(monitor, "Connecting...")

    peer, err := net_client_connect(network.client, host, port)

    delete(host)

    network.peer = peer

    switch err
    {
        case .SUCCESS:
            network.status = .CONNECTING
            network.connection_time = 0.0
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

ConnectPromptData :: struct
{
    host: string,
    port: u16,
    username: string,
    password: string,
}

builtin_command_connect :: proc(
    cmd: ^shared.Command,
    screen: ^Screen,
    network: ^Network,
)
{
    // TODO: handle the error here
    prompt_data_ptr, _ := new(ConnectPromptData)

    screen.line_input.active_prompt = prompt_make(
        prompt_data_ptr,
        proc(data: rawptr, monitor: ^Monitor, network: ^Network)
        {
            prompt_data := (^ConnectPromptData)(data)

            cmd_connect(
                strings.clone_to_cstring(prompt_data.host),
                prompt_data.port,
                monitor,
                network,
            )
        },
        proc(data: rawptr)
        {
            prompt_data := (^ConnectPromptData)(data)

            delete(prompt_data.host)
            delete(prompt_data.username)
            delete(prompt_data.password)

            mem.free(data)
        },
    )

    prompt_add_step(
        screen.line_input.active_prompt,
        "[Connect] Please type the server's address.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)
            prompt_data.host = strings.clone(input)
            return true
        },
    )

    prompt_add_step(
        screen.line_input.active_prompt,
        "[Connect] Please type the server's port.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
        ) -> bool
        {
            port, ok := strconv.parse_uint(input)

            if !ok || port > uint(max(u16))
            {
                return false
            }

            prompt_data := (^ConnectPromptData)(data)
            prompt_data.port = u16(port)

            monitor_append_allocated_line(
                monitor,
                fmt.caprintf(
                    "[Connect] You have provided the address '%v:%v'.",
                    prompt_data.host,
                    prompt_data.port,
                ),
                raylib.GRAY,
            )

            return true
        },
    )

    prompt_add_step(
        screen.line_input.active_prompt,
        "[Connect] Please type your username.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)
            prompt_data.username = strings.clone(input)

            monitor_append_allocated_line(
                monitor,
                fmt.caprintf(
                    "[Connect] You have provided the username '%v'.",
                    prompt_data.username,
                ),
                raylib.GRAY,
            )

            line_input.silent = true
            return true
        },
    )

    prompt_add_step(
        screen.line_input.active_prompt,
        "[Connect] Please type your password.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)
            prompt_data.password = strings.clone(input)

            line_input.silent = false
            return true
        },
    )

    prompt_process_start(screen.line_input.active_prompt, &screen.monitor)
}

builtin_command_disconnect :: proc(
    command: ^shared.Command,
    monitor: ^Monitor,
    network: ^Network,
)
{
    if network.status != .CONNECTED {
        monitor_append_line(monitor, "You are not connected.")
        return
    }

    enet.peer_disconnect(network.peer, 0)
    monitor_append_line(monitor, "Disconnecting...")
}

handle_command :: proc(screen: ^Screen, network: ^Network)
{
    strings.pop_rune(&screen.line_input.text)
    command := shared.command_make(strings.to_string(screen.line_input.text))

    switch shared.command_get_next(&command)
    {
        case "connect":
            builtin_command_connect(&command, screen, network)
        case "disconnect":
            builtin_command_disconnect(&command, &screen.monitor, network)
        case "exit":
            screen.should_exit = true
        case:
            if network.status != .CONNECTED
            {
                monitor_append_line(
                    &screen.monitor,
                    "No such built-in command.",
                )
                return
            }

            strings.write_rune(&screen.line_input.text, 0)

            packet := enet.packet_create(
                rawptr(raw_data(strings.to_string(screen.line_input.text))),
                uint(strings.builder_len(screen.line_input.text)),
                .RELIABLE,
            )

            enet.peer_send(network.peer, NETWORK_SERVER_CHANNEL, packet)
    }
}

draw_step :: proc(screen: ^Screen, fonts: ^Fonts)
{
    raylib.BeginDrawing()
    defer raylib.EndDrawing()

    raylib.ClearBackground(COLOR_BACKGROUND)

    monitor_draw(&screen.monitor, fonts.serif)
    line_input_draw(&screen.line_input, fonts.serif)
}

process_input :: proc(
    network: ^Network,
    screen: ^Screen,
    fonts: ^Fonts,
    sound_engine: ^SoundEngine,
)
{
    if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER)
    {
        if screen.line_input.active_prompt != nil
        {
            strings.pop_rune(&screen.line_input.text)

            if !prompt_process_step(
                screen.line_input.active_prompt,
                strings.clone(strings.to_string(screen.line_input.text)),
                &screen.monitor,
                &screen.line_input,
                network,
            )
            {
                prompt_destroy(screen.line_input.active_prompt)
                screen.line_input.active_prompt = nil
            }
        }
        else
        {
            handle_command(screen, network)
        }

        line_input_reset(&screen.line_input)
    }
    else
    {
        line_input_handle_input(screen, fonts.serif, sound_engine)
    }
}

network_step :: proc(network: ^Network, screen: ^Screen)
{
    if network.status == .CONNECTING
    {
        network.connection_time += raylib.GetFrameTime()

        if network.connection_time >= 5.0
        {
            enet.peer_reset(network.peer)
            network.status = .STALLED
            network.connection_time = 0.0
            monitor_append_line(
                &screen.monitor,
                "Connection failed.",
                COLOR_MSG_ERR,
            )
        }
    }

    switch network_poll(network)
    {
        case .NO_EVENT:
            // Nothing should be done in this case
        case .FAILURE:
            monitor_append_line(
                &screen.monitor,
                "An error ocurred while trying to poll events.",
                COLOR_MSG_ERR,
            )
        case .EVENT:
            switch network.event.type
            {
                case .NONE:
                    // Nothing should be done in this case
                case .CONNECT:
                    network.status = .CONNECTED
                    monitor_append_line(
                        &screen.monitor,
                        "Successfully connected.",
                        COLOR_MSG_SUCCESS,
                    )
                case .DISCONNECT:
                    network.status = .STALLED
                    monitor_append_line(
                        &screen.monitor,
                        "Disconnected from the server.",
                    )
                case .RECEIVE:
                    // TODO: handle packet

                    enet.packet_destroy(network.event.packet)
            }
    }
}

main :: proc()
{
    when #config(DEBUG, false)
    {
        track: mem.Tracking_Allocator = {}
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            memory_mistakes: bool = false

            fmt.println("\n    Tracking allocator status report\n")

            if len(track.allocation_map) > 0
            {
                memory_mistakes = true

                fmt.eprintf(
                    "=== %v allocations not freed: ===\n",
                    len(track.allocation_map),
                )

                for _, entry in track.allocation_map
                {
                    fmt.eprintf(
                        "- %v bytes @ %v\n",
                        entry.size,
                        entry.location,
                    )
                }
            }

            if len(track.bad_free_array) > 0
            {
                memory_mistakes = true

                fmt.eprintf(
                    "=== %v incorrect frees: ===\n",
                    len(track.bad_free_array),
                )

                for entry in track.bad_free_array
                {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }

            mem.tracking_allocator_destroy(&track)

            if !memory_mistakes {
                fmt.printf("=== No memory mistakes found. ===")
            }
        }
    }

    raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE)
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(SCREEN_FPS)

    fonts := fonts_make()
    defer fonts_destroy(&fonts)

    screen := Screen {
        monitor = monitor_make(),
        line_input = line_input_make(),
    }

    defer monitor_destroy(&screen.monitor)
    defer line_input_destroy(&screen.line_input)

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

    network, err := network_make()

    switch err
    {
        case .NONE:
            // Nothing should be done
        case .FAILED_TO_INITIALIZE:
            fmt.println("Failed to initialize the Network module.")
            return
        case .FAILED_TO_CREATE_HOST:
            fmt.println("Failed to create host.")
            return
    }

    defer network_destroy(&network)

    for !raylib.WindowShouldClose() && !screen.should_exit
    {
        network_step(&network, &screen)
        process_input(&network, &screen, &fonts, &sound_engine)
        draw_step(&screen, &fonts)
    }
}
