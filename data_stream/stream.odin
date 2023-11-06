package data_stream

import "core:runtime"
import "core:slice"
import "core:strings"

import enet "vendor:ENet"

STREAM_MAX_SIZE :: 4096

StringLength :: u32le

MessageType :: enum u32le
{
    LOGIN,
    REGISTER,
    MESSAGE,
}

Stream :: struct
{
    data: []byte,
    buffer: []byte,
    offset: uint,
}

InsertErr :: enum
{
    None,
    BufferOverflow,
}

ExtractErr :: enum
{
    None,
    MissingData,
}

create :: proc() -> (stream: Stream, err: runtime.Allocator_Error)
{
    buffer := make([]byte, STREAM_MAX_SIZE) or_return

    stream = Stream {
        data = nil,
        buffer = buffer,
        offset = 0,
    }

    return
}

destroy :: proc(stream: ^Stream)
{
    delete(stream.buffer)
}

reset :: proc(stream: ^Stream)
{
    stream.offset = 0
}

insert_message_type :: proc(stream: ^Stream, type: MessageType)
{
    data_ptr := raw_data(stream.buffer[stream.offset:])
    (^MessageType)(data_ptr)^ = type

    stream.offset += size_of(MessageType)
}

extract_message_type :: proc(stream: ^Stream) -> (MessageType, ExtractErr)
{
    if stream.offset + size_of(MessageType) > len(stream.data)
    {
        return nil, .MissingData
    }

    type := (^MessageType)(raw_data(stream.data[stream.offset:]))^

    stream.offset += size_of(MessageType)

    return type, .None
}

@(private="file")
insert_string_length :: proc(stream: ^Stream, length: int)
{
    data_ptr := raw_data(stream.buffer[stream.offset:])
    (^StringLength)(data_ptr)^ = StringLength(length)

    stream.offset += size_of(StringLength)
}

@(private="file")
extract_string_length :: proc(stream: ^Stream) -> (StringLength, ExtractErr)
{
    if stream.offset + size_of(StringLength) > len(stream.data)
    {
        return 0, .MissingData
    }

    length := (^StringLength)(raw_data(stream.data[stream.offset:]))^

    stream.offset += size_of(StringLength)

    return length, .None
}

insert_string :: proc(stream: ^Stream, str: string) -> InsertErr
{
    storage_size := size_of(StringLength) + len(str)

    if int(stream.offset) + storage_size > len(stream.buffer)
    {
        return .BufferOverflow
    }

    insert_string_length(stream, len(str))

    copy(stream.buffer[stream.offset:], transmute([]byte)str)

    stream.offset += len(str)

    return .None
}

extract_string :: proc(stream: ^Stream) -> (str: string, err: ExtractErr)
{
    length := extract_string_length(stream) or_return

    if stream.offset + uint(length) > len(stream.data)
    {
        err = .MissingData
        return
    }

    str = strings.string_from_ptr(
        raw_data(stream.data[stream.offset:]),
        int(length),
    )

    stream.offset += uint(length)

    err = .None
    return
}

insert_cstring :: proc(stream: ^Stream, cstr: cstring) -> InsertErr
{
    return insert_string(stream, string(cstr))
}

to_packet :: proc(stream: ^Stream) -> ^enet.Packet
{
    return enet.packet_create(
        raw_data(stream.buffer),
        stream.offset,
        .RELIABLE,
    )
}

read_packet ::proc(stream: ^Stream, packet: ^enet.Packet)
{
    reset(stream)

    stream.data = slice.from_ptr(packet.data, int(packet.dataLength))
}
