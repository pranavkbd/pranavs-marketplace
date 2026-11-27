# Skyline spec

How the skyline status line works. The implementation is [`skyline.sh`](skyline.sh) (bash, jq,
awk). It has been tested on macOS (Apple Terminal, Claude Code 2.1.x).

## What it looks like

On screen, `■ output` and the top of each bar are red, `■ new input` is amber, and `■ re-read`
and the bottom of each bar are teal.

```
▰▰▰▱▱▱▱▱ 34%  last: 3 calls × ~339.1k doc = 1.0M read (8.0k new) · 3.8k out
  50k                                                      ■ output
                                                           ■ new input
                                                           ■ re-read ÷20  (335.0k per call now)
  25k
      ▐█████▐███▐███▐▐▐▐█▐▐███▐██▐████▐███▐██▐██▐█▐▐█▐█▐█  59 messages
      ▐█████▐███▐███▐▐▐▐█▐▐███▐██▐████▐███▐██▐██▐█▐▐█▐█▐█  session 308.0k new · 172.1k out · 34.3M re-read total (all calls)
      ──────────────────────────────────────────────────────  154 calls
```

- **Line 1:** the context-window bar, then what the user's last message cost.
- **The chart:** one bar per message the user sent. A bar's **width** is the number of model calls
  that message took (one column per call). Its **height** is the average tokens per call, stacked
  bottom to top as re-read (divided by 20), new input, then output. Each bar starts with a thin gap.
- **The labels** to the right of the chart: a legend in stacking order (top to bottom), the
  message and call counts in bold, and session totals.

## Concepts

| Term | Meaning | Where it comes from |
|---|---|---|
| **Call** | One request to the model. A message with no tool use is 1 call. Each round of tool use ends one call and starts another, so a message that reads a file, edits it and replies is about 3 calls. | One assistant API response |
| **Re-read** | Tokens the call read from the prompt cache. Every call re-sends the whole conversation (the "document"), so this is roughly the document size. | `usage.cache_read_input_tokens` |
| **New input** | Tokens the call read for the first time (uncached, plus tokens written to the cache). | `usage.input_tokens + usage.cache_creation_input_tokens` |
| **Output** | Tokens the model wrote, thinking included. | `usage.output_tokens` |

Each call re-reads the whole document, so **total re-read ≈ calls × average document size**. In a
long session, re-reads are most of the tokens. The number of calls is the multiplier, which is why
the call count sits on the baseline in bold violet.

## Inputs

1. **Status line JSON on stdin.** Two fields are used:
   - `.context_window.used_percentage`: context fullness, 0 to 100
   - `.transcript_path`: path to the session transcript (JSONL)
2. **`COLUMNS` environment variable.** Claude Code sets it to the terminal width. `/dev/tty` is
   **not** available to the status line command, so `stty size` fails.

## Reading the transcript

The transcript is JSONL, one entry per line.

1. **Calls are `type == "assistant"` entries with `message.usage`.**
2. **Deduplicate by `message.id`.** One API response is written as several lines, one per content
   block (thinking, text, tool_use), and each line repeats the same `usage`.
3. **Skip `isSidechain == true`.** Those are subagent entries. Subagent usage is not counted (a
   known limitation).
4. **A user message**, the thing that starts a new bar, is an entry with `type == "user"`,
   `isMeta != true`, `isSidechain != true` and `isCompactSummary != true`, whose `message.content`
   is a string or an array containing a `text` block.
   - Entries whose content is only `tool_result` blocks are tool results, not user messages.
   - `isMeta` entries are injected context, such as skill text.
   - "[Request interrupted by user …]" entries count as messages. They get no calls, so they draw
     no bar.
5. **`isCompactSummary == true` starts a new document.** After compaction the call list is cleared
   so the chart starts over. `/clear` starts a new transcript file, so it resets the chart
   naturally.
6. **"Last message" for line 1** means every call after the last user message, as defined in rule 4.

## Line 1: context bar and last message

- **Bar:** 8 cells, filled cells = round(pct × 8 / 100). Green below 50%, yellow from 50%, red
  from 80%.
- **`last:`** covers the calls since the last user message: `N calls`, `× ~avg doc` where
  avg = (new + re-read) / calls, `= total read`, `(X new)`, `· Y out`.
- **Hidden when the current message has 0 calls**, right after the user hits enter.
- Number format: `1234 → 1.2k`, `1234567 → 1.2M`, below 1000 as an integer.

## The chart

### Data per bar

Calls are grouped by user message. For each message: calls = count, and f, n, o = the average per
call of re-read, new input and output. Re-reads are drawn at `f / 20` so new input and output stay
visible even when the document is 300k tokens.

### Width and growth

- **One column per call, never squeezed.**
- **The chart grows to the right** up to `W = STATUSLINE_CHART_WIDTH`, default `COLUMNS − 80`,
  minimum 20.
- **When the calls no longer fit in W, the oldest whole messages scroll off the left.** A message
  is never cut in half. The count label then says `last 49 of 59 messages`.

### Height and scale

- **Rows:** `STATUSLINE_CHART_ROWS`, default 6.
- **Top of chart (M):** the first of 10k, 20k, 50k, 100k, 200k, 500k, 1M, 2M, … that is **at least
  twice the tallest bar** in view.
- **Y-axis labels:** `ak(M)` on the top row and `ak(M/2)` on row `ROWS/2 − 1` (0 = bottom),
  right-aligned in 5 characters, formatted as `50k`, `25k`, `2.5k`, `1M`.

### Drawing each cell

- **Every cell is one solid color, filled or empty.** No partial-height blocks, no backgrounds.
- Layer tops per column, rounded to the nearest row: `c1 = round(f/M × ROWS)`,
  `c2 = round((f+n)/M × ROWS)`, `c3 = round((f+n+o)/M × ROWS)`. `c3 ≥ 1` if the column has any
  tokens, and `c1 ≤ c2 ≤ c3`.
- Row r is re-read if `r < c1`, new input if `r < c2`, output if `r < c3`, otherwise empty.
- **Glyph:** `█`, except the first column of each message uses `▐`, which leaves a thin gap so
  adjacent messages read as separate bars. A column taller than the chart gets `▲` in its top cell.
- **Colors** (256-color foreground): re-read `38;5;73` teal, new input `38;5;179` amber, output
  `38;5;167` red.

### Labels

Labels follow the bars directly, so they move right as the chart grows. From the top: `■ output`,
`■ new input`, `■ re-read ÷20  (335.0k per call now)` (the last call's raw re-read, dimmed), then
on row 1 the bold message count, and on row 0 the dimmed session totals. A dimmed `─`
baseline as long as the bars sits underneath, followed by the call count in bold violet (`38;5;141`, a
color no bar layer uses).

## Pitfalls

Each of these broke the display at least once.

1. **Claude Code trims leading whitespace from every status line row**, which shifts rows left and
   jumbles the chart. Empty cells, axis padding and the gap before the labels use the Braille
   blank `⠀` (U+2800), which looks empty and is not trimmed.
2. **Background colors are not drawn.** One color per cell.
3. **Partial blocks** (`▁▃▅`) show up as floating slivers. Whole cells only.
4. **Thin dark lines between rows** come from the terminal's line spacing. Set line height to 1.0.
5. **No `/dev/tty`.** Use `COLUMNS` for width.
6. **Box-drawing characters can't line up with half-cell gaps**, so there is no per-message tick
   line, only the plain baseline.
7. **The awk program sits inside single quotes in bash.** An apostrophe in an awk comment ends the
   program and blanks the chart.
8. **`tail -r` exists only on macOS.** Lines are reversed with awk instead.
9. **`LC_NUMERIC=C`** keeps `printf '%.0f'` working in locales with a comma decimal separator.
10. **Performance:** the transcript is read once with `jq -n 'reduce inputs …'`, which streams
    instead of slurping. About 0.3 s on a 0.5 MB transcript and 0.9 s on a 12 MB one.

## Acceptance checks

Run `echo '{"context_window":{"used_percentage":34},"transcript_path":"<path>"}' | COLUMNS=200 ./skyline.sh`
and check:

- [ ] A message with 1 call is 1 column wide, and a message with 11 calls is 11 columns.
- [ ] Every column stacks bottom-up as re-read, new input, output.
- [ ] With leading whitespace stripped (`sed 's/^ *//'`), the rows still line up.
- [ ] Every label row starts in the same column.
- [ ] Duplicate transcript lines with the same `message.id` are counted once.
- [ ] A fresh session (1–2 messages) draws a short chart with a 10k or 20k top.
- [ ] More calls than `W` scrolls whole messages off and shows `last N of M messages`.
- [ ] Right after the user sends a message (0 calls yet), `last:` is hidden and nothing errors.
- [ ] A transcript whose last entry is a compaction summary draws no chart until the next call.
