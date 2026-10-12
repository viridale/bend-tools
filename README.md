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
../bend-tools/rc.sh build/app.c --file MAIN > bench/rc.txt
../bend-tools/rc.sh build/app.c bench/rc.txt --file MAIN
python3 ../bend-tools/charsplit.py OTHER 65 66
```

See each script's header for options. Requirements vary by tool: Bend, Bash 5,
Python 3, `rsync`, and GNU `timeout`. Some scripts replace their own `tmp/`
workspace in the target repo. MIT licensed; see [LICENSE](LICENSE).
