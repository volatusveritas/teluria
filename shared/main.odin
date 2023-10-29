package shared

import "core:fmt"

import enet "vendor:ENet"

main :: proc()
{
    nw := network_writer_make()
    defer network_writer_destroy(nw)

    network_writer_push_string(&nw, "Away the beast goes")
    network_writer_push_string(&nw, "Within the beast hides")

    packet := network_writer_to_packet(&nw)
    defer enet.packet_destroy(packet)

    // --------------------------

    nr := network_reader_make(packet)

    str1, err1 := network_reader_read_string(&nr)

    if err1 != .None
    {
        fmt.println("Error while processing str1")
    }

    str2, err2 := network_reader_read_string(&nr)

    if err2 != .None
    {
        fmt.println("Error while processing str2")
    }

    fmt.printf("str1 = %v\n", str1)
    fmt.printf("str2 = %v\n", str2)
}
