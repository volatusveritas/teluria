package client

import "core:strings"
import "core:strconv"

Command :: struct
{
    source: string,
    anchor: int,
}

command_make :: proc(source: string) -> Command
{
    return Command{source, 0}
}

command_has_next :: proc(c: ^Command) -> bool
{
    return c.anchor != -1
}

command_get_next :: proc(c: ^Command) -> string
{
    if end_idx := strings.index_byte(c.source[c.anchor:], ' '); end_idx != -1
    {
        str := c.source[c.anchor:][:end_idx]
        c.anchor += end_idx + 1
        return str
    }

    str := c.source[c.anchor:]
    c.anchor = -1
    return str
}

command_get_string :: command_get_next

command_get_u16 :: proc(c: ^Command) -> (u16, bool)
{
    n, ok := strconv.parse_uint(command_get_next(c))

    if !ok || n > uint(max(u16))
    {
        return 0, false
    }

    return u16(n), true
}
