/*
 * launcher.c — a tiny native ELF shim for an Atheris (Python) fuzz/oracle entry point.
 *
 * Why this exists: Mayhem (and the integration gate's fuzz-smoke / DWARF checks) require the
 * target command to be a real ELF binary, not a shell/script wrapper, and to carry DWARF<4
 * debug info. A bare `python3 harness.py` command is a script invocation, not an ELF. This shim
 * is compiled with clang + $DEBUG_FLAGS (-gdwarf-3) so it is an ELF with DWARF<4, then it simply
 * exec()s the CPython interpreter on the baked-in harness script, forwarding any libFuzzer args.
 * Atheris drives libFuzzer underneath, so the resulting process iterates exactly like a native
 * libFuzzer target.
 *
 * PYSCRIPT is set at compile time (-DPYSCRIPT='"/mayhem/mayhem/<script>.py"'). PYTHONPATH is
 * pointed at the in-tree pip source so the harness imports the pip-under-test without an install.
 */
#include <unistd.h>
#include <stdlib.h>

#ifndef PYSCRIPT
#define PYSCRIPT "/mayhem/mayhem/fuzz_requirements.py"
#endif

int main(int argc, char **argv) {
    /* Import the pip sources that live in the checkout (additive: no install needed). */
    setenv("PYTHONPATH", "/mayhem/src", 1);

    char *args[1024];
    int n = 0;
    args[n++] = "python3";
    args[n++] = (char *)PYSCRIPT;
    for (int i = 1; i < argc && n < 1022; i++)
        args[n++] = argv[i];
    args[n] = (char *)0;

    execvp("python3", args);
    /* Only reached if exec fails. */
    return 127;
}
