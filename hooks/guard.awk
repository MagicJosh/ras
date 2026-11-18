# guard.awk (ras 6): the PreToolUse check, in one awk process. POSIX awk. Run with LC_ALL=C.
# Reads one hook event (JSON) on stdin and prints two lines: the session id, then a verdict:
#   ok | specs | risky <path> (matches <pattern>) | locked <what> (<why>) | cannot <reason>
# risky needs an approved spec or skip spec. locked and cannot are denied whatever the session approved:
# a locked path holds ras's own state, and a locked command or prompt would type the approval for the user.
# One command can name several targets. The strongest verdict decides, so the walk goes on after a risky hit.
# Exits 1 on input it cannot parse, a bad pattern or an unreadable .ras/risky-paths. The shell then denies.
# Env: CLAUDE_PROJECT_DIR, HOME (or USERPROFILE), and RAS_RISKY = the .ras/risky-paths file when it exists. Strings come in through
# ENVIRON because awk -v would process backslash escapes. Regexes use [.] instead of \. for the same reason.
# A guard rail for the agent, not a sandbox: it reads redirects and the arguments of write commands.
# For rm and mv it also asks git (ls-files, one call) for the tracked files in a folder that the command takes.

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
# Why the repo-relative, lowercase path w is locked, or "". The agent cannot loosen the list or forge a state file.
function locked(w) {
  if (w ~ /(^|\/)[.]ras(\/|$)/ && w !~ /(^|\/)[.]ras\/handoffs(\/|$)/) return ".ras/ holds the risky-path list"
  if (w ~ /(^|\/)[.]claude\/spec[.]/) return ".claude/spec.* holds the approval state"
  if (w ~ /(^|\/)[.]claude$/) return "the .claude folder holds the approval state"
  return ""
}
# Why the lowercase absolute path p under the home folder is risky, or "": user settings and installed plugins.
function homep(p) {
  if (home == "" || index(p "/", home "/") != 1) return ""
  p = substr(p, length(home) + 2)
  if (p ~ /^[.]claude\/settings[^\/]*[.]json$/) return "~/.claude/settings*.json, " OFF
  if (p ~ /^[.]claude\/plugins(\/|$)/) return "~/.claude/plugins/, " OFF
  return ""
}
# Print the pattern that makes the repo-relative, lowercase path w risky. Print nothing if none does.
function risky(w,   k) {
  if (w ~ /(^|\/)[.]claude\/settings[^\/]*[.]json$/) return ".claude/settings*.json, " OFF
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
  K["session_id"] = K["tool_name"] = K["command"] = K["file_path"] = K["notebook_path"] = K["prompt"] = 1
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
# One path word: the first locked one goes to lockv, the first risky one to hitv.
function chk(w,   h, r) {
  if (w == "") return
  r = rel(w)
  if (lockv == "" && !outp && r !~ /^specs\//) { h = locked(r); if (h != "") { lockv = r " (" h ")"; return } }
  if (hitv == "") { h = cand(w); if (h != "") hitv = h }
}
# The path of word w, relative to the project. Sets outp when it is outside: ~ or an absolute path elsewhere.
# Sets pa to the absolute path. ~, $HOME and $env:USERPROFILE at the start stand for the home folder.
function rel(w) {
  outp = 0; pa = ""
  w = norm(w)
  if (w ~ /^(~|[$]home|[$][{]home[}]|[$]env:(userprofile|home))(\/|$)/) {
    if (home == "") { outp = 1; return "" }
    sub(/^[^\/]*/, "", w); w = home w
  }
  if (substr(w, 1, 1) == "~") { outp = 1; return "" }
  if (w ~ /^(\/|[a-z]:\/)/) {
    w = canon(w); pa = w
    if (index(w "/", base "/") != 1) { outp = 1; return "" }
    return substr(w, length(base) + 2)
  }
  pa = canon(base "/" w)
  return canon(w)
}
# One path word. Print "path (matches pattern)" when it is risky.
function cand(w,   h) {
  w = rel(w)
  if (outp) { h = homep(pa); return h == "" ? "" : pa " (matches " h ")" }
  if (w == "" || w ~ /^specs\//) return ""
  h = risky(w)
  if (h == "") h = homep(pa)
  return h == "" ? "" : w " (matches " h ")"
}
# An argument of a write command: an option is no path, but --opt=value and a=value check the value.
function argchk(a) {
  if (cps && a ~ /^-[a-z]+:/) chk(substr(a, index(a, ":") + 1))
  else if (index(a, "=")) chk(substr(a, index(a, "=") + 1))
  else if (a !~ /^-/) chk(a)
}
# s in single quotes for sh. Not gsub: awks differ on backslashes in the replacement text.
function sq(s,   n, i, r) {
  n = split(s, sp, "'"); r = sp[1]
  for (i = 2; i <= n; i++) r = r "'\\''" sp[i]
  return "'" r "'"
}
# Folder candidates: the path arguments from ar[from] on. A mover leaves out the last one, its destination.
# shortcut: mv -t dir a b takes b for the destination and dir for a source, upgrade when an agent moves folders that way
function fold(from, mv,   k, a, p) {
  p = 0
  for (k = from; k <= na; k++) {
    a = ar[k]
    if (a == "" || a ~ /^-/ || index(a, "=")) continue
    if (p) fadd(ar[p])
    p = k
  }
  if (p && !mv) fadd(ar[p])
}
function fadd(w) {
  w = rel(w)
  if (outp || w ~ /^([.][.]|specs)(\/|$)/) return # outside the project, or specs/ (its lines are skipped below)
  fc[++nfc] = (w == "" ? "." : w)
}
# One git call for all candidates: the tracked files below them. The first locked one goes to lockv, the first
# risky one to hitv. Git missing, no repo or an error: nothing.
function fcheck(   gc, i, f, h, in_) {
  gc = "GIT_ICASE_PATHSPECS=1 git -C " sq(ENVIRON["CLAUDE_PROJECT_DIR"]) " -c core.quotepath=false ls-files --"
  for (i = 1; i <= nfc; i++) gc = gc " " sq("./" fc[i])
  gc = gc " 2>/dev/null"
  in_ = ", in a folder that this command removes or moves"
  while ((gc | getline f) > 0) {
    if (f ~ /^".*"$/) f = substr(f, 2, length(f) - 2)
    f = tolower(f)
    if (f ~ /^specs\//) continue
    h = locked(f)
    if (h != "") { lockv = f " (" h ")" in_; break }
    if (hitv == "") { h = risky(f); if (h != "") hitv = f " (matches " h ")" in_ }
  }
  close(gc)
}
# cp, install and mv: the destination, and for a folder destination the folder plus each source name.
# The destination is a folder when -t names it, when it ends in a slash, or when there are several sources.
# Reads aw[], the words in their own case: -t takes a value, -T does not.
# shortcut: cp a.sql db with db a folder is checked as the file db, upgrade when the end-of-turn check lands
function dest(   k, a, d, dir, ns, vopt) {
  vopt = (cmd == "install") ? "mogS" : "S" # the short options that take a value
  d = ""; dir = 0; ns = 0
  for (k = 1; k <= na; k++) {
    a = aw[k]
    if ((a ~ /^-[a-zA-Z]*t$/ || a == "--target-directory") && k < na) { d = aw[++k]; dir = 1 } # -t, also at the end of a group: -vt
    else if (a ~ /^--target-directory=/) { d = substr(a, 20); dir = 1 }
    else if (a ~ /^-[a-zA-Z]$/ && index(vopt, substr(a, 2)) && k < na) k++
    else if (a ~ /^-./) { if (index(a, "=")) chk(substr(a, index(a, "=") + 1)) }
    else src[++ns] = a
  }
  if (!dir) {
    if (!ns) return
    d = src[ns--]; dir = (d ~ /[\/\\]$/ || ns > 1)
  }
  chk(d)
  if (dir) for (k = 1; k <= ns; k++) {
    a = src[k]; gsub(/\\/, "/", a); sub(/\/+$/, "", a); sub(/.*\//, "", a)
    if (a != "") chk(d "/" a)
  }
}
# git checkout: the words after --. Without --, every plain word after the first, which is the branch or commit.
# With -b, -B, --orphan or --track every word is a branch or a start point.
function gco(from,   k, a, dd, p) {
  dd = 0
  for (k = from; k <= na; k++) if (ar[k] == "--") { dd = k; break }
  if (dd) { for (k = dd + 1; k <= na; k++) chk(ar[k]); return }
  for (k = from; k <= na; k++) if (ar[k] ~ /^-(b|t|-orphan|-track)/) return
  p = 0
  for (k = from; k <= na; k++) { a = ar[k]; if (a ~ /^-/) continue; if (p++) chk(a) }
}
# claude: a run that resumes or names a session types into that session, so it is locked. The plugin commands that
# remove or disable a plugin can turn ras off, so they are risky.
function claude(   k, a, s) {
  for (k = 1; k <= na; k++) {
    a = aw[k]
    if (a ~ /^--(continue|resume|session-id|from-pr|teleport)(=|$)/ || a ~ /^-[a-z]*[cr][a-z]*$/ || (k == 1 && a ~ /^(attach|respawn)$/)) {
      if (lockv == "") lockv = "claude " a " (it types into a session, and only the user approves or skips)"
      return
    }
  }
  if (na < 2 || ar[1] !~ /^plugins?$/) return
  s = ar[2]
  if (s == "marketplace" && na > 2) s = s " " ar[3]
  if (hitv == "" && s ~ /^(disable|uninstall|remove|rm|marketplace (remove|rm))$/) hitv = "claude plugin " s " (matches a command that " OFF ")"
}
# The simple command is complete: check its arguments by the command word.
function evalcmd(   k, a, last, g, s, j) {
  if (cmd in WR) {
    for (k = 1; k <= na; k++) argchk(ar[k])
    if (cmd in DEL || cmd in MOV) fold(1, cmd in MOV)
    if (cmd == "mv") dest()
    return
  }
  # Copies check the destination only: reading a risky file into another file passes.
  if (cmd in PCP || (cps && cmd == "cp")) { # Copy-Item, and cp is its alias in PowerShell: the -Destination value, else the last plain word
    g = ""; last = ""
    for (k = 1; k <= na; k++) {
      a = ar[k]
      if (a ~ /^-des[a-z]*:/) g = substr(a, index(a, ":") + 1)
      else if (a ~ /^-des[a-z]*$/ && k < na) g = ar[++k]
      else if (a !~ /^-/) last = a
    }
    chk(g != "" ? g : last); return
  }
  if (cmd == "cp" || cmd == "install") { dest(); return }
  if (cmd == "claude" || cmd == "claude-code") { claude(); return }
  if (cmd == "dd") { for (k = 1; k <= na; k++) if (ar[k] ~ /^of=/) chk(substr(ar[k], 4)); return }
  if (cmd == "sed" || cmd == "perl") {
    g = 0
    for (k = 1; k <= na; k++) if (ar[k] ~ /^-[a-z]*i/ || ar[k] ~ /^--in-place/) g = 1
    if (g) for (k = 1; k <= na; k++) argchk(ar[k])
    return
  }
  if (cmd == "git") { # git -c x=y -C dir <sub> ...
    g = ""
    for (k = 1; k <= na; k++) {
      a = ar[k]
      if (g != "") argchk(a)
      else if (a == "-c") k++
      else if (a !~ /^-/) {
        g = a
        if (g == "checkout") { gco(k + 1); return }
        if (!(g in GIT)) return
        if (g == "rm" || g == "mv") fold(k + 1, g == "mv")
      }
    }
    return
  }
  if (cmd in SHELL) { for (k = 1; k < na; k++) if (ar[k] ~ /^-[a-z]*c$/) { push(aw[k + 1], 0); return }; return }
  if (cmd == "pwsh" || cmd == "powershell") {
    for (k = 1; k <= na; k++) if (ar[k] == "-c" || ar[k] == "-command") {
      s = ""
      for (j = k + 1; j <= na; j++) s = s (j > k + 1 ? " " : "") aw[j]
      if (s != "") push(s, 1)
      return
    }
    return
  }
  if (cmd == "eval" && na > 0) { s = aw[1]; for (k = 2; k <= na; k++) s = s " " aw[k]; push(s, 0) }
}
function endcmd(   k) {
  if (cmd != "") evalcmd()
  if (cmd in SHELL) for (k = hd0; k <= hdn; k++) hds[k] = 1 # a heredoc fed to a shell is a script
  hd0 = hdn + 1; cmd = ""; pre = 0; na = 0
}
# ar[] holds the arguments in lower case, because PowerShell and Windows paths ignore case. aw[] keeps their own case.
function word(w,   b, lw) {
  lw = tolower(w)
  if (cmd != "") { ar[++na] = lw; aw[na] = w; return }
  if (lw ~ /^[a-z_][a-z0-9_]*=/) return
  if (pre && w ~ /^-/) return # shortcut: options of sudo, env and friends that take a value (sudo -u root) are not skipped, upgrade when such a call slips through
  b = lw; gsub(/\\/, "/", b); sub(/.*\//, "", b); sub(/[.](exe|cmd)$/, "", b)
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
  while (i <= n && lockv == "") {
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
  push(c, ps)
  for (qi = 1; qi <= qn && lockv == ""; qi++) walk(qt[qi], qp[qi])
  if (lockv == "" && nfc) fcheck()
  if (lockv != "") return "locked " lockv
  return hitv == "" ? "ok" : "risky " hitv
}
# A prompt that CronCreate or ScheduleWakeup would send later. It arrives as a user prompt, so one that holds
# the approval or the skip phrase would approve for the user. Looser than the prompt hook on purpose.
function sched(p) {
  if (length(p) > 65536) return "cannot this scheduled prompt is too long for the guard (over 64 KB)"
  p = tolower(dec(p))
  if (uesc) return USC
  gsub(/[^a-z]/, "", p)
  if (index(p, "approvespec") || index(p, "skipspec")) return "locked a scheduled prompt that reads approve spec or skip spec (only the user types those)"
  return "ok"
}

# ---- the verdict
function filetool(p,   rel, h) {
  p = dec(p)
  if (uesc) return USC
  p = norm(p)
  if (p ~ /^~\// && home != "") p = home substr(p, 2)
  if (p !~ /^(\/|[a-z]:)/) p = base "/" p
  p = canon(p)
  if (index(p "/", base "/") != 1) { h = homep(p); return h == "" ? "ok" : "risky " p " (matches " h ")" }
  rel = substr(p, length(base) + 2)
  if (rel ~ /^specs\//) return "specs"
  h = locked(rel)
  if (h != "") return "locked " rel " (" h ")"
  h = risky(rel)
  if (h == "") h = homep(p)
  return h == "" ? "ok" : "risky " rel " (matches " h ")"
}

{ json = json (NR > 1 ? "\n" : "") $0 }
END {
  TOOLONG = "cannot this command is too long for the guard (over 64 KB or 2,000 lines). Write the file with the Write tool"
  USC = "cannot the input has a \\u escape, which the guard cannot check"
  set(SK, "sudo env command exec nohup builtin xargs time npx bunx if then else elif do while until ! { }")
  set(SP, "sudo env command exec nohup builtin xargs time npx bunx")
  OFF = "which can turn ras off"
  set(WR, "rm rmdir mv ln touch truncate tee patch shred unlink set-content add-content out-file new-item remove-item move-item rename-item clear-content tee-object sc ac ni ri rni ren mi move del erase rd clc")
  set(PCP, "copy-item cpi copy")
  set(DEL, "rm rmdir unlink remove-item ri del erase rd")
  set(MOV, "mv move-item mi move rename-item rni ren")
  set(SHELL, "sh bash dash zsh ksh")
  set(GIT, "apply rm mv restore")
  load(ENVIRON["RAS_RISKY"])
  parse(json)
  if (index(raw["session_id"], "\n")) fail("a newline in session_id")
  base = canon(norm(ENVIRON["CLAUDE_PROJECT_DIR"]))
  home = ENVIRON["HOME"]; if (home == "") home = ENVIRON["USERPROFILE"]
  home = canon(norm(home)); if (home == "/") home = ""
  tool = raw["tool_name"]
  if (tool == "Bash" || tool == "PowerShell" || tool == "Monitor") { # a Monitor command runs in the Bash shell
    v = "ok"
    if (raw["command"] != "") v = shell(raw["command"], tool == "PowerShell")
  } else if (tool == "CronCreate" || tool == "ScheduleWakeup") {
    v = ("prompt" in raw) ? sched(raw["prompt"]) : "cannot no prompt in the tool input"
  } else {
    p = raw["file_path"]; if (p == "") p = raw["notebook_path"]
    v = (p == "") ? "cannot no file_path in the tool input" : filetool(p)
  }
  gsub("\n", " ", v)
  print raw["session_id"]
  print v
}
