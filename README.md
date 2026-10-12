# bend-tools

Small utilities for developing Bend repositories. Each tool is standalone; no
package installation is needed. The repository starts with tools brought over
from [bend-cli](https://github.com/viridale/bend-cli).

## `rc.sh`

Counts `term_keep`, `ctr_take`, and `rfc_seal` calls per Bend def in emitted C.
It includes a def's continuations and expands its spin helpers. A first run
prints a baseline; a run with a baseline path reports changes and exits with
status 1 when counts differ.

```sh
./rc.sh build/app.c --file MAIN --file LIB > bench/rc.txt
./rc.sh build/app.c bench/rc.txt --file MAIN --file LIB
```

`--file` takes the uppercase source filename used in emitted `FID_` names,
without `.bend` (for example, `MAIN` for `main.bend`). Repeat it to select
multiple files. Without `--file`, all emitted defs are counted. The script
requires Bash and awk.

## `charsplit.py`

Prints exhaustive `match c:` arms for a Bend `Char` view proof. Pass the
expression to use for all other characters, followed by decimal Unicode
code points in the order required by the proof's sum type.

```sh
python3 charsplit.py 'OTHER' 65 66
```

The generated arms are meant to be pasted into a proof and checked with Bend.
The script requires Python 3.

## Origin and license

Both tools were copied from `bend-cli` under its MIT license. The original
copyright notice is retained in [LICENSE](LICENSE).
