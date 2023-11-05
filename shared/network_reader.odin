package shared

import "core:slice"
import "core:strings"
import "core:log"

import enet "vendor:ENet"

NetworkReaderErr :: enum
{
    None,
    MissingData,
}

NetworkReader :: struct
{
    data: []byte,
    offset: uint,
}

network_reader_load_packet ::proc(
    network_reader: ^NetworkReader,
    packet: ^enet.Packet,
)
{
    network_reader.data = slice.from_ptr(packet.data, int(packet.dataLength))
    network_reader.offset = 0
}

network_reader_get_next :: proc(network_reader: ^NetworkReader) -> []byte
{
    return network_reader.data[network_reader.offset:]
}

network_reader_get_type :: proc(
    network_reader: ^NetworkReader,
) -> (NetworkMessageType, NetworkReaderErr)
{
    if (
        network_reader.offset + size_of(NetworkMessageType)
        > len(network_reader.data)
    )
    {
        log.error("Not enough data to extract the message's type.")
        return nil, .MissingData
    }

    type := (^NetworkMessageType)(
        raw_data(network_reader_get_next(network_reader)),
    )^

    network_reader.offset += size_of(NetworkMessageType)

    return type, .None
}

@(private="file")
network_reader_read_string_length :: proc(
    network_reader: ^NetworkReader,
) -> (StringLengthType, NetworkReaderErr)
{
    if (
        network_reader.offset + size_of(StringLengthType)
        > len(network_reader.data)
    )
    {
        return 0, .MissingData
    }

    length := (^StringLengthType)(
        raw_data(network_reader_get_next(network_reader)),
    )^

    network_reader.offset += size_of(StringLengthType)

    return length, .None
}

network_reader_read_string :: proc(
    network_reader: ^NetworkReader,
) -> (str: string, err: NetworkReaderErr)
{
    length := network_reader_read_string_length(network_reader) or_return

    if network_reader.offset + uint(length) > len(network_reader.data)
    {
        return "", .MissingData
    }

    str = strings.string_from_ptr(
        raw_data(network_reader_get_next(network_reader)),
        int(length),
    )

    network_reader.offset += uint(length)

    err = .None

    return
}
