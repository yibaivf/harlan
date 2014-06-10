#!/usr/bin/python

"""This runs the benchmarks from the OOPSLA paper and graphs the
results. This script should be run from the Harlan root directory.
"""

import os
import subprocess
import re

# Start off by building the tests.
#os.system("./build-benchmarks")

benchmarks = [
    { "name": "bench-add-vector.kfc",
      "args": [str(x) for x in xrange(1, 90)] },
    { "name": "bench-dot-prod.kfc",
      "args": [""] }
]

def run_bench(benchmark):
    name = benchmark["name"]
    args = benchmark["args"]

    print "Running benchmark " + name
    
    exe = "./test.bin/" + name + ".bin"
    out = "./test.bin/" + name + ".dat"

    out = open(out, "w")

    for arg in args:
        result = subprocess.check_output([exe, arg], stderr = subprocess.PIPE)

        match = re.search("^SELFTIMED: (.*)$", result, flags=re.MULTILINE)
        if match:
            out.write("{arg:s},{time:s}\n".format(arg=arg, time=match.group(1)))
        else:
            for match in re.finditer("^ARG_AND_TIME: (\d+)\s+(\d+)",
                                     result,
                                     flags=re.MULTILINE):

                sec = float(match.group(2))

                out.write("{arg:s},{time:4f}\n".format(arg=match.group(1),
                                                       time=(sec / 1e6)))

for bench in benchmarks:
    run_bench(bench)
