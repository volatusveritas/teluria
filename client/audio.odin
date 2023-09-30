package client

import "core:mem"

import "vendor:miniaudio"

MAXIMUM_SOUND_POLIPHONY : int : 16

SoundMap :: map[cstring](^[MAXIMUM_SOUND_POLIPHONY]miniaudio.sound)

audio_engine_make :: proc() -> (^miniaudio.engine, bool)
{
    ptr, alloc_err := mem.alloc(size_of(miniaudio.engine))

    if alloc_err != .None
    {
        return nil, false
    }

    ae := (^miniaudio.engine)(ptr)
    config := miniaudio.engine_config_init()

    if miniaudio.engine_init(&config, ae) != .SUCCESS
    {
        mem.free(ae)
        return nil, false
    }

    return ae, true
}

audio_engine_destroy :: proc(ae: ^miniaudio.engine)
{
    miniaudio.engine_uninit(ae)
}

SoundEngine :: struct
{
    audio_engine: ^miniaudio.engine,
    sound_map: SoundMap,
}

sound_engine_register_sound :: proc(
    se: ^SoundEngine,
    key: cstring,
    path: cstring
) -> bool
{
    ptr, alloc_err := mem.alloc(
        size_of(miniaudio.sound) * MAXIMUM_SOUND_POLIPHONY
    )

    if alloc_err != .None do return false

    sound_arr := (^[MAXIMUM_SOUND_POLIPHONY]miniaudio.sound)(ptr)

    result: miniaudio.result

    result = miniaudio.sound_init_from_file(
        se.audio_engine, path, 0, nil, nil, &sound_arr[0]
    )

    if result != .SUCCESS
    {
        free(ptr)
        return false
    }

    for i in 1..<MAXIMUM_SOUND_POLIPHONY
    {
        result = miniaudio.sound_init_copy(
            se.audio_engine, &sound_arr[0], 0, nil, &sound_arr[i]
        )

        if result != .SUCCESS
        {
            for idx in 0..<i do miniaudio.sound_uninit(&sound_arr[idx])
            free(ptr)

            return false
        }
    }

    se.sound_map[key] = sound_arr

    return true
}

sound_engine_remove_sound :: proc(se: ^SoundEngine, key: cstring)
{
    sound_arr := se.sound_map[key]

    for i in 0..<MAXIMUM_SOUND_POLIPHONY
    {
        miniaudio.sound_uninit(&sound_arr[i])
    }

    free(sound_arr)

    delete_key(&se.sound_map, key)
}

sound_engine_make :: proc() -> (SoundEngine, bool)
{
    audio_engine, success := audio_engine_make()

    if !success do return {}, false

    sound_engine := SoundEngine {
        audio_engine,
        make(SoundMap)
    }

    return sound_engine, true
}

sound_engine_destroy :: proc(se: ^SoundEngine)
{
    for key in se.sound_map do sound_engine_remove_sound(se, key)

    delete(se.sound_map)

    audio_engine_destroy(se.audio_engine)
}
