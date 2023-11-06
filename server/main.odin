package server

import "core:fmt"
import "core:mem"
import "core:log"

import enet "vendor:ENet"
import lua "vendor:lua/5.4"

import "../data_stream"

when !#config(TR_ALLOC, false)
{
    _ :: fmt
    _ :: mem
}

HOST_POLL_TIMEOUT :: 200
HOST_ADDRESS :: "127.0.0.1"
HOST_PORT :: 25565
HOST_PEER_COUNT :: 32
HOST_CHANNELS :: 2
HOST_INBOUND_BANDWIDTH :: 0
HOST_OUTBOUND_BANDWIDTH :: 0

ServerInfo :: struct
{
    user_credentials: map[string]string,
}

server_info_make :: proc() -> ServerInfo
{
    return ServerInfo {
        user_credentials = make(map[string]string),
    }
}

server_info_destroy :: proc(server_info: ^ServerInfo)
{
    delete(server_info.user_credentials)
}

handle_packet :: proc(
    event: enet.Event,
    lua_state: ^lua.State,
    stream: ^data_stream.Stream,
)
{
    data_stream.read_packet(stream, event.packet)

    type, type_err := data_stream.extract_message_type(stream)

    if type_err != .None
    {
        return
    }

    #partial switch type
    {
        case .LOGIN, .REGISTER:
            username, u_err := data_stream.extract_string(stream)
            
            if u_err != .None
            {
                return
            }

            password, p_err := data_stream.extract_string(stream)

            if p_err != .None
            {
                return
            }

            if type == .LOGIN
            {
                log.infof(
                    "Login packet with username '%v' and password '%v'.",
                    username,
                    password,
                )
            }
            else
            {
                log.infof(
                    "Register packet with username '%v' and password '%v'.",
                    username,
                    password,
                )
            }
    }

    teluria_call_custom_command(lua_state, cstring(event.packet.data))

    enet.packet_destroy(event.packet)
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

    server_info := server_info_make()
    defer server_info_destroy(&server_info)

    host, network_err := network_initialize(
        HOST_ADDRESS,
        HOST_PORT,
        HOST_PEER_COUNT,
        HOST_CHANNELS,
        HOST_INBOUND_BANDWIDTH,
        HOST_OUTBOUND_BANDWIDTH,
    )

    if network_err != .None
    {
        return
    }

    defer network_deinitialize(host)

    stream, stream_err := data_stream.create()

    if stream_err != .None
    {
        return
    }

    defer data_stream.destroy(&stream)

    lua_state := lua_engine_initialize()
    defer lua_engine_deinitialize(lua_state)

    lua_engine_setup_registry(lua_state, host, &stream)
    lua_engine_expose_builtin_api(lua_state)
    lua_engine_load_server(lua_state)

    log.info("Polling events...")

    event := enet.Event{}

    for
    {
        if enet.host_service(host, &event, HOST_POLL_TIMEOUT) < 0
        {
            log.error("Error while polling server events.")
            break
        }

        switch event.type
        {
            case .NONE:
                // Nothing should be done in this case
            case .CONNECT:
                log.info("Event captured: CONNECT")
                teluria_callback_on_connect(lua_state, event.peer.connectID)
            case .DISCONNECT:
                log.info("Event captured: DISCONNECT")
                teluria_callback_on_disconnect(lua_state, event.peer.connectID)
            case .RECEIVE:
                log.info("Event captured: RECEIVE")
                handle_packet(event, lua_state, &stream)
        }
    }
}
