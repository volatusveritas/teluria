package client

import enet "vendor:ENet"

CONNECTION_PEERS : uint : 1
CONNECTION_CHANNELS : uint : 2
CONNECTION_BANDWIDTH_IN : u32 = 0
CONNECTION_BANDWIDTH_OUT : u32 = 0

NetworkPollErr :: enum
{
    EVENT,
    NO_EVENT,
    FAILURE,
}

NetworkStatus :: enum
{
    STALLED,
    CONNECTING,
    CONNECTED,
}

Network :: struct
{
    client: ^enet.Host,
    connection_time: f32,
    event: enet.Event,
    peer: ^enet.Peer,
    status: NetworkStatus,
}

network_poll :: proc(n: ^Network) -> NetworkPollErr
{
    if n.status == .STALLED
    {
        return NetworkPollErr.NO_EVENT
    }

    result := enet.host_service(n.client, &n.event, 0)

    if result > 0
    {
        return NetworkPollErr.EVENT
    }
    else if result == 0
    {
        return NetworkPollErr.NO_EVENT
    }
    else
    {
        return NetworkPollErr.FAILURE
    }
}

NetErr :: enum
{
    SUCCESS,
    RESOLVE_HOST,
    ATTEMPT_CONNECTION,
}

net_make :: proc() -> bool
{
    return enet.initialize() == 0
}

net_destroy :: proc()
{
    enet.deinitialize()
}

net_client_make :: proc() -> ^enet.Host
{
    return enet.host_create(
        nil,
        CONNECTION_PEERS,
        CONNECTION_CHANNELS,
        CONNECTION_BANDWIDTH_IN,
        CONNECTION_BANDWIDTH_OUT
    )
}

net_client_destroy :: proc(c: ^enet.Host)
{
    enet.host_destroy(c)
}

net_client_connect :: proc(
    c: ^enet.Host,
    host: cstring,
    port: u16
) -> (^enet.Peer, NetErr)
{
    address: enet.Address = { 0, port }

    if enet.address_set_host(&address, host) != 0
    {
        return nil, NetErr.RESOLVE_HOST
    }

    peer := enet.host_connect(c, &address, CONNECTION_CHANNELS, 0)

    if peer == nil
    {
        return nil, NetErr.ATTEMPT_CONNECTION
    }

    return peer, NetErr.SUCCESS
}
