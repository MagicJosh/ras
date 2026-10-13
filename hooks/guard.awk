# guard.awk (ras 6): the PreToolUse check, in one awk process. POSIX awk. Run with LC_ALL=C.
# Reads one hook event (JSON) on stdin and prints two lines: the session id, then a verdict:
#   ok | specs | risky <path> (matches <pattern>) | cannot <reason>
# Exits 1 on input it cannot parse, a bad pattern or an unreadable .ras/risky-paths. The shell then denies.
# Env: CLAUDE_PROJECT_DIR, and RAS_RISKY = the .ras/risky-paths file when it exists. Strings come in through
# ENVIRON because awk -v would process backslash escapes. Regexes use [.] instead of \. for the same reason.
# A guard rail for the agent, not a sandbox: it reads redirects and the arguments of write commands.

function fail(m) { print "ras: " m > "/dev/stderr"; exit 1 }
function set(A, s,   n, i) { n = split(s, tw, " "); for (i = 1; i <= n; i++) A[tw[i]] = 1 }
function add(p) { pat[++np] = p; all = all (np > 1 ? "|" : "") "(" p ")" }

# ---- paths
# Lowercase, \ to /, one slash, /c/x to c:/x, no trailing slash.
function norm(p) {
  p = tolower(p); gsub(/\\/, "/", p); gsub(/\/\/+/, "/", p)
  if (p ~ /^\/[a-z]\//) p = substr(p, 2, 1) ":" substr(p, 3)
  sub(/\/$/, "", p)
  return p
}
# Resolve . and .. as text. A leading .. that cannot be resolved stays.
function canon(p,   lead, n, i, m, s, r) {
  lead = ""
  if (p ~ /^[a-z]:\//) { lead = substr(p, 1, 3); p = substr(p, 4) }
  else if (substr(p, 1, 1) == "/") { lead = "/"; p = substr(p, 2) }
  n = split(p, ca, "/"); m = 0
  for (i = 1; i <= n; i++) {
    s = ca[i]
    if (s == "" || s == ".") continue
    if (s == "..") {
      if (m > 0 && co[m] != "..") { m--; continue }
      if (lead != "") continue
    }
    co[++m] = s
  }
  r = ""
  for (i = 1; i <= m; i++) r = r (i > 1 ? "/" : "") co[i]
  return lead r
}

# ---- risky paths
# The risky paths: the defaults, or the lines of .ras/risky-paths, which replace them.
function load(f,   line, r, x, cr) {
  if (f == "") {
    add("(^|/)[.]github/(workflows|actions)(/|$)")
    add("(^|/)[.]gitlab-ci[.]yml$")
    add("(^|/)[.]env([.][^/]*)?$")
    add("(^|/)[.]envrc$")
    add("(^|/)[.](husky|devcontainer)(/|$)")
    add("(^|/)[.]mcp[.]json$")
    add("(^|/)migrations?(/|$)")
    add("(^|/)db/migrate(/|$)")
    add("[.]sql$")
    add("(^|/)dockerfile[^/]*$")
    add("(^|/)docker-compose[^/]*$")
    add("(^|/)compose([.][^/]+)?[.]ya?ml$")
    add("[.]tf(vars)?$")
    add("(^|/)prisma/schema[.]prisma$")
    add("(^|/)supabase/config[.]toml$")
    add("(^|/)(auth|permissions)(/|$)")
    add("(^|/)(auth|permissions|policies)[.][^/]*$")
    return
  }
  ovr = 1; cr = sprintf("%c", 13)
  while ((r = (getline line < f)) > 0) {
    gsub(cr, "", line); sub(/^[[:blank:]]+/, "", line); sub(/[[:blank:]]+$/, "", line)
    if (line == "" || substr(line, 1, 1) == "#") continue
    line = tolower(line)
    x = ("" ~ line) # compile now: a bad regex ends awk here, on every call
    add(line)
  }
  if (r < 0) fail("cannot read " f)
  close(f)
  if (np) x = ("" ~ all)
}
# Print the pattern that makes the repo-relative, lowercase path w risky. Print nothing if none does.
function risky(w,   k) {
  if (w ~ /(^|\/)[.]ras(\/|$)/ && w !~ /(^|\/)[.]ras\/handoffs(\/|$)/) return ".ras/"
  if (w ~ /(^|\/)[.]claude\/spec[.]/) return ".claude/spec.*"
  if (!ovr && w ~ /(^|\/)[.]env[.](example|sample|template|dist)$/) return ""
  if (np == 0 || w !~ all) return "" # one regex first: gawk compiles a dynamic regex again each time it changes
  for (k = 1; k <= np; k++) if (w ~ pat[k]) return pat[k]
  return ""
}

# ---- JSON
# Backslashes at the end of s: an odd count means the next quote is escaped.
function odd(s,   l, k) { l = length(s); k = 0; while (l > 0 && substr(s, l, 1) == "\\") { k++; l-- } return k % 2 }
# Walk the quotes once. A string followed by a colon is a key. raw[key] = the raw text of the first string value.
function parse(j,   n, i, ins, cur, cap, joined, t, want) {
  if (j !~ /^[[:space:]]*[{]/) fail("the hook input is not a JSON object")
  K["session_id"] = K["tool_name"] = K["command"] = K["file_path"] = K["notebook_path"] = 1
  n = split(j, sg, "\"")
  for (i = 1; i < n; i++) {
    if (!ins) { ins = 1; cur = sg[i + 1]; joined = 0; cap = (want != ""); continue }
    if (odd(sg[i])) { # an escaped quote: the string goes on
      joined = 1
      if (cap && length(cur) < 140000) cur = cur "\"" sg[i + 1]
      continue
    }
    ins = 0; t = sg[i + 1]
    if (t ~ /^[[:space:]]*:/) {
      want = ""
      if (!joined && (cur in K) && !(cur in raw)) want = cur
      sub(/^[[:space:]]*:[[:space:]]*/, "", t)
      if (t != "") want = "" # the value is not a string
    } else if (want != "") { raw[want] = cur; want = "" }
  }
  if (ins) fail("unterminated string in the hook input")
}
# Decode \" \\ \/ \b \f \n \r \t. A \u escape sets uesc: the guard does not decode it.
function dec(s,   m, j, c, o) {
  m = split(s, dp, "\\"); o = dp[1]; j = 2
  while (j <= m && length(o) <= 65536) {
    if (dp[j] == "") { o = o "\\"; j++; if (j <= m) o = o dp[j]; j++; continue }
    c = substr(dp[j], 1, 1)
    if (c == "u") { uesc = 1; return "" }
    if (c == "n") c = "\n"
    else if (c == "t") c = "\t"
    else if (c == "r") c = "\r"
    else if (c == "b") c = sprintf("%c", 8)
    else if (c == "f") c = sprintf("%c", 12)
    o = o c substr(dp[j], 2); j++
  }
  return o
}

# ---- the shell tokenizer
function push(s, ps) { qt[++qn] = s; qp[qn] = ps }
function chk(w,   h) { if (hitv == "" && w != "") { h = cand(w); if (h != "") hitv = h } }
# One path word. Print "path (matches pattern)" when it is risky.
function cand(w,   h) {
  if (substr(w, 1, 1) == "~") return ""
  w = norm(w)
  if (w ~ /^(\/|[a-z]:\/)/) {
    w = canon(w)
    if (index(w "/", base "/") != 1) return ""
    w = substr(w, length(base) + 2)
  } else w = canon(w)
  if (w == "" || w ~ /^specs\//) return ""
  h = risky(w)
  return h == "" ? "" : w " (matches " h ")"
}
# An argument of a write command: an option is no path, but --opt=value and a=value check the value.
function argchk(a) {
  if (cps && a ~ /^-[a-z]+:/) chk(substr(a, index(a, ":") + 1))
  else if (index(a, "=")) chk(substr(a, index(a, "=") + 1))
  else if (a !~ /^-/) chk(a)
}
# The simple command is complete: check its arguments by the command word.
function evalcmd(   k, a, last, g, s, j) {
  if (cmd in WR) { for (k = 1; k <= na; k++) argchk(ar[k]); return }
  if (cmd in DST) { # the destination only: reading a risky file into another file passes
    last = ""
    for (k = 1; k <= na; k++) { a = ar[k]; if (a ~ /^-/ || index(a, "=")) argchk(a); else last = a }
    chk(last); return
  }
  if (cmd == "dd") { for (k = 1; k <= na; k++) if (ar[k] ~ /^of=/) chk(substr(ar[k], 4)); return }
  if (cmd == "sed" || cmd == "perl") {
    g = 0
    for (k = 1; k <= na; k++) if (ar[k] ~ /^-[a-z]*i/ || ar[k] ~ /^--in-place/) g = 1
    if (g) for (k = 1; k <= na; k++) argchk(ar[k])
    return
  }
  if (cmd == "git") { # git -c x=y -C dir <sub> ...; checkout is left out, because feature/auth is a branch
    g = ""
    for (k = 1; k <= na; k++) {
      a = ar[k]
      if (g != "") argchk(a)
      else if (a == "-c") k++
      else if (a !~ /^-/) { g = a; if (!(g in GIT)) return }
    }
    return
  }
  if (cmd in SHELL) { for (k = 1; k < na; k++) if (ar[k] ~ /^-[a-z]*c$/) { push(ar[k + 1], 0); return }; return }
  if (cmd == "pwsh" || cmd == "powershell") {
    for (k = 1; k <= na; k++) if (ar[k] == "-c" || ar[k] == "-command") {
      s = ""
      for (j = k + 1; j <= na; j++) s = s (j > k + 1 ? " " : "") ar[j]
      if (s != "") push(s, 1)
      return
    }
    return
  }
  if (cmd == "eval" && na > 0) { s = ar[1]; for (k = 2; k <= na; k++) s = s " " ar[k]; push(s, 0) }
}
function endcmd(   k) {
  if (cmd != "") evalcmd()
  if (cmd in SHELL) for (k = hd0; k <= hdn; k++) hds[k] = 1 # a heredoc fed to a shell is a script
  hd0 = hdn + 1; cmd = ""; pre = 0; na = 0
}
function word(w,   b) {
  if (cmd != "") { ar[++na] = w; return }
  if (w ~ /^[a-z_][a-z0-9_]*=/) return
  if (pre && w ~ /^-/) return # shortcut: options of sudo, env and friends that take a value (sudo -u root) are not skipped, upgrade when such a call slips through
  b = w; gsub(/\\/, "/", b); sub(/.*\//, "", b); sub(/[.]exe$/, "", b)
  if (b in SK) { pre = (b in SP); return }
  cmd = b; pre = 0; na = 0
}
# A word is complete: a redirect target, a heredoc delimiter, or a word of the command.
function endword(   w) {
  if (!inw) return
  w = wd; wd = ""; inw = 0; wq = 0
  if (rd == 1 || (rd == 4 && w !~ /^([0-9]+|-)$/)) chk(w)
  else if (rd == 3) { hdn++; hdw[hdn] = w; hdt[hdn] = hdtab; hds[hdn] = 0 }
  if (rd) rd = 0
  else word(w)
}
# Walk the characters once. Quotes come off and glue to their neighbors.
# shortcut: a heredoc starts after << even inside $(( 1 << 2 )), so lines after one can be skipped, upgrade when that matters
function walk(c, ps,   n, i, ch, nx, t, esc, k, m, j, l, used, body) {
  n = length(c); i = 1; esc = ps ? "`" : "\\"
  wd = ""; inw = 0; wq = 0; rd = 0; cmd = ""; pre = 0; na = 0; hdn = 0; hd0 = 1; cps = ps
  while (i <= n && hitv == "") {
    ch = substr(c, i, 1)
    if (ch == "'") {
      inw = 1; wq = 1; i++
      while (i <= n) {
        t = substr(c, i, 1)
        if (t == "'") {
          if (!ps || substr(c, i + 1, 1) != "'") break
          i++ # '' is a quote in PowerShell
        }
        wd = wd t; i++
      }
      i++
    } else if (ch == "\"") {
      inw = 1; wq = 1; i++
      while (i <= n) {
        t = substr(c, i, 1)
        if (t == "\"") break
        if (t == esc) {
          nx = substr(c, i + 1, 1)
          if (nx == "\n") { i += 2; continue }
          if (nx != "" && (ps || index("\"\\$`", nx))) { t = nx; i++ }
        }
        wd = wd t; i++
      }
      i++
    } else if (ch == esc) {
      nx = substr(c, i + 1, 1)
      if (nx != "" && nx != "\n") { wd = wd nx; inw = 1 }
      i += 2
    } else if (ch == " " || ch == "\t" || ch == "\r" || (ps && ch == ",")) {
      endword(); i++
    } else if (ch == "\n") {
      endword(); endcmd(); rd = 0; i++
      for (k = 1; k <= hdn; k++) { # the heredoc bodies start on the next line
        m = split(substr(c, i), hl, "\n"); body = ""; used = 0
        for (j = 1; j <= m; j++) {
          l = hl[j]; used += length(l) + 1
          t = l
          if (hdt[k]) while (substr(t, 1, 1) == "\t") t = substr(t, 2)
          if (t == hdw[k]) break
          if (hds[k]) body = body l "\n"
        }
        i += used
        if (body != "") push(body, 0)
      }
      hdn = 0; hd0 = 1
    } else if (ch == "#" && !inw) {
      t = index(substr(c, i), "\n"); i = t ? i + t - 1 : n + 1
    } else if (ch == ";" || ch == "|" || ch == "(" || ch == ")" || (ch == "&" && substr(c, i + 1, 1) != ">") || (!ps && ch == "`")) {
      endword(); endcmd(); rd = 0; i++
    } else if (ch == ">" || ch == "<" || ch == "&") {
      if (ch != "&" && inw && !wq && (wd ~ /^[0-9]+$/ || (ps && wd == "*"))) { wd = ""; inw = 0 } # 2> and *>: a file descriptor
      else endword()
      if (ch == "&") { i++; ch = ">" } # &> and &>>
      t = substr(c, i + 1, 1)
      if (ch == "<" && t == "<" && !ps) {
        if (substr(c, i + 2, 1) == "<") { i += 3; rd = 2 } # <<< is data
        else { i += 2; hdtab = (substr(c, i, 1) == "-"); if (hdtab) i++; rd = 3 }
      } else if (ch == ">") {
        rd = 1
        if (t == ">" || t == "|") i += 2
        else if (t == "&") { i += 2; rd = 4 }
        else i++
      } else {
        rd = 2
        if (t == "&") i += 2
        else if (t == ">") { i += 2; rd = 1 }
        else i++
      }
    } else { wd = wd ch; inw = 1; i++ }
  }
  endword(); endcmd()
}
function lines(c,   n) { n = split(c, lt, "\n"); if (substr(c, length(c)) == "\n") n--; return n }
function shell(c, ps) {
  if (length(c) > 131072) return TOOLONG
  c = dec(c)
  if (uesc) return USC
  if (length(c) > 65536 || lines(c) > 2000) return TOOLONG
  push(tolower(c), ps)
  for (qi = 1; qi <= qn && hitv == ""; qi++) walk(qt[qi], qp[qi])
  return hitv == "" ? "ok" : "risky " hitv
}

# ---- the verdict
function filetool(p,   rel, h) {
  p = dec(p)
  if (uesc) return USC
  p = norm(p)
  if (p !~ /^(\/|[a-z]:)/) p = base "/" p
  p = canon(p)
  if (index(p "/", base "/") != 1) return "ok"
  rel = substr(p, length(base) + 2)
  if (rel ~ /^specs\//) return "specs"
  h = risky(rel)
  return h == "" ? "ok" : "risky " rel " (matches " h ")"
}

{ json = json (NR > 1 ? "\n" : "") $0 }
END {
  TOOLONG = "cannot this command is too long for the guard (over 64 KB or 2,000 lines). Write the file with the Write tool"
  USC = "cannot the input has a \\u escape, which the guard cannot check"
  set(SK, "sudo env command exec nohup builtin xargs time if then else elif do while until ! { }")
  set(SP, "sudo env command exec nohup builtin xargs time")
  set(WR, "rm rmdir mv touch truncate tee patch shred unlink set-content add-content out-file new-item remove-item move-item rename-item clear-content tee-object sc ac ni ri rni ren mi move del erase rd clc")
  set(DST, "cp ln install copy-item cpi copy")
  set(SHELL, "sh bash dash zsh ksh")
  set(GIT, "apply rm mv restore")
  load(ENVIRON["RAS_RISKY"])
  parse(json)
  if (index(raw["session_id"], "\n")) fail("a newline in session_id")
  base = canon(norm(ENVIRON["CLAUDE_PROJECT_DIR"]))
  tool = raw["tool_name"]
  if (tool == "Bash" || tool == "PowerShell") {
    v = "ok"
    if (raw["command"] != "") v = shell(raw["command"], tool == "PowerShell")
  } else {
    p = raw["file_path"]; if (p == "") p = raw["notebook_path"]
    v = (p == "") ? "cannot no file_path in the tool input" : filetool(p)
  }
  gsub("\n", " ", v)
  print raw["session_id"]
  print v
}
