package client

import "vendor:raylib"
import "core:fmt"

MONITOR_HEIGHT : i32 : SCREEN_HEIGHT - 3 * PADDING - LINE_INPUT_HEIGHT
MONITOR_WIDTH  : i32 : SCREEN_WIDTH - 2 * PADDING
MONITOR_X      : i32 : PADDING
MONITOR_Y      : i32 : PADDING
MONITOR_ROUND  : f32 : 16.0
MONITOR_RADIUS : f32 : MONITOR_ROUND / f32(MONITOR_HEIGHT)
MONITOR_SEGS   : i32 : 16
MONITOR_LINES  : int : int(MONITOR_HEIGHT / FONT_SIZE)

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

monitor_destroy :: proc(monitor: Monitor)
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
    monitor: ^Monitor,
    line: cstring,
    color: raylib.Color = COLOR_TEXT,
)
{
    append(&monitor.lines, line)
    append(&monitor.colors, color)
}

monitor_append_allocated_line :: proc(
    monitor: ^Monitor,
    line: cstring,
    color: raylib.Color = COLOR_TEXT,
)
{
    append(&monitor.allocated_lines, line)
    append(&monitor.lines, line)
    append(&monitor.colors, color)
}

monitor_draw :: proc(monitor: Monitor, font: raylib.Font)
{
    raylib.DrawRectangleRounded(
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

    start := max(len(monitor.lines) - MONITOR_LINES, 0)

    for i in start..<len(monitor.lines)
    {
        raylib.DrawTextEx(
            font,
            monitor.lines[i],
            {
                f32(MONITOR_X + TEXT_PADDING),
                f32(MONITOR_Y + TEXT_PADDING + i32(i - start) * FONT_SIZE),
            },
            f32(FONT_SIZE),
            FONT_SPACING,
            monitor.colors[i],
        )
    }
}
