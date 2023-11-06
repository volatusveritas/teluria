package client

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strconv"
import "core:strings"

import "vendor:raylib"
import enet "vendor:ENet"

import "../shared"

when !#config(TR_ALLOC, false)
{
    // Abusing a compiler bug to solve a design issue; no one will convince me
    // of the opposite.
    _ :: mem
}

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
    prompt: Prompt,
}

LoginCredentials :: struct
{
    username: string,
    password: string,
}

ClientInfo :: struct
{
    login_credentials: LoginCredentials,
    new_account: bool,
}

ConnectPromptData :: struct
{
    host: string,
    port: u16,
    username: string,
    password: string,
    new_account: bool,
}

send_login_credentials :: proc(
    network: ^Network,
    client_info: ^ClientInfo,
)
{
    shared.network_writer_reset(&network.writer)

    shared.network_writer_set_type(
        &network.writer,
        .REGISTER if client_info.new_account else .LOGIN,
    )

    shared.network_writer_push_string(
        &network.writer,
        client_info.login_credentials.username,
    )
    shared.network_writer_push_string(
        &network.writer,
        client_info.login_credentials.password,
    )

    packet := shared.network_writer_to_packet(&network.writer)
    // TODO: there may be an error here
    enet.peer_send(network.peer, NETWORK_SERVER_CHANNEL, packet)
}

// TODO: change this function's name
cmd_connect :: proc(
    host: cstring,
    port: u16,
    monitor: ^Monitor,
    network: ^Network,
)
{
    monitor_append_line(monitor, "Connecting...")

    peer, err := net_client_connect(network.client, host, port)

    switch err
    {
        case .SUCCESS:
            // Nothing should be done here
        case .RESOLVE_HOST:
            log.error("Failed to resolve the host.")
            return
        case .ATTEMPT_CONNECTION:
            log.error("Failed to attempt connection")
            return
    }

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

builtin_command_connect :: proc(
    cmd: ^shared.Command,
    screen: ^Screen,
    network: ^Network,
    client_info: ^ClientInfo,
)
{
    data := new(ConnectPromptData)

    prompt_setup(&screen.prompt, data)

    screen.prompt.destroy_callback = proc(data: rawptr)
    {
        prompt_data := (^ConnectPromptData)(data)

        delete(prompt_data.host)
        delete(prompt_data.username)
        delete(prompt_data.password)

        free(data)
    }

    screen.prompt.done_callback = proc(
        data: rawptr,
        monitor: ^Monitor,
        network: ^Network,
        client_info: ^ClientInfo,
    )
    {
        prompt_data := (^ConnectPromptData)(data)

        client_info.login_credentials.username = prompt_data.username
        client_info.login_credentials.password = prompt_data.password
        client_info.new_account = prompt_data.new_account

        cmd_connect(
            strings.clone_to_cstring(prompt_data.host),
            prompt_data.port,
            monitor,
            network,
        )
    }

    prompt_add_step(
        &screen.prompt,
        "[Connect] Please type the server's address.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
            prompt: ^Prompt,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)
            prompt_data.host = strings.clone(input)
            return true
        },
    )

    prompt_add_step(
        &screen.prompt,
        "[Connect] Please type the server's port.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
            prompt: ^Prompt,
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
        &screen.prompt,
        "[Connect] Please type 'login' or 'register'.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
            prompt: ^Prompt,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)

            if input == "login"
            {
                prompt_data.new_account = false

                monitor_append_line(
                    monitor,
                    "[Connect] A login attempt will be made.",
                    raylib.GRAY,
                )
            }
            else if input == "register"
            {
                prompt_data.new_account = true

                monitor_append_line(
                    monitor,
                    "[Connect] A registration attempt will be made.",
                    raylib.GRAY,
                )
            }
            else
            {
                monitor_append_line(
                    monitor,
                    "[Connect] There is no such option.",
                    raylib.GRAY,
                )

                prompt.next_step -= 1
            }

            return true
        },
    )

    prompt_add_step(
        &screen.prompt,
        "[Connect] Please type your username.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
            prompt: ^Prompt,
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
        &screen.prompt,
        "[Connect] Please type your password.",
        proc(
            data: rawptr,
            input: string,
            monitor: ^Monitor,
            line_input: ^LineInput,
            network: ^Network,
            prompt: ^Prompt,
        ) -> bool
        {
            prompt_data := (^ConnectPromptData)(data)
            prompt_data.password = strings.clone(input)

            line_input.silent = false
            return true
        },
    )

    prompt_process_start(screen.prompt, &screen.monitor)
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

handle_command :: proc(
    screen: ^Screen,
    network: ^Network,
    client_info: ^ClientInfo,
)
{
    strings.pop_rune(&screen.line_input.text)
    command := shared.command_make(strings.to_string(screen.line_input.text))

    switch shared.command_get_next(&command)
    {
        case "connect":
            builtin_command_connect(&command, screen, network, client_info)
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

draw_step :: proc(screen: Screen, fonts: Fonts)
{
    raylib.BeginDrawing()
    defer raylib.EndDrawing()

    raylib.ClearBackground(COLOR_BACKGROUND)

    monitor_draw(screen.monitor, fonts.serif)
    line_input_draw(screen.line_input, fonts.serif)
}

process_input :: proc(
    network: ^Network,
    screen: ^Screen,
    fonts: ^Fonts,
    sound_engine: ^SoundEngine,
    client_info: ^ClientInfo,
)
{
    input_length := strings.builder_len(screen.line_input.text)

    if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) && input_length > 1
    {
        if screen.prompt.active
        {
            strings.pop_rune(&screen.line_input.text)

            if !prompt_process_step(
                &screen.prompt,
                strings.clone(strings.to_string(screen.line_input.text)),
                &screen.monitor,
                &screen.line_input,
                network,
                client_info,
            )
            {
                prompt_reset(&screen.prompt)
            }
        }
        else
        {
            handle_command(screen, network, client_info)
        }

        line_input_reset(&screen.line_input)
    }
    else
    {
        line_input_handle_input(screen, fonts.serif, sound_engine)
    }
}

network_step :: proc(
    network: ^Network,
    screen: ^Screen,
    client_info: ^ClientInfo,
)
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

    network_status := network_poll(network)

    if network_status != .EVENT
    {
        if network_status == .FAILURE
        {
            monitor_append_line(
                &screen.monitor,
                "An error ocurred while trying to poll events.",
                COLOR_MSG_ERR,
            )
        }

        return
    }

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

            send_login_credentials(
                network,
                client_info,
            )
        case .DISCONNECT:
            network.status = .STALLED

            monitor_append_line(
                &screen.monitor,
                "Disconnected from the server.",
            )
        case .RECEIVE:
            log.info("Event captured: RECEIVE")

            shared.network_reader_load_packet(
                &network.reader,
                network.event.packet,
            )

            type, type_err := shared.network_reader_get_type(&network.reader)

            if type_err != .None || type != .MESSAGE
            {
                return
            }

            message, message_err := shared.network_reader_read_string(
                &network.reader,
            )

            if message_err != .None
            {
                return
            }

            monitor_append_allocated_line(
                &screen.monitor,
                strings.clone_to_cstring(message),
            )

            enet.packet_destroy(network.event.packet)
    }
}

main :: proc()
{
    context.logger = log.create_console_logger(
        opt=log.Options{.Level} | log.Full_Timestamp_Opts,
    )

    defer log.destroy_console_logger(context.logger)

    when ODIN_DEBUG
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
        prompt = prompt_make(),
    }

    defer monitor_destroy(screen.monitor)
    defer line_input_destroy(&screen.line_input)
    defer prompt_destroy(screen.prompt)

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
        case .INITIALIZE:
            fmt.println("Failed to initialize the Network module.")
            return
        case .CREATE_HOST:
            fmt.println("Failed to create host.")
            return
    }

    defer network_destroy(&network)

    client_info := ClientInfo {
        login_credentials = {},
    }

    for !raylib.WindowShouldClose() && !screen.should_exit
    {
        network_step(&network, &screen, &client_info)
        process_input(&network, &screen, &fonts, &sound_engine, &client_info)
        draw_step(screen, fonts)
    }
}
