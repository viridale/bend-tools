# bend-tools

Standalone Bend utilities from [bend-cli](https://github.com/viridale/bend-cli).

| Tool | Purpose |
| --- | --- |
| `rc.sh` | Count keep/take/seal calls per def in emitted C. |
| `charsplit.py` | Generate exhaustive `Char` proof match arms. |
| `lawcheck.sh` | Type-check new laws against planned definitions. |
| `perlaw.sh` | Check proof laws separately. |
| `kernel.sh` | Explain a `--verdict` failure. |
| `chk.sh` | Filter expected `--check-only` diagnostics. |
| `bench.sh` | Compare native builds at a base ref and the worktree. |

From a Bend repo next to this checkout:

```sh
../bend-tools/rc.sh build/app.c --fid-prefix FID_MAIN_ > bench/rc.txt
../bend-tools/rc.sh build/app.c bench/rc.txt --fid-prefix FID_MAIN_
python3 ../bend-tools/charsplit.py OTHER 65 66
```

See each script's header for options. Requirements vary by tool: Bend, Bash 5,
Python 3, `rsync`, and GNU `timeout`. Scratch files use unique directories under
the target repo's `tmp/`. `--fid-prefix` is a literal prefix; `--fid` selects
one def exactly. `chk.sh -e` takes a tab-separated file/def allowlist. Run
`python3 test_tools.py` for regression checks. MIT licensed; see [LICENSE](LICENSE).
