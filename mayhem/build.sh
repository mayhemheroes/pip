#!/usr/bin/env bash
#
# mayhem/build.sh — build the Atheris (Python) fuzz target(s) for pip.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# (ghcr.io/mayhemheroes/base) exports the build contract (CC, SANITIZER_FLAGS, DEBUG_FLAGS, SRC, …).
#
# NOTE on $SANITIZER_FLAGS: the fuzzed code here is PYTHON (pip), not C. Coverage and bug detection
# come from Atheris (atheris.instrument_all / instrument_func) and Python's own exceptions, so the
# C/C++ sanitizer flags do not apply to the harnessed code — there is no native pip object to
# instrument. We still honor the build contract: Atheris is installed from a baked, offline
# wheelhouse (see mayhem/Dockerfile), pip-under-test is imported from the in-tree source, and the
# native libFuzzer ELF shims below carry $DEBUG_FLAGS (DWARF<4) so Mayhem can triage them.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs from the ENVIRONMENT, with sane fallbacks (parameter expansion, no if-statements).
# SANITIZER_FLAGS uses `=` (not `:=`) so an explicit empty --build-arg is honored; referenced here
# to satisfy the contract even though it does not apply to the Python target (see NOTE above).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS carries DWARF debug info; DWARF MUST be < 4 (Mayhem triage can't read >=4), so the
# explicit -gdwarf-3 (clang-19's plain -g emits DWARF-5). Applied to the native launcher shims.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC MAYHEM_JOBS

SRC="${SRC:-/mayhem}"
cd "$SRC"

# 1) Atheris is installed system-wide from the baked wheelhouse by the Dockerfile (online, once).
#    Re-assert it here from the OFFLINE wheelhouse so build.sh is self-contained and the air-gapped
#    re-run stays a no-op when it is already present (idempotent + air-gapped — SPEC §6.5).
if ! python3 -c 'import atheris' >/dev/null 2>&1; then
  python3 -m pip install --break-system-packages --no-index --find-links=/opt/wheelhouse atheris
fi

# 2) Build a native ELF launcher per Python entry point. Each is a tiny clang-compiled shim
#    (ELF + DWARF<4 via $DEBUG_FLAGS) that exec()s python3 on the baked-in script. As an ELF
#    (not a script wrapper) Mayhem accepts it as a libFuzzer target; Atheris drives libFuzzer
#    underneath so it iterates like a native fuzzer.
$CC $DEBUG_FLAGS -O1 -DPYSCRIPT='"/mayhem/mayhem/fuzz_requirements.py"' \
    "$SRC/mayhem/launcher.c" -o /mayhem/fuzz_requirements

# Standalone reproducer: the same ELF, run on a single input file, replays one input once
# (libFuzzer single-input mode) and crashes naturally — a non-fuzzer repro artifact.
cp -f /mayhem/fuzz_requirements /mayhem/fuzz_requirements-standalone

# Oracle driver shim, used only by mayhem/test.sh (a /mayhem-rooted ELF so the anti-reward-hack
# sabotage check can neuter it).
$CC $DEBUG_FLAGS -O1 -DPYSCRIPT='"/mayhem/mayhem/oracle.py"' \
    "$SRC/mayhem/launcher.c" -o /mayhem/oracle_run

echo "build.sh: built /mayhem/fuzz_requirements (+ -standalone) and /mayhem/oracle_run"
