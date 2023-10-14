package client

// Doesn't work for some reason if I have this on
import "core:mem"

PromptStep :: #type proc(
    rawptr,
    string,
    ^Monitor,
    ^LineInput,
    ^Network,
) -> bool

PromptDoneCallback :: #type proc(rawptr, ^Monitor, ^Network)

Prompt :: struct
{
    data: rawptr,
    messages: [dynamic]cstring,
    steps: [dynamic]PromptStep,
    done_callback: PromptDoneCallback,
    destroy_callback: #type proc(rawptr),
    next_step: int,
}

prompt_make :: proc(
    data: rawptr,
    done_callback: PromptDoneCallback,
    destroy_callback: #type proc(rawptr),
) -> ^Prompt
{
    // TODO: handle the error here
    prompt_ptr, _ := new(Prompt)
    prompt := (^Prompt)(prompt_ptr)

    prompt.data = data
    prompt.messages = make([dynamic]cstring)
    prompt.steps = make([dynamic]PromptStep)
    prompt.done_callback = done_callback
    prompt.destroy_callback = destroy_callback
    prompt.next_step = 0

    return prompt
}

prompt_destroy :: proc(prompt: ^Prompt)
{
    delete(prompt.messages)
    delete(prompt.steps)

    // mem.free(prompt.data)
    prompt.destroy_callback(prompt.data)

    mem.free(prompt)
}

prompt_add_step :: proc(prompt: ^Prompt, message: cstring, step: PromptStep)
{
    append(&prompt.messages, message)
    append(&prompt.steps, step)
}

prompt_process_start :: proc(prompt: ^Prompt, monitor: ^Monitor)
{
    monitor_append_line(monitor, prompt.messages[0])
}

prompt_process_step :: proc(
    prompt: ^Prompt,
    input: string,
    monitor: ^Monitor,
    line_input: ^LineInput,
    network: ^Network,
) -> bool
{
    result := prompt.steps[prompt.next_step](
        prompt.data,
        input,
        monitor,
        line_input,
        network,
    )

    delete(input)

    if prompt.next_step == len(prompt.steps) - 1
    {
        prompt.done_callback(prompt.data, monitor, network)
        return false
    }
    else if result
    {
        monitor_append_line(monitor, prompt.messages[prompt.next_step + 1])
    }

    prompt.next_step += 1

    return result
}
