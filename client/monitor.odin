package client

import "vendor:raylib"

MONITOR_HEIGHT : i32 : SCREEN_HEIGHT - 3 * PADDING - LINE_INPUT_HEIGHT
MONITOR_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
MONITOR_X      : i32 : PADDING
MONITOR_Y      : i32 : PADDING
MONITOR_ROUND  : f32 : 16.0
MONITOR_RADIUS : f32 : MONITOR_ROUND / f32(MONITOR_HEIGHT)
MONITOR_SEGS   : i32 : 16

Monitor :: struct
{
    lines: [dynamic]cstring,
    allocated_lines: [dynamic]cstring,
    colors: [dynamic]raylib.Color,
    exit: bool,
}

monitor_make :: proc() -> Monitor
{
    return Monitor {
        lines = {},
        allocated_lines = {},
        colors = {},
        exit = false,
    }
}

monitor_destroy :: proc(monitor: ^Monitor)
{
    for line in monitor.allocated_lines
    {
        delete(line)
    }

    delete(monitor.lines)
    delete(monitor.allocated_lines)
    delete(monitor.colors)
}

monitor_append_line :: proc(
    m: ^Monitor,
    line: cstring,
    color: raylib.Color = COLOR_TEXT,
)
{
    append(&m.lines, line)
    append(&m.colors, color)
}

monitor_append_allocated_line :: proc(
    m: ^Monitor,
    line: cstring,
    color: raylib.Color = COLOR_TEXT,
)
{
    append(&m.allocated_lines, line)
    append(&m.colors, color)
}

monitor_draw :: proc(m: ^Monitor, font: raylib.Font)
{
    using raylib

    DrawRectangleRounded(
        {
            f32(MONITOR_X),
            f32(MONITOR_Y),
            f32(MONITOR_WIDTH),
            f32(MONITOR_HEIGHT),
        },
        MONITOR_RADIUS,
        MONITOR_SEGS,
        COLOR_TEXTBOX,
    )

    for i in 0..<len(m.lines)
    {
        DrawTextEx(
            font,
            m.lines[i],
            {
                f32(MONITOR_X + TEXT_PADDING),
                f32(MONITOR_Y + TEXT_PADDING + i32(i) * FONT_SIZE),
            },
            f32(FONT_SIZE),
            FONT_SPACING,
            m.colors[i],
        )
    }
}
