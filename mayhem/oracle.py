#!/usr/bin/python3
# oracle.py — deterministic driver for pip's requirements parser, used by mayhem/test.sh as the
# FUNCTIONAL oracle. It parses a fixed requirements file through the SAME code path the fuzz
# harness exercises (pip._internal.req.req_file.parse_requirements) and prints the parsed result
# in a stable, assertable form. test.sh compares the output against golden values, so a patch that
# breaks (or no-ops) the parser changes the output and FAILS the oracle.
import os
import sys
import tempfile

# Import the pip-under-test from the checkout source (also set on PYTHONPATH by the launcher).
sys.path.insert(0, "/mayhem/src")

from pip._internal.req.req_file import parse_requirements
from pip._internal.network.session import PipSession

# A known requirements file: three real requirements plus a comment and a blank line (which the
# parser must skip). The parsed `.requirement` strings are deterministic.
CONTENT = "flask==2.0.1\nrequests>=2.25.0\n# a comment line\n\nDjango~=4.2\n"


def main():
    path = os.path.join(tempfile.gettempdir(), "pip_oracle_requirements.txt")
    with open(path, "w") as fd:
        fd.write(CONTENT)
    parsed = list(
        parse_requirements(
            path,
            PipSession(),
            finder=None,
            options=None,
            constraint=None,
        )
    )
    print("COUNT", len(parsed))
    for item in parsed:
        print("REQ", item.requirement)


if __name__ == "__main__":
    main()
