package client

import "core:mem"

import "vendor:miniaudio"

/*
EXPLANATION OF TERMS:

- Audio Engine: the underlying audio engine provided by Miniaudio.
- Sound Engine: Teluria's Sound Engine which supports polyphony.
- Sound Bank: a collection of sounds that can be playd polyphonically.
*/

MAXIMUM_SOUND_POLYPHONY : int : 16

SoundMap :: map[cstring]SoundBank

SoundBank :: struct
{
    sounds: []miniaudio.sound,
    next: int,
}

sound_bank_make :: proc() -> (SoundBank, bool)
{
    sounds, alloc_err := make([]miniaudio.sound, MAXIMUM_SOUND_POLYPHONY)

    if alloc_err != .None
    {
        return {}, false
    }

    return SoundBank{sounds, 0}, true
}

sound_bank_destroy :: proc(sb: ^SoundBank)
{
    delete(sb.sounds)
    sb.next = -1
}

sound_bank_play :: proc(sb: ^SoundBank) -> bool
{
    result: miniaudio.result

    result = miniaudio.sound_seek_to_pcm_frame(&sb.sounds[sb.next], 0)
    
    if result != .SUCCESS do return false

    result = miniaudio.sound_start(&sb.sounds[sb.next])

    if result != .SUCCESS do return false

    sb.next += 1
    if sb.next >= MAXIMUM_SOUND_POLYPHONY
    {
        sb.next = 0
    }

    return true
}

audio_engine_make :: proc() -> (^miniaudio.engine, bool)
{
    // ptr, alloc_err := mem.alloc(size_of(miniaudio.engine))
    ptr, alloc_err := new(miniaudio.engine)

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
    free(ae)
}

SoundEngine :: struct
{
    audio_engine: ^miniaudio.engine,
    sound_map: SoundMap,
}

sound_engine_register_sound :: proc(
    se: ^SoundEngine,
    key: cstring,
    path: cstring,
) -> bool
{
    sb, ok := sound_bank_make()

    if !ok do return false

    result: miniaudio.result

    result = miniaudio.sound_init_from_file(
        se.audio_engine, path, 0, nil, nil, &sb.sounds[0],
    )

    if result != .SUCCESS
    {
        sound_bank_destroy(&sb)
        return false
    }

    for i in 1..<MAXIMUM_SOUND_POLYPHONY
    {
        result = miniaudio.sound_init_copy(
            se.audio_engine, &sb.sounds[0], 0, nil, &sb.sounds[i],
        )

        if result != .SUCCESS
        {
            for idx in 0..<i do miniaudio.sound_uninit(&sb.sounds[idx])
            sound_bank_destroy(&sb)
            return false
        }
    }

    se.sound_map[key] = sb

    return true
}

sound_engine_remove_sound :: proc(se: ^SoundEngine, key: cstring)
{
    sb := se.sound_map[key]

    for i in 0..<MAXIMUM_SOUND_POLYPHONY
    {
        miniaudio.sound_uninit(&sb.sounds[i])
    }

    sound_bank_destroy(&sb)
    delete_key(&se.sound_map, key)
}

sound_engine_play :: proc(se: ^SoundEngine, key: cstring) -> bool
{
    return sound_bank_play(&se.sound_map[key])
}

sound_engine_make :: proc() -> (SoundEngine, bool)
{
    audio_engine, success := audio_engine_make()

    if !success do return {}, false

    sound_engine := SoundEngine {
        audio_engine,
        make(SoundMap),
    }

    return sound_engine, true
}

sound_engine_destroy :: proc(se: ^SoundEngine)
{
    for key in se.sound_map do sound_engine_remove_sound(se, key)

    delete(se.sound_map)

    audio_engine_destroy(se.audio_engine)
}
