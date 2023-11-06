package data_stream

import "core:testing"

@(test)
test_insert_size :: proc(t: ^testing.T)
{
    stream, _ := create()
    defer destroy(&stream)

    message_type := MessageType.LOGIN
    username := "Username"
    password := "Password"

    insert_message_type(&stream, message_type)
    insert_string(&stream, username)
    insert_string(&stream, password)

    packet := to_packet(&stream)

    assert(packet.dataLength == (
        size_of(message_type)
        + size_of(StringLength) + len(username)
        + size_of(StringLength) + len(password)
    ))
}

@(test)
test_extract :: proc(t: ^testing.T)
{
    username := "Username"
    password := "Password"

    expected_length := (
        + size_of(StringLength) + len(username)
        + size_of(StringLength) + len(password)
    )

    buf := make([]byte, expected_length)
    defer delete(buf)

    stream := Stream {
        buffer = buf,
        offset = 0,
    }

    (^StringLength)(raw_data(stream.buffer[stream.offset:]))^ = (
        StringLength(len(username))
    )

    stream.offset += size_of(StringLength)

    copy(stream.buffer[stream.offset:], transmute([]u8)username)
    stream.offset += len(username)

    (^StringLength)(raw_data(stream.buffer[stream.offset:]))^ = (
        StringLength(len(password))
    )

    stream.offset += size_of(StringLength)

    copy(stream.buffer[stream.offset:], transmute([]u8)password)
    stream.offset += len(password)
}
