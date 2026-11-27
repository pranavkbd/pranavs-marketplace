---
name: clear-yourself
description: Use when the user tells you to "clear yourself" (or "clear your context", "start fresh", "hand off and clear"). Pushes back if you are in the middle of something; otherwise writes or updates a handoff document so that, after the user types /clear, the fresh session reads it and carries on.
---

# Clear yourself

The user wants this session cleared so you continue with a fresh, small context. Done right it
is seamless for them: you write a handoff, they type `/clear`, and the new you picks up exactly
where you left off. Three steps, in order.

## 1. Decide whether now is a good time

Say **not now** and stop, without writing anything, if any of these is true:

- A subagent, background command, or other task you started is still running, or you are
  waiting on its result or notification.
- You are part way through a change: files half edited, tests not yet run on what you changed,
  a migration or command sequence partly done.
- You asked the user a question in this turn that is still open, or you are waiting for another
  session (a worker or the assistant) to reply.

Say what you're waiting on and when it would make sense, for example: "Not yet: the test run and
the browser subagent are still going. I'll be ready to clear once they report back." Then carry
on. Only proceed when the user insists after hearing why; if they do, record the unfinished state
precisely in the handoff.

## 2. Write or update the handoff

**Where:** several sessions can share a repo, so never write to a handoff another session owns.
In order:

1. A file the user or the assistant named for you (a worker's `.local/handoff-c.md`, say).
2. This session's own handoff: if this session started from one (the start of your context
   names it), update that same file.
3. Otherwise a new file, `.local/handoffs/<topic>.md`, in the `.local/` folder at the top of the
   repo (the working directory outside git; never `~/.local`). `<topic>` is a short kebab-case
   name for the work, such as `skyline-plugin`. If that file already exists, it belongs to
   another session: add `-2`, `-3`, … instead of overwriting it.

Make sure `.local/` is kept out of git: if `git check-ignore -q .local/` fails, add `.local/` to
`.git/info/exclude`.

**Updating:** rewrite it so it describes the state now. Keep what still matters from the old
version, drop what is finished or no longer true. It is not a log.

**What goes in it.** Write for a capable colleague who has seen none of this conversation. Be
specific: paths, commands, names, numbers. Link to longer documents rather than copying them.

- **Goal:** what the user is trying to achieve overall, and what this session was doing for it.
- **Where things stand:** what is done (and how it was checked), what is in progress, what is
  next. Name the exact next step.
- **Decisions and why:** choices made with the user, options rejected, and the reasons, so the
  new session doesn't reopen them.
- **The user's preferences and corrections:** how they like things done, things they said no to,
  their exact words where wording matters.
- **Context on the topic:** background facts, constraints and findings the work depends on,
  beyond the code: how the system works, what was learned while debugging, gotchas.
- **Files and docs:** the files changed or central to the work, plus specs, issues, PRs,
  artifacts, and other documents worth opening, each with a one-line note on why.
- **How to run and check things:** commands for build, tests, dev servers, ports, where outputs
  and logs go.
- **Open questions and risks:** anything unresolved or waiting on the user.
- **Git state:** branch, uncommitted or unpushed work, and what the user has and hasn't approved
  (for example "commits approved, ask before each push").

**If you are in an assistant/worker setup** (you are the `assistant`, or a `worker` reporting to
one), add a **Sessions** section:

- Use the ListAgents tool (load it with ToolSearch if needed) to list the other sessions, and
  record each one's exact name.
- For each worker or thread: what it is working on right now, whether it may edit code, what it
  is waiting for (an answer, a review, a run), and open question or answer IDs such as
  `QUESTION [C2]` that still need a reply.
- Who the editing worker is, if any, and the handoff file each worker uses.
- Tell the new session, in the handoff, to run ListAgents itself to find these sessions again
  and to reach them with SendMessage.

Keep it as short as it can be while still letting the new session continue without asking the
user anything. A page or two is typical.

## 3. Hand over to the user

Run this as the **last thing in your turn**, with the handoff file's path:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/mark-handoff.sh" <handoff file>
```

It records the handoff so that the session starting after `/clear` is told to read it first.
Then end the turn with exactly these two lines, the handoff path filled in and the second line
word for word (it is the user's own sign-off, spelling included):

> Handoff is in `.local/handoffs/skyline-plugin.md`.
>
> KLEAR ME NOW!

You can't run `/clear` yourself, and that's deliberate: the user typing it is their checkpoint.
Don't do any more work after this. If the script fails, add one line before the sign-off: "After
`/clear`, say: Continue from the handoff `<path>`."
