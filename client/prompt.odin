package client

PromptStep :: #type proc(
    rawptr,
    string,
    ^Monitor,
    ^LineInput,
    ^Network,
) -> bool

PromptDoneCallback :: #type proc(rawptr, ^Monitor, ^Network, ^ClientInfo)
PromptDestroyCallback :: #type proc(rawptr)

Prompt :: struct
{
    active: bool,
    data: rawptr,
    destroy_callback: PromptDestroyCallback,
    done_callback: PromptDoneCallback,
    messages: [dynamic]cstring,
    next_step: int,
    steps: [dynamic]PromptStep,
}

prompt_make :: proc() -> Prompt
{
    return Prompt {
        active = false,
        data = nil,
        destroy_callback = nil,
        done_callback = nil,
        messages = make([dynamic]cstring),
        next_step = 0,
        steps = make([dynamic]PromptStep),
    }
}

prompt_reset :: proc(prompt: ^Prompt)
{
    if prompt.destroy_callback != nil
    {
        prompt.destroy_callback(prompt.data)
    }

    clear(&prompt.messages)
    clear(&prompt.steps)
}

prompt_destroy :: proc(prompt: Prompt)
{
    delete(prompt.messages)
    delete(prompt.steps)
}

prompt_setup :: proc(prompt: ^Prompt, data: rawptr)
{
    prompt.active = true
    prompt.data = data
    prompt.destroy_callback = nil
    prompt.done_callback = nil
    clear(&prompt.messages)
    prompt.next_step = 0
    clear(&prompt.steps)
}

prompt_add_step :: proc(prompt: ^Prompt, message: cstring, step: PromptStep)
{
    append(&prompt.messages, message)
    append(&prompt.steps, step)
}

prompt_process_start :: proc(prompt: Prompt, monitor: ^Monitor)
{
    monitor_append_line(monitor, prompt.messages[0])
}

prompt_process_step :: proc(
    prompt: ^Prompt,
    input: string,
    monitor: ^Monitor,
    line_input: ^LineInput,
    network: ^Network,
    client_info: ^ClientInfo,
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
        prompt.done_callback(prompt.data, monitor, network, client_info)
        return false
    }
    else if result
    {
        monitor_append_line(monitor, prompt.messages[prompt.next_step + 1])
    }

    prompt.next_step += 1

    return result
}
