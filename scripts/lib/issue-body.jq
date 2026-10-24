# Issue-body format for gh-issue.sh (revise and manual-tests).
#
# Run as:
#   jq -n -j --slurpfile view view.json --rawfile content FILE \
#      --arg op revise|manual --argjson version N --argjson limit 65536 \
#      --argjson issue N -f issue-body.jq
#
# Reads the body from $view[0].body, writes the new body to stdout (no trailing
# newline added by jq) or refuses: the message goes to stderr and the exit
# status is 5. Block content is exactly the lines strictly between the two
# marker lines, joined with "\n", so recovering it is byte-exact.
#
# The format contract is in the plan: docs/superpowers/plans/
# 2026-10-24-scripts-github-io-and-hooks.md ("Issue-body format contract").

def refuse(msg): msg | halt_error(5);
def malformed: refuse("issue #\($issue) body has malformed aew blocks; refusing to edit (fix by hand)");

# One whole marker line; a trailing \r is tolerated.
def any_marker: "^<!-- /?aew:[a-z-]+( v[0-9]+)? -->\r?$";
def blank: "^\\s*$";

# The opener on a line, or null.
def opener($l):
  ([$l | capture("^<!-- aew:spec v(?<v>[1-9][0-9]*) -->\r?$")] | .[0]) as $s
  | ([$l | capture("^<!-- aew:spec-prev v(?<v>[1-9][0-9]*) -->\r?$")] | .[0]) as $p
  | if $s then {kind: "spec", k: ($s.v | tonumber)}
    elif $p then {kind: "prev", k: ($p.v | tonumber)}
    elif ($l | test("^<!-- aew:manual-tests -->\r?$")) then {kind: "manual", k: 0}
    else null end;

def closes($b; $l):
  if $b.kind == "spec" then ($l | test("^<!-- /aew:spec -->\r?$"))
  elif $b.kind == "manual" then ($l | test("^<!-- /aew:manual-tests -->\r?$"))
  else ($l | test("^<!-- /aew:spec-prev v\($b.k) -->\r?$")) end;

# Two-state scan: outside a block only an opener may appear; inside, the next
# marker line must be the matching close. Returns {blocks, bad}.
def scan($L):
  reduce range(0; $L | length) as $i ({blocks: [], cur: null, bad: false};
    if .bad then .
    elif ($L[$i] | test(any_marker)) | not then .
    elif .cur == null then
      (opener($L[$i])) as $o
      | if $o then .cur = ($o + {open: $i}) else .bad = true end
    elif closes(.cur; $L[$i]) then
      .blocks += [.cur + {close: $i}] | .cur = null
    else .bad = true end)
  | {blocks, bad: (.bad or .cur != null)};

def inner($L; $b): $L[$b.open + 1 : $b.close];

# Drops leading and trailing blank lines; [] when every line is blank.
def trim_blank:
  (map(test(blank) | not)) as $nb
  | ([range(0; length) | select($nb[.])]) as $ix
  | if ($ix | length) == 0 then [] else .[$ix[0] : $ix[-1] + 1] end;

# C_K of a prev block, or malformed.
def prev_content($L; $b):
  inner($L; $b) as $P
  | if ($P | length) >= 6
       and ($P[0] | test("^<details>\r?$"))
       and ($P[1] | test("^<summary>.*</summary>\r?$"))
       and ($P[2] | test("^\r?$"))
       and ($P[-2] | test("^\r?$"))
       and ($P[-1] | test("^</details>\r?$"))
    then $P[3:-2] | join("\n")
    else malformed end;

def spec_block($n; $s): "<!-- aew:spec v\($n) -->\n" + $s + "\n<!-- /aew:spec -->";
def manual_block($m): "<!-- aew:manual-tests -->\n" + $m + "\n<!-- /aew:manual-tests -->";
def prev_block($k; $c):
  "<!-- aew:spec-prev v\($k) -->\n<details>\n<summary>Spec v\($k)"
  + (if $k == 1 then " (original)" else "" end)
  + "</summary>\n\n" + $c + "\n\n</details>\n<!-- /aew:spec-prev v\($k) -->";

# managed: spec, manual?, prev blocks newest first, O?
def serialise_managed($n; $s; $m; $prevs; $o):
  ([spec_block($n; $s)]
   + (if $m != null then [manual_block($m)] else [] end)
   + ($prevs | sort_by(-.k) | map(prev_block(.k; .c)))
   + (if $o != null then [$o] else [] end)
   | join("\n\n")) + "\n";

def serialise_unmanaged($v; $m):
  (if $v == "" then "" else $v + "\n\n" end) + manual_block($m) + "\n";

# --- the program ---------------------------------------------------------------

($view[0].body // "") as $body
| ($body | split("\n")) as $L
| ($content | split("\n")) as $CL
| if ($CL | map(select(test(any_marker))) | length) > 0
  then refuse("content file contains an aew marker line; refusing to edit")
  else . end
| scan($L) as $scan
| if $scan.bad then malformed else . end
| $scan.blocks as $blocks
| [$blocks[] | select(.kind == "spec")] as $specs
| [$blocks[] | select(.kind == "manual")] as $mts
| [$blocks[] | select(.kind == "prev")] as $prevs
| if ($specs | length) > 1 or ($mts | length) > 1 then malformed else . end
| ($specs | length == 1) as $managed
| if ($prevs | map(.k) | unique | length) != ($prevs | length) then malformed else . end
| if $managed
  # Count first: `or` short-circuits, so a huge vN never builds range(1; N).
  then (if ($prevs | length) != $specs[0].k - 1
           or ($prevs | map(.k) | sort) != [range(1; $specs[0].k)]
        then malformed else . end)
  else (if ($prevs | length) > 0 then malformed else . end)
  end
| (if $mts | length == 1 then inner($L; $mts[0]) | join("\n") else null end) as $m
| (if $managed then $specs[0].k else 1 end) as $cur
| if $op == "manual" then .
  elif $version < 2 then refuse("version must be >= 2 (v1 is the author's original)")
  elif $version < $cur then refuse("spec v\($version) is older than the recorded v\($cur) (regression); not editing")
  elif $version > $cur + 1 then refuse("spec v\($version) would skip v\($cur + 1) (gap); not editing")
  else . end
| ([$prevs[] | {k, c: prev_content($L; .)}]) as $prev_c
| (if $managed then inner($L; $specs[0]) | join("\n") else null end) as $s_cur
# manual: the block is set or replaced; the spec version, spec and history stay.
| ($op == "manual") as $manual
| (if $manual then $s_cur
   elif $version == $cur
   then (if $content == $s_cur or $content == ($s_cur | split("\n") | map(rtrimstr("\r")) | join("\n"))
         then $s_cur
         else refuse("spec v\($version) already recorded with different content; use version \($version + 1)") end)
   else $content end) as $spec
| (if $managed
   then
     # Author text outside the blocks is kept, moved to the end.
     ([range(0; ($blocks | length) + 1)
       | $L[(if . == 0 then 0 else $blocks[. - 1].close + 1 end)
            : (if . == ($blocks | length) then ($L | length) else $blocks[.].open end)]
       | trim_blank | select(length > 0) | join("\n")] | if length == 0 then null else join("\n\n") end) as $o
     | serialise_managed(if $manual then $cur else $version end; $spec;
         (if $manual then $content else $m end);
         (if $manual or $version == $cur then $prev_c else [{k: $cur, c: $s_cur}] + $prev_c end); $o)
   else
     # Unmanaged: V is the author's whole body (minus a manual block we wrote).
     (if ($mts | length) == 0 then $body
      else
        $mts[0] as $b
        | (if $b.open == 0 then ""
           elif ($L[$b.open - 1] | test("^\r?$")) then $L[0 : $b.open - 1] | join("\n")
           else $L[0 : $b.open] | join("\n") end) as $before
        | ($L[$b.close + 1 :] | trim_blank | join("\n")) as $tail
        | if $tail == "" then $before
          elif $before == "" then $tail
          else $before + "\n\n" + $tail end
      end) as $v
     | if $manual then serialise_unmanaged($v; $content)
       else serialise_managed($version; $spec; $m; [{k: 1, c: $v}]; null) end
   end) as $new
| if ($new | length) > $limit
  then refuse("new body would be \($new | length) characters (GitHub limit \($limit)); not editing")
  else $new end
