#!/usr/bin/env bash
# Purpose: count term_keep, ctr_take and rfc_seal per def in Bend's emitted C,
#   optionally selecting source files and comparing with a baseline.
# Expected output: with one argument, the counts in baseline form; with two,
#   "rc: <n> defs equal <baseline>", or each differing def and exit 1.
# Run: rc.sh build/app.c [bench/rc.txt] [--file MAIN] [--file LIB]
#
# A def's counts cover its segment, its continuations (FID_<def>_K<n>, which
# follow it), and each spin helper they call, once per call site and expanded
# through the spins that spin calls. Spin numbers change between builds, so a
# spin counts only toward its callers.
set -euo pipefail

usage() {
  echo 'usage: rc.sh <file.c> [baseline] [--file SOURCE_NAME]...' >&2
  exit 2
}

[ $# -ge 1 ] || usage
source_file=$1
shift
[ -r "$source_file" ] || { echo "rc: cannot read $source_file" >&2; exit 2; }

baseline=
if [ $# -gt 0 ] && [ "$1" != --file ]; then
  baseline=$1
  shift
  [ -r "$baseline" ] || { echo "rc: cannot read $baseline" >&2; exit 2; }
fi

files=
while [ $# -gt 0 ]; do
  [ "$1" = --file ] && [ $# -ge 2 ] || usage
  [[ "$2" =~ ^[A-Z][A-Z0-9_]*$ ]] || usage
  files="$files $2"
  shift 2
done

counts=$(LC_ALL=C awk -v files="$files" '
  function wanted(fid,   i) {
    if (file_count == 0) return 1
    for (i = 1; i <= file_count; i++)
      if (index(fid, "FID_" file[i] "_") == 1) return 1
    return 0
  }
  function scan(line, unit,   k, t, s) {
    for (k = 1; k <= 3; k++) {
      t = " " line
      while (match(t, "[^A-Za-z0-9_]" op[k] "\\(")) {
        n[unit, k]++
        t = substr(t, RSTART + RLENGTH - 1)
      }
    }
    t = " " line
    while (match(t, "[^A-Za-z0-9_]spin_[0-9]+\\(")) {
      s = substr(t, RSTART + 1, RLENGTH - 2)
      if (s != unit) calls[unit] = calls[unit] " " s
      t = substr(t, RSTART + RLENGTH - 1)
    }
  }
  function expand(s,   k, i, m, c) {
    if (state[s] == 2) return
    if (!(s in spin) || state[s] == 1) {
      print "rc: cannot expand " s > "/dev/stderr"
      exit 2
    }
    state[s] = 1
    for (k = 1; k <= 3; k++) x[s, k] = n[s, k]
    m = split(calls[s], c, " ")
    for (i = 1; i <= m; i++) {
      expand(c[i])
      for (k = 1; k <= 3; k++) x[s, k] += x[c[i], k]
    }
    state[s] = 2
  }
  BEGIN {
    op[1] = "term_keep"; op[2] = "ctr_take"; op[3] = "rfc_seal"
    sub(/^ /, "", files)
    if (files != "") file_count = split(files, file, " ")
  }
  /^\/\/ =+$/ && prev ~ /^\/\/ [A-Z][A-Za-z0-9]*$/ {
    sec = substr(prev, 4); seen[sec] = 1; unit = ""
  }
  sec == "Spins" && /^[A-Z][A-Za-z_ ]* spin_[0-9]+\(/ {
    match($0, /spin_[0-9]+/); unit = substr($0, RSTART, RLENGTH); spin[unit] = 1
  }
  sec == "Spins" && /^}/ { unit = "" }
  sec == "Segments" && match($0, /WL_CASE\(FID_[A-Z0-9_]+\)/) {
    f = substr($0, RSTART + 8, RLENGTH - 9); b = f; sub(/_K[0-9]+$/, "", b)
    if (b != def) def = f
    unit = wanted(def) ? def : ""
    if (unit != "") own[unit] = 1
  }
  unit != "" { scan($0, unit) }
  { prev = $0 }
  END {
    if (!("Segments" in seen)) {
      print "rc: no // Segments section in " FILENAME > "/dev/stderr"
      exit 2
    }
    for (u in own) {
      for (k = 1; k <= 3; k++) t[k] = n[u, k]
      m = split(calls[u], c, " ")
      for (i = 1; i <= m; i++) {
        expand(c[i])
        for (k = 1; k <= 3; k++) t[k] += x[c[i], k]
      }
      printf "%s %d %d %d\n", u, t[1], t[2], t[3]
    }
  }
' "$source_file" | LC_ALL=C sort)

if [ -z "$baseline" ]; then
  echo '# FID term_keep ctr_take rfc_seal'
  [ -z "$counts" ] || printf '%s\n' "$counts"
  exit 0
fi

printf '%s\n' "$counts" | awk -v base="$baseline" -v c="$source_file" '
  BEGIN {
    while ((getline l < base) > 0) {
      if (l ~ /^[ \t]*(#|$)/) continue
      if (split(l, f, " ") != 4) { print "rc: bad line in " base ": " l > "/dev/stderr"; err = 1; exit 2 }
      want[f[1]] = f[2] " " f[3] " " f[4]; order[++nb] = f[1]
    }
  }
  NF != 4 { next }
  {
    have = $2 " " $3 " " $4; defs++
    if (!($1 in want)) { print "new  " $1 " " have; bad = 1; next }
    split(want[$1], w, " ")
    if ($2 > w[1] || $3 > w[2] || $4 > w[3]) print "rise " $1 " " want[$1] " -> " have
    else if (have != want[$1]) print "fall " $1 " " want[$1] " -> " have
    if (have != want[$1]) bad = 1
    delete want[$1]
  }
  END {
    if (err) exit 2
    for (i = 1; i <= nb; i++)
      if (order[i] in want) { print "gone " order[i] " " want[order[i]]; bad = 1 }
    if (bad) {
      print "rc: counts differ from " base "; review changes before regenerating the baseline"
      exit 1
    }
    print "rc: " defs + 0 " defs equal " base
  }
'
