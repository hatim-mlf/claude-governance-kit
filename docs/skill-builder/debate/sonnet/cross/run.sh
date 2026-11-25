#!/bin/bash
# run from cross/: both lints on every fixture; no-pyyaml runs with the yaml import blocked
for f in fixtures/*/; do n=$(basename $f); pre=""; [ "$n" = no-pyyaml ] && pre="env PYTHONPATH=/tmp/noyaml"
 o=$($pre python3 ../other/lint_skill.py $f 2>&1); orc=$?
 m=$($pre python3 ../proposal/lint_skill.py $f 2>&1); mrc=$?
 echo "### $n"; echo "other rc=$orc: $(echo "$o"|head -1)"; echo "mine  rc=$mrc: $(echo "$m"|grep -v '^WARN'|head -1)"
done
