# event.awk (ras 6): reads one hook event (JSON) on stdin for SessionStart, UserPromptSubmit and Stop,
# in one awk process, because every process start costs about 0.1 s on Windows. POSIX awk. Run with LC_ALL=C.
# Prints eight lines:
#   1 session id       the first string value of "session_id"
#   2 safe session id  line 1 with everything but A-Z a-z 0-9 _ - removed, for a file name
#   3 source           the first string value of "source"
#   4 agent            1 when the event has an "agent_id" key, else 0
#   5 active           1 when "stop_hook_active" is true, else 0
#   6 prompt           "prompt" in lower case, without leading and trailing spaces and \n \r \t escapes
#   7 asks             1 when "last_assistant_message" holds "approve spec" in any case, else 0
#   8 decisions        1 when that message has a Decisions heading, else 0
# Values stay as the JSON wrote them. No escape is decoded, so approve spec is not "approve spec".
# A key and its value must be on one line. An escaped \" inside a value cannot match a key.

# The first string value of a key on this line, or "" with found = 0.
function value(key,   re, m) {
  re = "\"" key "\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\""
  found = match($0, re)
  if (!found) return ""
  m = substr($0, RSTART, RLENGTH)
  sub(/^"[a-z_]*"[[:space:]]*:[[:space:]]*"/, "", m)
  sub(/"$/, "", m)
  return m
}
{
  if (!has["sid"]) { v = value("session_id"); if (found) { has["sid"] = 1; sid = v } }
  if (!has["src"]) { v = value("source"); if (found) { has["src"] = 1; src = v } }
  if (!has["p"]) { v = value("prompt"); if (found) { has["p"] = 1; p = v } }
  if (!has["last"]) { v = value("last_assistant_message"); if (found) { has["last"] = 1; last = v } }
  if ($0 ~ /"agent_id"[[:space:]]*:/) agent = 1
  if ($0 ~ /"stop_hook_active"[[:space:]]*:[[:space:]]*true/) active = 1
}
END {
  safe = sid; gsub(/[^A-Za-z0-9_-]/, "", safe)
  p = tolower(p)
  sub(/^(\\[nrt]|[[:space:]])+/, "", p)
  sub(/(\\[nrt]|[[:space:]])+$/, "", p)
  last = tolower(last)
  print sid; print safe; print src; print agent + 0; print active + 0; print p
  print (index(last, "approve spec") > 0) + 0
  print (last ~ /(^|\\n)[[:space:]]*([-*+][[:space:]]+)?(#+[[:space:]]*|\*\*)?decisions/) + 0
}
