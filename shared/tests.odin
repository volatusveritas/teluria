package shared

import "core:testing"

@(test)
test_writer_to_reader :: proc(t: ^testing.T)
{
    writer := network_writer_make()
    defer network_writer_destroy(writer)

    network_writer_set_type(&writer, .MESSAGE)

    assert(writer.offset == size_of(NetworkMessageType))

    message: string = "Something seems off..."

    network_writer_push_string(&writer, message)

    assert(writer.offset == (
        size_of(NetworkMessageType)
        + size_of(StringLengthType)
        + len(message)
    ))

    packet := network_writer_to_packet(&writer)

    assert(packet.dataLength == writer.offset)

    reader := NetworkReader {}

    network_reader_load_packet(&reader, packet)

    type, _ := network_reader_get_type(&reader)

    assert(type == .MESSAGE)

    read_str, _ := network_reader_read_string(&reader)

    assert(read_str == message)
}
