# Pranav's Marketplace

My Claude Code plugins.

| Plugin | What it is |
|---|---|
| [`assistant-worker`](plugins/assistant-worker/) | An assistant you talk to, one worker session per thread of work, and a browser agent |
| [`fineline`](plugins/fineline/) | A two-line status line with thin bars: branch and model, then context and rate limits |
| [`skyline`](plugins/skyline/) | A token usage chart that goes below your existing status line: last message cost and tokens per call |

Install one:

```
/plugin marketplace add pranavkbd/pranavs-marketplace
/plugin install fineline@pranavs-marketplace
```

For example, to install assistant-worker:

```
/plugin marketplace add pranavkbd/pranavs-marketplace
/plugin install assistant-worker@pranavs-marketplace
```

Then follow [its README](plugins/assistant-worker/) to add the `assistant` and `worker` shell launchers.
