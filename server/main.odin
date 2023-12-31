package server

import "core:fmt"
import "core:strings"

import enet "vendor:ENet"

main :: proc()
{
    if enet.initialize() != 0
    {
        fmt.println("Could not initialize ENet.")
        return
    }

    fmt.println("ENet successfully initialized.")
    defer enet.deinitialize()

    address := enet.Address{}

    if enet.address_set_host(&address, "127.0.0.1") != 0
    {
        fmt.println("Could not resolve the host address.")
        return
    }

    address.port = 25565

    host := enet.host_create(&address, 32, 2, 0, 0)

    if host == nil
    {
        fmt.println("Could not create the host.")
        return
    }

    fmt.println("Host successfully created.")
    defer enet.host_destroy(host)

    fmt.println("Server successfully initialized.")

    event := enet.Event{}

    fmt.println("Polling events...")
    for enet.host_service(host, &event, 200) >= 0
    {
        switch event.type
        {
            case .NONE:

            case .CONNECT:
                fmt.println("Event received: CONNECT")
            case .DISCONNECT:
                fmt.println("Event received: DISCONNECT")
            case .RECEIVE:
                fmt.println("Event received: RECEIVE")

                pk_text := strings.string_from_ptr(
                    event.packet.data,
                    int(event.packet.dataLength),
                )

                fmt.printf(
                    "Packet of size %v received, contents:\n%v\n",
                    len(pk_text),
                    pk_text,
                )

                response: cstring = "THE SERVER SAYS THIS"

                pkt := enet.packet_create(
                    rawptr(response),
                    uint(len(response)),
                    .RELIABLE,
                )

                enet.peer_send(event.peer, 0, pkt)

                enet.packet_destroy(event.packet)
        }
    }

    fmt.println("Error while polling server events.")
}
