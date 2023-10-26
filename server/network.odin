package server

import "core:log"

import enet "vendor:ENet"

NetworkErr :: enum
{
    None,
    Initialize_ENet,
    Resolve_Address,
    Create_Host,
}

network_initialize :: proc(
    address: cstring,
    peer_count: uint,
    channel_limit: uint,
    incoming_bandwidth: u32,
    outgoing_bandwidth: u32,
) -> (host: ^enet.Host, err: NetworkErr)
{
    if enet.initialize() != 0
    {
        log.error("Could not initialize ENet.")
        err = .Initialize_ENet

        return
    }

    defer if err != .None
    {
        enet.deinitialize()
    }

    address := enet.Address{}

    if enet.address_set_host(&address, HOST_ADDRESS) != 0
    {
        log.error("Could not resolve the host address.")
        err = .Resolve_Address

        return
    }

    host = enet.host_create(
        &address,
        peer_count,
        channel_limit,
        incoming_bandwidth,
        outgoing_bandwidth,
    )

    if host == nil
    {
        log.error("Could not create the host.")
        err = .Create_Host

        return
    }

    log.info("Host successfully created.")
    log.info("ENet successfully initialized.")
    log.info("Server successfully initialized.")

    err = .None

    return
}

network_deinitialize :: proc(host: ^enet.Host)
{
    enet.host_destroy(host)
    enet.deinitialize()
}
