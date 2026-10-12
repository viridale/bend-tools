# bend-tools

Standalone utilities for Bend repositories, originally from
[bend-cli](https://github.com/viridale/bend-cli).

## `rc.sh`

Count `term_keep`, `ctr_take`, and `rfc_seal` per def in Bend-generated C.
`--file` selects source files by uppercase name; omit it to count all defs.

```sh
./rc.sh build/app.c --file MAIN > bench/rc.txt
./rc.sh build/app.c bench/rc.txt --file MAIN
```

The first command saves a baseline; the second compares against it.

## `charsplit.py`

Generate exhaustive `match c:` arms for a `Char` proof from a fallback
expression and decimal code points:

```sh
python3 charsplit.py OTHER 65 66
```

MIT licensed; see [LICENSE](LICENSE).
