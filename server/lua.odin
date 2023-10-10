package server

import "core:fmt"

import lua "vendor:lua/5.4"
import enet "vendor:ENet"

lua_engine_initialize :: proc() -> ^lua.State
{
    state := lua.L_newstate()
    lua.L_openlibs(state)
    return state
}

lua_engine_deinitialize :: proc(state: ^lua.State)
{
    lua.close(state)
}

lua_engine_load_server :: proc(state: ^lua.State)
{
    result := lua.L_dofile(state, "scripts/init.lua")

    if result == 0 {
        return
    }

    fmt.eprintln("------- Lua errors BEGIN -------")
    fmt.eprintln(lua.tostring(state, -1))
    fmt.eprintln("-------  Lua errors END  -------")
}

lua_engine_setup_registry :: proc(
    state: ^lua.State,
    host: ^enet.Host,
)
{
    lua.pushinteger(state, lua.Integer(uintptr(host)))
    lua.setfield(state, lua.REGISTRYINDEX, "host")
}

@(private="file")
teluria_core_get_host :: proc "c" (state: ^lua.State) -> ^enet.Host
{
    lua.getfield(state, lua.REGISTRYINDEX, "host")
    host := (^enet.Host)(uintptr(lua.tointeger(state, lua.gettop(state))))
    lua.pop(state, 1)

    return host
}

@(private="file")
teluria_core_get_event :: proc "c" (state: ^lua.State) -> ^enet.Event
{
    lua.getfield(state, lua.REGISTRYINDEX, "event")
    event := (^enet.Event)(uintptr(lua.tointeger(state, lua.gettop(state))))
    lua.pop(state, 1)

    return event
}

@(private="file")
teluria_builtin_broadcast :: proc "c" (state: ^lua.State) -> i32
{
    host := teluria_core_get_host(state)
    message := lua.L_checkstring(state, 1)
    packet := enet.packet_create(rawptr(message), len(message), .RELIABLE)

    enet.host_broadcast(host, 0, packet)

    return 0
}

@(private="file")
teluria_builtin_send :: proc "c" (state: ^lua.State) -> i32
{
    peer_id := u32(lua.L_checkinteger(state, 1))
    message := lua.L_checkstring(state, 2)
    host := teluria_core_get_host(state)

    for i: uint = 0; i < host.peerCount; i += 1
    {
        if host.peers[i].connectID == peer_id
        {
            packet := enet.packet_create(
                rawptr(message),
                len(message),
                .RELIABLE,
            )

            // TODO: handle errors here
            enet.peer_send(&host.peers[i], 0, packet)

            break
        }
    }

    return 0
}

teluria_callback_on_connect :: proc(state: ^lua.State, peer_id: u32)
{
    lua.getglobal(state, "teluria")
    teluria_index := lua.gettop(state)
    lua.getfield(state, teluria_index, "on_connect")
    on_connect_index := lua.gettop(state)

    if lua.type(state, on_connect_index) == .FUNCTION
    {
        lua.pushinteger(state, lua.Integer(peer_id))
        lua.call(state, 1, 0)
        lua.pop(state, 1)
    }
    else
    {
        lua.pop(state, 2)
    }
}

teluria_callback_on_disconnect :: proc(state: ^lua.State, peer_id: u32)
{
    lua.getglobal(state, "teluria")
    teluria_index := lua.gettop(state)
    lua.getfield(state, teluria_index, "on_disconnect")
    on_disconnect_index := lua.gettop(state)

    if lua.type(state, on_disconnect_index) != .FUNCTION
    {
        lua.pop(state, 2)
        return
    }

    lua.pushinteger(state, lua.Integer(peer_id))
    lua.call(state, 1, 0)
    lua.pop(state, 1)
}

lua_engine_expose_builtin_api :: proc(state: ^lua.State)
{
    teluria_libfuncs := []lua.L_Reg {
        { "broadcast", teluria_builtin_broadcast },
        { "send", teluria_builtin_send },
        { nil, nil },
    }

    lua.L_newlib(state, teluria_libfuncs)
    lua.setglobal(state, "teluria")
}
