#!/usr/bin/env bash
# Purpose: count term_keep, ctr_take and rfc_seal per def in Bend's emitted C,
#   optionally selecting exact FIDs, literal FID prefixes, or defs of named
#   files at the greatest import-path depth, and comparing with a baseline.
# Expected output: with one argument, the counts in baseline form; with two,
#   "rc: <n> defs equal <baseline>", or each differing def and exit 1.
# Run: rc.sh build/app.c [bench/rc.txt] [--fid FID_MAIN_FOO]
#   [--fid-prefix FID_MAIN_] [--deepest-file CLI]
#
# A def's counts cover its segment, its continuations (FID_<def>_K<n>, which
# follow it), and each spin helper they call, once per call site and expanded
# through the spins that spin calls. Spin numbers change between builds, so a
# spin counts only toward its callers.
# Bend encodes each "../" in an import path as three underscores after FID_.
# --deepest-file NAME keeps the greatest path depth across all named files
# and prints their FIDs without the path prefix, for comparable counts across
# harnesses. Supplying related file names together excludes shallower defs
# whose names merely share a file prefix. At depth 0, a local cli_foo def
# cannot be distinguished from a def of cli.bend by FID alone.
set -euo pipefail
BEND_TOOLS_PIN=2.0.36
# shellcheck source=.bend-version.sh
source "$(dirname "${BASH_SOURCE[0]}")/.bend-version.sh"
bend_tools_warn_version "$BEND_TOOLS_PIN" "$(basename "$0")"

usage() {
  echo 'usage: rc.sh <file.c> [baseline] [--fid FID_NAME]... [--fid-prefix FID_PREFIX]... [--deepest-file NAME]...' >&2
  exit 2
}

[ $# -ge 1 ] || usage
source_file=$1
shift
[ -r "$source_file" ] || { echo "rc: cannot read $source_file" >&2; exit 2; }

baseline=
if [ $# -gt 0 ] && [[ $1 != --* ]]; then
  baseline=$1
  shift
  [ -r "$baseline" ] || { echo "rc: cannot read $baseline" >&2; exit 2; }
fi

fids='' prefixes='' deepest_files=''
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case $1 in
    --fid)
      [[ $2 =~ ^FID_[A-Z0-9_]+$ ]] || usage
      fids="$fids $2" ;;
    --fid-prefix)
      [[ $2 =~ ^FID_[A-Z0-9_]+$ ]] || usage
      prefixes="$prefixes $2" ;;
    --deepest-file)
      [[ $2 =~ ^[A-Z][A-Z0-9_]*$ ]] || usage
      deepest_files="$deepest_files $2" ;;
    *) usage ;;
  esac
  shift 2
done
[ -z "$deepest_files" ] || [ -z "$fids$prefixes" ] || usage

counts=$(LC_ALL=C awk -v fids="$fids" -v prefixes="$prefixes" -v deepest_files="$deepest_files" '
  function wanted(fid,   i, d, pattern) {
    if (file_count) {
      for (i = 1; i <= file_count; i++) {
        pattern = "^FID_(___)*" file[i] "_"
        if (match(fid, pattern)) {
          d = (RLENGTH - 5 - length(file[i])) / 3
          file_depth[fid] = d
          if (d > max_depth) max_depth = d
          return 1
        }
      }
      return 0
    }
    if (fid_count + prefix_count == 0) return 1
    for (i = 1; i <= fid_count; i++) if (fid == exact[i]) return 1
    for (i = 1; i <= prefix_count; i++)
      if (index(fid, prefix[i]) == 1) return 1
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
    sub(/^ /, "", fids); sub(/^ /, "", prefixes); sub(/^ /, "", deepest_files)
    if (fids != "") fid_count = split(fids, exact, " ")
    if (prefixes != "") prefix_count = split(prefixes, prefix, " ")
    if (deepest_files != "") file_count = split(deepest_files, file, " ")
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
      if (file_count && file_depth[u] != max_depth) continue
      name = file_count ? "FID_" substr(u, 5 + 3 * file_depth[u]) : u
      if (seen_name[name]++) {
        print "rc: ambiguous normalized FID " name > "/dev/stderr"
        exit 2
      }
      for (k = 1; k <= 3; k++) t[k] = n[u, k]
      m = split(calls[u], c, " ")
      for (i = 1; i <= m; i++) {
        expand(c[i])
        for (k = 1; k <= 3; k++) t[k] += x[c[i], k]
      }
      printf "%s %d %d %d\n", name, t[1], t[2], t[3]
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
