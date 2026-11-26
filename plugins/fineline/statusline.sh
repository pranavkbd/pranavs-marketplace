#!/bin/bash
# Fineline: a Claude Code status line with thin hairline bars.
# Line 1: branch (or folder), ports, model. Line 2: context, 5h and 7d limits.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_name=$(basename "$cwd" 2>/dev/null)
[ -z "$dir_name" ] && dir_name="$cwd"

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
model_id=$(echo "$input" | jq -r '.model.id // ""')

effort=$(echo "$input" | jq -r 'if (.effort|type) == "object" then .effort.level else .effort end // empty')

# Prefer an actual reported session cost if Claude Code provides one.
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

if [ -z "$cost" ]; then
  # Fallback: rough estimate from the last API call's token usage.
  input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
  output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
  cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
  cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

  # Per-1K-token USD rates, keyed off the model id.
  case "$model_id" in
    *opus*) in_rate=0.015; out_rate=0.075; cr_rate=0.0015; cw_rate=0.01875 ;;
    *haiku*) in_rate=0.0008; out_rate=0.004; cr_rate=0.00008; cw_rate=0.001 ;;
    *) in_rate=0.003; out_rate=0.015; cr_rate=0.0003; cw_rate=0.00375 ;;
  esac

  cost=$(awk -v it="$input_tokens" -v ot="$output_tokens" -v cr="$cache_read" -v cw="$cache_write" \
    -v ir="$in_rate" -v orr="$out_rate" -v crr="$cr_rate" -v cwr="$cw_rate" \
    'BEGIN { printf "%.4f", (it*ir + ot*orr + cr*crr + cw*cwr) / 1000 }')
fi

fmt_k() {
  awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n/1000000; else if (n >= 1000) printf "%.0fk", n/1000; else printf "%d", n }'
}

# Git branch (skip optional locks) with dirty marker
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
dirty=""
if [ -n "$branch" ] && [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
  dirty="*"
fi

# Thin line bar: 8 cells, filled part colored, rest dim. bar PCT COLOR
bar() {
  local f=$(( ($1 * 8 + 50) / 100 )) i out=""; [ "$f" -gt 8 ] && f=8; [ "$f" -lt 0 ] && f=0
  out=$(printf "\033[%sm" "$2")
  for ((i = 0; i < f; i++)); do out="$out━"; done
  out="$out$(printf '\033[2m')"
  for ((i = f; i < 8; i++)); do out="$out─"; done
  printf '%s\033[0m' "$out"
}

# Context window: tokens used / left
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

ctx=""
if [ -n "$used_pct" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  left_tok=$(awk -v s="$ctx_size" -v p="$used_pct" 'BEGIN{printf "%d", s*(100-p)/100}')
  [ "$left_tok" -lt 0 ] && left_tok=0
  pct_int=$(printf '%.0f' "$used_pct")
  if [ "$pct_int" -ge 85 ]; then c=31; elif [ "$pct_int" -ge 60 ]; then c=33; else c=34; fi
  ctx=$(printf "\033[2mctx\033[0m %s \033[%sm%s%%\033[0m" "$(bar "$pct_int" "$c")" "$c" "$pct_int")
else
  ctx=$(printf "\033[2mctx --\033[0m")
fi

# Rate limits: one line with a usage bar and a dot countdown per window
now=$(date +%s)

# Seconds as "2h14m", "3d5h" or "25m"
fmt_dur() {
  local secs=$1 d h m
  d=$(( secs / 86400 )) h=$(( secs % 86400 / 3600 )) m=$(( secs % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

# limit_row LABEL KEY COLOR
limit_row() {
  local pct reset p c=$3 row left
  pct=$(echo "$input" | jq -r ".rate_limits.$2.used_percentage // empty")
  [ -z "$pct" ] && return
  reset=$(echo "$input" | jq -r ".rate_limits.$2.resets_at // empty")
  p=$(printf '%.0f' "$pct")
  row=$(printf "\033[2m%s\033[0m %s \033[%sm%s%%\033[0m" "$1" "$(bar "$p" "$c")" "$c" "$p")
  if [ -n "$reset" ]; then
    left=$(( ${reset%.*} - now )); [ "$left" -lt 0 ] && left=0
    row="$row $(printf "\033[2m%s\033[0m" "$(fmt_dur "$left")")"
  fi
  printf '%s' "$row"
}

sep=$(printf "\033[2m | \033[0m")
# Line 1: branch (or folder outside git), this checkout's ports, model
if [ -n "$branch" ]; then
  out=$(printf "\033[36m%s%s\033[0m" "$branch" "$dirty")
else
  out=$(printf "\033[36m%s\033[0m" "$dir_name")
fi

# Stash checkouts: this checkout's server and UI ports, shown only while they're listening,
# as clickable OSC 8 links. Ports come from .local/config.yml and the UI's env file.
port_up() { timeout 0.2 bash -c "exec 3<>/dev/tcp/127.0.0.1/$1" 2>/dev/null; }
link() { printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$1" "$2"; }
top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
if [ -n "$top" ] && [ -f "$top/.local/config.yml" ]; then
  srv=$(sed -n 's/^port: *//p' "$top/.local/config.yml" 2>/dev/null | head -1)
  ui=$(sed -n 's/^STASH_UI_PORT=//p' "$top/ui/v2.5/.env.development.local" 2>/dev/null | tail -1)
  ports=""
  for spec in "srv:$srv" "ui:$ui"; do
    label=${spec%%:*} port=${spec#*:}
    [ -n "$port" ] && port_up "$port" || continue
    [ -n "$ports" ] && ports="$ports "
    ports="$ports$(printf '\033[2m%s\033[0m \033[32m' "$label")$(link "http://localhost:$port" ":$port")$(printf '\033[0m')"
  done
  [ -n "$ports" ] && out="$out$sep$ports"
fi

out="$out$sep$(printf "\033[35m%s\033[0m" "$model")"
[ -n "$effort" ] && out="$out$(printf "\033[2m (%s)\033[0m" "$effort")"

# Line 2: context, then session limit in orange (256-color 208), weekly limit in green
line2="$ctx"
for spec in "5h:five_hour:38;5;208" "7d:seven_day:32"; do
  IFS=: read -r label key color <<< "$spec"
  row=$(limit_row "$label" "$key" "$color")
  [ -n "$row" ] && line2="$line2$sep$row"
done

printf "%s\n%s" "$out" "$line2"
exit 0
