#!/usr/bin/env bash
#
# mayhem/test.sh — FUNCTIONAL oracle for pip's requirements parser.
#
# Runs the pre-built /mayhem/oracle_run ELF (built by mayhem/build.sh), which parses a known
# requirements file through pip._internal.req.req_file.parse_requirements and prints the parsed
# result. We assert the parsed VALUES (golden output), not just exit status — so a patch that
# breaks or no-ops the parser changes the output and FAILS here. Emits a CTRF summary.
#
# The oracle deliberately runs THROUGH the /mayhem-rooted ELF shim (not python3 directly): the
# anti-reward-hack sabotage check neuters /mayhem binaries to exit(0), which makes oracle_run
# produce no output and this suite fail — proving the oracle is behavioral.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-${SRC:-/mayhem}/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

ORACLE=/mayhem/oracle_run
if [ ! -x "$ORACLE" ]; then
  echo "FAIL: $ORACLE missing/not executable — mayhem/build.sh did not build the oracle" >&2
  emit_ctrf "pip-reqparse" 0 1 0
  exit $?
fi

out="$("$ORACLE" 2>/dev/null)"

passed=0; failed=0
check() {  # check <description> <expected-line>
  if printf '%s\n' "$out" | grep -qxF "$2"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL [$1]: expected line not found: '$2'" >&2
  fi
}

# Golden assertions on the parsed requirements (comment + blank line skipped -> COUNT 3).
check "count"     "COUNT 3"
check "flask"     "REQ flask==2.0.1"
check "requests"  "REQ requests>=2.25.0"
check "django"    "REQ Django~=4.2"

if [ "$failed" -ne 0 ]; then
  echo "----- oracle output was -----" >&2
  printf '%s\n' "$out" >&2
  echo "-----------------------------" >&2
fi

emit_ctrf "pip-reqparse" "$passed" "$failed" 0
exit $?
