package server

import "core:fmt"
import "core:log"
import "core:mem"
import "core:time"

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

AUTHENTICATION_THRESHOLD_SECONDS :: 5.0

// TODO: GL32 error
// Probably wrong pointer assignment, getting it from OpenGL debuggin info,
// Doesn't happen in release versions

UserAuthenticationInfo :: struct
{
    peer: ^enet.Peer,
    attempt_start: time.Time,
}

UserInfo :: struct
{
    peer: ^enet.Peer,
}

ServerInfo :: struct
{
    user_credentials: map[string]string,
    // TODO: name this better
    authentication_map: map[u32]UserAuthenticationInfo,
    user_map: map[u32]UserInfo,
}

server_info_make :: proc() -> ServerInfo
{
    return ServerInfo {
        user_credentials = make(map[string]string),
        authentication_map = make(map[u32]UserAuthenticationInfo),
        user_map = make(map[u32]UserInfo),
    }
}

server_info_destroy :: proc(server_info: ^ServerInfo)
{
    delete(server_info.user_credentials)
    delete(server_info.authentication_map)
    delete(server_info.user_map)
}

handle_packet :: proc(
    server_info: ^ServerInfo,
    event: enet.Event,
    lua_state: ^lua.State,
    stream: ^data_stream.Stream,
)
{
    defer enet.packet_destroy(event.packet)

    data_stream.read_packet(stream, event.packet)

    type, type_err := data_stream.extract_message_type(stream)

    if type_err != .None
    {
        return
    }

    if type == .MESSAGE
    {
        teluria_call_custom_command(lua_state, cstring(event.packet.data))
        return
    }

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

        account_password, ok := server_info.user_credentials[username]

        if !ok || account_password != password {
            if event.peer.connectID not_in server_info.authentication_map
            {
                server_info.authentication_map[event.peer.connectID] = {
                    peer = event.peer,
                    attempt_start = time.now(),
                }
            }

            return
        }

        delete_key(&server_info.authentication_map, event.peer.connectID)

        // TODO: fill in initial data
        server_info.user_map[event.peer.connectID] = {
            peer = event.peer,
        }

        teluria_callback_on_connect(lua_state, event.peer.connectID)
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

authentication_step :: proc(server_info: ^ServerInfo)
{
    for _, auth_info in server_info.authentication_map
    {
        elapsed_time := time.duration_seconds(
            time.since(auth_info.attempt_start),
        )

        if elapsed_time >= AUTHENTICATION_THRESHOLD_SECONDS
        {
            // TODO: give the user a nice message explaining why they're an
            // idiot

            enet.peer_reset(auth_info.peer)
        }
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

    // @DELETE_LATER
    server_info.user_credentials["Volatus"] = "pass"
    // @DELETE_LATER

    for
    {
        if enet.host_service(host, &event, HOST_POLL_TIMEOUT) < 0
        {
            log.error("Error while polling server events.")
            break
        }

        authentication_step(&server_info)

        switch event.type
        {
            case .NONE:
                // Nothing should be done in this case
            case .CONNECT:
                log.info("Event captured: CONNECT")
            case .DISCONNECT:
                log.info("Event captured: DISCONNECT")
                teluria_callback_on_disconnect(lua_state, event.peer.connectID)
            case .RECEIVE:
                log.info("Event captured: RECEIVE")
                handle_packet(&server_info, event, lua_state, &stream)
        }
    }
}
