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
teluria_builtin_broadcast :: proc "c" (state: ^lua.State) -> i32
{
    host := teluria_core_get_host(state)

    message: cstring = "This message was broadcasted."
    packet := enet.packet_create(rawptr(message), len(message), .RELIABLE)

    enet.host_broadcast(host, 0, packet)

    return 0
}

@(private="file")
teluria_builtin_send :: proc "c" (state: ^lua.State) -> i32
{
    return 0
}

@(private="file")
teluria_builtin_on_connect :: proc "c" (state: ^lua.State) -> i32
{
    return 0
}

lua_engine_expose_builtin_api :: proc(state: ^lua.State)
{
    // lua_CFunction :: proc(^lua.State) -> int
    // lua_setfield(state, idx_of_t, k)  ->  t[k] = top_of_stack
    // lua_setglobal(state, name)  ->  pop top and set to name as global
    // lua_gettop(state)  ->  index of top

    teluria_libfuncs := []lua.L_Reg {
        { "broadcast", teluria_builtin_broadcast },
        { "send", teluria_builtin_send },
        { "on_connect", teluria_builtin_on_connect },
        { nil, nil },
    }

    lua.L_newlib(state, teluria_libfuncs)
    lua.setglobal(state, "teluria")
}
