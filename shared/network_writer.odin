package shared

import enet "vendor:ENet"

MESSAGE_MAX_SIZE :: 4096

NetworkWriterErr :: enum
{
    None,
    BufferOverflow,
}

NetworkWriter :: struct
{
    buffer: []byte,
    offset: uint,
}

network_writer_make :: proc() -> NetworkWriter
{
    buffer := make([]byte, MESSAGE_MAX_SIZE)

    return NetworkWriter {
        buffer = buffer,
        offset = 0,
    }
}

network_writer_destroy :: proc(network_writer: NetworkWriter)
{
    delete(network_writer.buffer)
}

network_writer_reset :: proc(network_writer: ^NetworkWriter)
{
    network_writer.offset = 0
}

network_writer_get_next :: proc(network_writer: ^NetworkWriter) -> []byte
{
    return network_writer.buffer[network_writer.offset:]
}

network_writer_set_type :: proc(
    network_writer: ^NetworkWriter,
    type: NetworkMessageType,
)
{
    writer_data_ptr := raw_data(network_writer_get_next(network_writer))
    (^NetworkMessageType)(writer_data_ptr)^ = type

    network_writer.offset += size_of(NetworkMessageType)
}

@(private="file")
network_writer_push_string_length :: proc(
    network_writer: ^NetworkWriter,
    str: string,
)
{
    writer_data_ptr := raw_data(network_writer_get_next(network_writer))
    (^StringLengthType)(writer_data_ptr)^ = StringLengthType(len(str))

    network_writer.offset += size_of(StringLengthType)
}

network_writer_push_string :: proc(
    network_writer: ^NetworkWriter,
    str: string,
) -> NetworkWriterErr
{
    batch_size := uint(size_of(StringLengthType) + len(str))

    if network_writer.offset + batch_size >= MESSAGE_MAX_SIZE
    {
        return .BufferOverflow
    }

    network_writer_push_string_length(network_writer, str)

    copy(network_writer_get_next(network_writer), transmute([]byte)str)
    network_writer.offset += len(str)

    return .None
}

network_writer_push_cstring :: proc(
    network_writer: ^NetworkWriter,
    str: cstring,
) -> NetworkWriterErr
{
    return network_writer_push_string(network_writer, string(str))
}

network_writer_to_packet :: proc(
    network_writer: ^NetworkWriter,
) -> ^enet.Packet
{
    return enet.packet_create(
        raw_data(network_writer.buffer),
        network_writer.offset,
        // TODO: make this ".REALIBLE" a parameter
        .RELIABLE,
    )
}
