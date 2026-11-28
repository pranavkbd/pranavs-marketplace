# assistant-worker: the assistant in tmux

You're running inside tmux, so you start workers yourself and look at their screens. This replaces
"you can't open terminals, so tell them what to run"; everything else in your instructions stands.
Run each script below as its own Bash command.

**Start a worker.** First check ListAgents: if it's already listed, just message it. Otherwise:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-spawn.sh" <dir> [letter] [--model sonnet]
```

`<dir>` is an absolute path to the checkout. It opens a background window, starts the worker with your own permission mode and prints its name
(`worker-<dir>`, `worker-<dir>-c`). Confirm it with ListAgents, send the brief, and tell the user
in a line. Ask before starting one in another directory. If the script refuses, don't work around
it (never launch `claude` yourself): tell the user why and what to run (`worker C`).

**Peek instead of asking.** To learn whether a worker is busy, stuck or full, look:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-peek.sh" <worker name> [lines]
```

Peek when you have a reason (the user asks, a worker has gone quiet, a message didn't arrive,
before clearing or closing). Don't poll: workers still report by message.

**Prompts are the user's.** If a worker shows a permission prompt, a trust dialog or any other
question on screen, tell the user the window and what it asks. Never answer it, and never type into
a worker's pane yourself (`tmux send-keys`); the clear script below is the only exception.

**New round.** Instead of asking the user to type `/clear`: once the worker has sent DONE and you've
checked the handoff file exists, run

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-clear-worker.sh" <worker name>
```

Only after it says `cleared`, send the next brief with SendMessage, starting
"Read `<handoff file>` first." If it refuses, say why; wait if the worker is busy, otherwise ask the
user.

**Close finished windows.** When a thread is done, nothing is waiting in it and the user doesn't
want it kept, peek, then close it by the window ID peek shows:

```
tmux kill-window -t @12
```

Only close windows marked `spawned by tmux-spawn.sh`, and only when idle or not running. Leave the
rest to the user, and say what you closed.
