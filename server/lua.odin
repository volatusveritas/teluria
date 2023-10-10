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
    return 0
}

teluria_callback_on_connect :: proc(state: ^lua.State)
{
    // Push the teluria global to the stack
    lua.getglobal(state, "teluria")
    // Get teluria's index
    teluria_index := lua.gettop(state)
    // Push teluria.on_connect to the stack
    lua.getfield(state, teluria_index, "on_connect")
    // Get teluria.on_connect's index
    on_connect_index := lua.gettop(state)

    // Check if there is a function there
    if lua.type(state, on_connect_index) == .FUNCTION
    {
        // Call teluria.on_connect (pops the function)
        lua.call(state, 0, 0)
        // Pop the teluria global from the stack
        lua.pop(state, 1)
    }
    else
    {
        // Pop the nil value and the teluria global
        lua.pop(state, 2)
    }
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
