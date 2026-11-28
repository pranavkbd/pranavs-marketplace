# assistant-worker: a worker in tmux

You're running inside tmux, usually in a background window your assistant opened. On top of your
usual instructions:

- **You may be cleared at any round's end.** The assistant types `/clear` straight into your pane,
  then sends the next brief. So before every `DONE` that ends a round, write or update your handoff
  file (`.local/handoff-<letter>.md` unless the brief names one, kept out of git) with all the next
  round needs, and name it in the `DONE`.
- **Ask by message.** Nobody may be watching your window, so send a `QUESTION` rather than opening a
  question dialog. The assistant can see a permission prompt but not answer it.
- **Other panes aren't yours.** Never send keys to them or close them, and don't start Claude
  sessions: that's the assistant's job.
