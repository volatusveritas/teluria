package server

import "core:log"

import enet "vendor:ENet"
import lua "vendor:lua/5.4"

HOST_POLL_TIMEOUT :: 200
HOST_ADDRESS :: "127.0.0.1"
HOST_PORT :: 25565
HOST_PEER_COUNT :: 32
HOST_CHANNELS :: 2
HOST_INBOUND_BANDWIDTH :: 0
HOST_OUTBOUND_BANDWIDTH :: 0

handle_packet :: proc(event: enet.Event, lua_state: ^lua.State)
{
    teluria_call_custom_command(lua_state, cstring(event.packet.data))

    enet.packet_destroy(event.packet)
}

main :: proc()
{
    console_logger := log.create_console_logger(
        opt=log.Options{.Level} | log.Full_Timestamp_Opts,
    )

    defer log.destroy_console_logger(console_logger)

    context.logger = console_logger

    host, network_err := network_initialize(
        HOST_ADDRESS,
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

    lua_state := lua_engine_initialize()
    defer lua_engine_deinitialize(lua_state)

    lua_engine_setup_registry(lua_state, host)
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
                handle_packet(event, lua_state)
        }
    }
}
