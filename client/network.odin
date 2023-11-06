package client

import enet "vendor:ENet"

import "../data_stream"

NETWORK_SERVER_CHANNEL : u8 : 0
CONNECTION_PEERS : uint : 1
CONNECTION_CHANNELS : uint : 2
CONNECTION_BANDWIDTH_IN : u32 = 0
CONNECTION_BANDWIDTH_OUT : u32 = 0

NetworkErr :: enum
{
    NONE,
    INITIALIZE,
    CREATE_HOST,
    ALLOCATE_STREAM,
}

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
    stream: data_stream.Stream,
}

network_make :: proc() -> (network: Network, err: NetworkErr)
{
    if enet.initialize() < 0
    {
        return {}, .INITIALIZE
    }

    defer if err != .NONE
    {
        enet.deinitialize()
    }

    host := enet.host_create(
        nil,
        CONNECTION_PEERS,
        CONNECTION_CHANNELS,
        CONNECTION_BANDWIDTH_IN,
        CONNECTION_BANDWIDTH_OUT,
    )

    if host == nil
    {
        err = .CREATE_HOST
        return
    }

    defer if err != .NONE
    {
        enet.host_destroy(host)
    }

    stream, stream_err := data_stream.create()

    if stream_err != .None
    {
        err = .ALLOCATE_STREAM
        return
    }

    network = Network {
        client = host,
        connection_time = 0.0,
        event = {},
        peer = nil,
        status = .STALLED,
        stream = stream,
    }

    return network, .NONE
}

network_destroy :: proc(network: ^Network)
{
    enet.deinitialize()
    enet.host_destroy(network.client)

    data_stream.destroy(&network.stream)
}

network_poll :: proc(network: ^Network) -> NetworkPollErr
{
    if network.status == .STALLED
    {
        return NetworkPollErr.NO_EVENT
    }

    result := enet.host_service(network.client, &network.event, 0)

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

net_client_connect :: proc(
    c: ^enet.Host,
    host: cstring,
    port: u16,
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
