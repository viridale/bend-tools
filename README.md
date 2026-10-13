# bend-tools

| Tool | Purpose |
| --- | --- |
| `rc.sh` | Count keep/take/seal calls per def in emitted C. |
| `charsplit.py` | Generate exhaustive `Char` proof match arms. |
| `ctorarms.py` | Generate proof match arms for a Bend type's constructors. |
| `lawcheck.sh` | Type-check new laws against planned definitions. |
| `perlaw.sh` | Check proof laws separately. |
| `kernel.sh` | Explain a `--verdict` failure. |
| `chk.sh` | Filter expected `--check-only` diagnostics. |
| `bench.sh` | Compare native builds at a base ref and the worktree. |

From a Bend repo next to this checkout:

```sh
../bend-tools/rc.sh build/app.c --fid-prefix FID_MAIN_ > bench/rc.txt
../bend-tools/rc.sh build/app.c bench/rc.txt --fid-prefix FID_MAIN_
../bend-tools/rc.sh build/bench.c --deepest-file CLI --deepest-file RUN
python3 ../bend-tools/charsplit.py OTHER 65 66
python3 ../bend-tools/ctorarms.py --prefix Cli. cli.bend Item '$P <> tail' '{==}'
```

See each script's header for options. Requirements vary by tool: Bend, Bash 5,
Python 3, `curl`, `rsync`, and GNU `timeout`. Each tool pins Bend 2.0.36 and
warns when the installed version or latest GitHub release differs. The release
check is cached for a day and never blocks the tool. Scratch files use unique
directories under the target repo's `tmp/`. `--fid-prefix` is a literal prefix;
`--fid` selects one def exactly. `--deepest-file` uses FID naming to select
named basenames at the greatest import-path depth and normalize their FIDs;
depth-zero names can be ambiguous. It cannot be mixed with the literal FID
selectors. `rc.sh` folds numbered `_C` closures and `_K` continuations into
their parent def. `chk.sh -e` takes a tab-separated file/def allowlist. Run
`python3 test_tools.py` for regression checks. MIT licensed; see [LICENSE](LICENSE).
