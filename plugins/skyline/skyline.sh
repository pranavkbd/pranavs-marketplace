#!/usr/bin/env bash
# Skyline: a token usage status line for Claude Code.
# Reads the status line JSON on stdin and prints:
#   line 1: what the last message cost in tokens (hidden until the message has a call)
#   lines 2-8: a stacked bar chart of tokens per call for every message in the session
# Needs: bash, jq, awk (BSD or GNU). See SPEC.md for the full spec.
# Prints no context bar or model/branch line: run another status line above it for those.
export LC_NUMERIC=C
input=$(cat)
j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }
tp=$(j '.transcript_path')
R=$'\e[0m'; DIM=$'\e[2m'

line2=""
# Tokens used by the last turn: every API call since your last prompt (main thread only).
# calls x avg doc size = total read; new = uncached input + cache writes; the rest is cache reads; out = output.
k() { awk -v n="$1" 'BEGIN{ if(n>=1e6) printf "%.1fM",n/1e6; else if(n>=1e3) printf "%.1fk",n/1e3; else printf "%d",n }'; }
if [ -n "$tp" ] && [ -f "$tp" ]; then
  start=$(grep -n '"type":"user"' "$tp" | grep -v '"tool_result"' | cut -d: -f1 | awk '{a[NR]=$0} END{for(i=NR;i>0;i--) print a[i]}' | while read -r ln; do
    sed -n "${ln}p" "$tp" | jq -e 'select(.isMeta != true and .isSidechain != true and .isCompactSummary != true and (.message.content | type == "string" or any(.[]?; .type == "text")))' >/dev/null 2>&1 && { echo "$ln"; break; }
  done)
  if [ -n "$start" ]; then
    read -r calls tin tcache tout < <(tail -n +"$start" "$tp" | jq -rs '
      [ .[] | select(.type == "assistant" and .isSidechain != true and .message.usage) ]
      | unique_by(.message.id) | map(.message.usage)
      | "\(length) \(map((.input_tokens // 0) + (.cache_creation_input_tokens // 0)) | add // 0) \(map(.cache_read_input_tokens // 0) | add // 0) \(map(.output_tokens // 0) | add // 0)"' 2>/dev/null)
    if [ -n "$calls" ] && [ "$calls" -gt 0 ]; then
      read_total=$(( tin + tcache )); avg=$(( read_total / calls ))
      line2+="${DIM}last:${R} ${calls} call$([ "$calls" -eq 1 ] || echo s) ${DIM}×${R} ~$(k "$avg") doc ${DIM}=${R} $(k "$read_total") read ${DIM}($(k "$tin") new)${R} ${DIM}·${R} $(k "$tout") out"
    fi
  fi
fi

# Chart: tokens per call since the document started (resets on /clear or compaction).
# One column per call, so a message is as wide as its calls, with a thin gap at the start of each
# message; the chart grows as you go and, when full, older messages scroll off. Height = average tokens per call,
# stacked: re-read (cached) tokens / 20 (teal), new input (amber), output (red).
# Top of chart rescales: the first of 10k, 20k, 50k, 100k, ... at least twice the tallest bar.
# Labels sit to the right of the bars: legend (output, new input, re-read), message/call count, session totals.
# Settings: STATUSLINE_CHART_WIDTH (default: terminal width - 80), STATUSLINE_CHART_ROWS (default 6).
chart_lines=""
if [ -n "$tp" ] && [ -f "$tp" ]; then
  # widest the chart may grow: terminal width (Claude Code sets COLUMNS) minus ~80 for the axis and labels
  W=${STATUSLINE_CHART_WIDTH:-$(( ${COLUMNS:-140} - 80 ))}; [ "$W" -lt 20 ] && W=20
  data=$(jq -nr '
    reduce inputs as $e ({t:0, seen:{}, calls:[], tf:0, tn:0, to:0};
      if ($e.isCompactSummary==true) then .calls=[] | .t+=1
      elif ($e.type=="user" and $e.isMeta!=true and $e.isSidechain!=true
          and (($e.message.content|type)=="string" or any($e.message.content[]?; .type=="text"))) then .t+=1
      elif ($e.type=="assistant" and $e.isSidechain!=true and $e.message.usage and (.seen[$e.message.id]|not)) then
        .seen[$e.message.id]=true
        | ($e.message.usage) as $u
        | {t:.t, f:($u.cache_read_input_tokens//0),
           n:(($u.input_tokens//0) + ($u.cache_creation_input_tokens//0)),
           o:($u.output_tokens//0)} as $c
        | .calls += [$c] | .tf += $c.f | .tn += $c.n | .to += $c.o
      else . end)
    | if (.calls|length)==0 then empty else
      (.calls | group_by(.t) | map({key:(.[0].t|tostring), value:{f:(map(.f)|add/length), n:(map(.n)|add/length), o:(map(.o)|add/length)}}) | from_entries) as $avg
      | "\(.tf) \(.tn) \(.to) \(.calls[-1].f)", (.calls[] | "\(.t) \($avg[.t|tostring].f) \($avg[.t|tostring].n) \($avg[.t|tostring].o)")
      end' "$tp" 2>/dev/null)
  if [ -n "$data" ]; then
    chart_lines=$(printf '%s\n' "$data" | awk -v W="$W" -v ROWS="${STATUSLINE_CHART_ROWS:-6}" -v DIM="$DIM" -v R="$R" '
      function ak(n){ return (n>=1e6)?sprintf("%gM",n/1e6):(n>=1e3)?sprintf("%gk",n/1e3):sprintf("%d",n) }
      # y-axis prefix, padded with the Braille blank so Claude Code does not trim it
      function yax(txt,mark,  out){ out=sprintf("%5s",txt); gsub(/ /,B,out); return DIM out mark R }
      function k(n){ return (n>=1e6)?sprintf("%.1fM",n/1e6):(n>=1e3)?sprintf("%.1fk",n/1e3):sprintf("%d",n) }
      NR==1 { tf=$1; tn=$2; to=$3; floor=$4; next }
      { N++; t[N]=$1; F[N]=$2/20; Nw[N]=$3; O[N]=$4 }
      END {
        C["f"]=73; C["n"]=179; C["o"]=167; H=8*ROWS; B="⠀"
        # empty cells use the Braille blank (U+2800): Claude Code trims leading spaces from each
        # status line row, which would shift rows left and break the chart; this blank is not trimmed
        # one column per call (fixed step, never squeezed), so a message is as wide as its calls;
        # once the chart reaches W columns, the oldest whole messages scroll off the left
        m=0; for(i=1;i<=N;i++){ if(i==1 || t[i]!=t[i-1]){ m++; mf[m]=F[i]; mn[m]=Nw[i]; mo[m]=O[i]; mc[m]=0 } mc[m]++ }
        first=m; used=mc[m]; while(first>1 && used+mc[first-1]<=W){ first--; used+=mc[first] }
        L=0; mx=0
        for(q=first;q<=m;q++) for(c=0;c<mc[q];c++){ cf[L]=mf[q]; cn[L]=mn[q]; co[L]=mo[q]; tick[L]=(c==0)
          if(mf[q]+mn[q]+mo[q]>mx) mx=mf[q]+mn[q]+mo[q]; L++ }
        # top of chart: first of 10k, 20k, 50k, 100k, 200k, 500k, 1M, ... at least twice the tallest bar
        M=10000; while(M<2*mx){ M*=(substr(M,1,1)=="2")?2.5:2 }
        note=(first>1)?sprintf("last %d of %d messages", m-first+1, m):sprintf("%d message%s", m, (m==1)?"":"s")
        for(r=ROWS-1;r>=0;r--){ line=(r==ROWS-1)?yax(ak(M),B):(ROWS%2==0 && r==ROWS/2-1)?yax(ak(M/2),B):yax("",B)
          for(j=0;j<L;j++){
            b1=cf[j]/M*H; b2=(cf[j]+cn[j])/M*H; b3=(cf[j]+cn[j]+co[j])/M*H
            # whole cells only: round the top of each layer to a row
            c1=int(b1/8+0.5); c2=int(b2/8+0.5); c3=int(b3/8+0.5); if(c3<1 && b3>0) c3=1
            if(c2<c1)c2=c1; if(c3<c2)c3=c2
            A=(r<c1)?"f":(r<c2)?"n":(r<c3)?"o":""
            ch=(r==ROWS-1 && c3>ROWS)?"▲":(tick[j]?"▐":"█")  # first column is a right-half block: a thin gap starts each bar
            line=line (A==""?B:"\033[38;5;" C[A] "m" ch "\033[0m") }
          pad=""  # labels follow the bars, so they move right as the chart grows
          lab=(r==ROWS-1)?sprintf("\033[38;5;167m■%s output",R): \
              (r==ROWS-2)?sprintf("\033[38;5;179m■%s new input",R): \
              (r==ROWS-3)?sprintf("\033[38;5;73m■%s re-read ÷20  %s(%s per call now)%s",R,DIM,k(floor),R): \
              (r==1)?sprintf("\033[1;38;5;141m%d call%s%s %s·%s %s",N,(N==1)?"":"s",R,DIM,R,note): \
              (r==0)?sprintf("%ssession%s %s new · %s out · %s re-read total %s(all calls)%s",DIM,R,k(tn),k(to),k(tf),DIM,R):""
          print line pad B B lab }
        base=""; for(j=0;j<L;j++) base=base "─"  # bottom of the chart
        printf "%s%s%s%s\n", yax("",B), DIM, base, R
      }')
  fi
fi
# one line per row, with no blank first line when the last: line is hidden
out="$line2"
[ -n "$chart_lines" ] && out="${out:+$out$'\n'}$chart_lines"
printf '%s' "$out"
