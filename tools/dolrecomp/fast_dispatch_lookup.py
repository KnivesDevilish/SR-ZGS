#!/usr/bin/env python3
"""SR-Source: find the recompiled function for an address in a few steps.

    python3 tools/dolrecomp/fast_dispatch_lookup.py src/recompiled/<GAME_ID>

Every time the chassis (or an indirect branch in recompiled code) jumps to a
game address, dolrecomp_find_original() in generated.h finds the function that
holds it. DolRecomp writes it as one test per run of equal-sized functions,
one after another. The C backend's functions are all the same size, so that
is a single test. The LLVM backend's follow the game's functions, all of
different sizes, so it is one test per function: in Zero Gravity, 14383 tests
for an address near the end. That lookup took 78% of the CPU thread.

This script keeps that function, renamed dolrecomp_find_original_linear (the
module template reads the code ranges out of it), and writes a new
dolrecomp_find_original() over sorted tables: the address's 256-byte page
gives the few runs that can hold it, and a binary search among them finds
the one. Same answers, for every address.

DolRecomp's own DOLRECOMP_DISPATCH_LOOKUP=indexed does much the same, but the
module template can't read the code ranges out of what it writes.

Edits generated.h in place and can be run again: a header it already changed
is left as it is. tools/dolrecomp/recompile.sh runs it on every LLVM
recompilation. If the lookup isn't in the shape it knows, it changes nothing
and says so: the module still works, only slower.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MARK = "/* SR-Source: fast dispatch lookup, tools/dolrecomp/fast_dispatch_lookup.py */"
PAGE_SHIFT = 8

FUNCTION_START = re.compile(
    r"^static inline DolRecompFunction dolrecomp_find_original(?P<suffix>\w*)\(u32 address\) \{\n",
    re.MULTILINE,
)
GROUP = re.compile(
    r"\{\s*u32 offset = address - 0x(?P<base>[0-9A-Fa-f]{8})u;\s*"
    r"if \(offset < 0x(?P<span>[0-9A-Fa-f]{8})u && \(offset & 3u\) == 0u\) \{\s*"
    r"static const DolRecompFunction chunk_functions\[\] = \{(?P<funcs>[^}]*)\};\s*"
    r"return chunk_functions\[offset / 0x(?P<stride>[0-9A-Fa-f]{8})u\];\s*\}\s*\}"
)
SINGLE = re.compile(
    r"if \(address >= 0x(?P<start>[0-9A-Fa-f]{8})u && address < 0x(?P<end>[0-9A-Fa-f]{8})u && "
    r"\(\(address - 0x(?P=start)u\) & 3u\) == 0u\) return (?P<func>\w+);"
)
FUNC_NAME = re.compile(r"\w+")


class Unknown(Exception):
    pass


def parse_body(body: str) -> list[tuple[int, int, int, list[str]]]:
    """Runs (start, end, stride, functions) of one linear lookup, in order."""
    runs = []
    position = 0
    while True:
        rest = body[position:]
        stripped = rest.lstrip()
        position += len(rest) - len(stripped)
        if stripped.startswith("return NULL;"):
            if stripped[len("return NULL;"):].strip():
                raise Unknown("text after 'return NULL;'")
            break
        group = GROUP.match(body, position)
        if group:
            base = int(group["base"], 16)
            stride = int(group["stride"], 16)
            funcs = FUNC_NAME.findall(group["funcs"])
            span = int(group["span"], 16)
            if not funcs or stride == 0 or stride % 4 or span > len(funcs) * stride:
                raise Unknown(f"odd run at 0x{base:08X}")
            runs.append((base, base + span, stride, funcs))
            position = group.end()
            continue
        single = SINGLE.match(body, position)
        if single:
            start = int(single["start"], 16)
            end = int(single["end"], 16)
            if end <= start:
                raise Unknown(f"empty range at 0x{start:08X}")
            runs.append((start, end, end - start, [single["func"]]))
            position = single.end()
            continue
        raise Unknown("unknown line: " + stripped.splitlines()[0][:80])
    runs.sort()
    for previous, current in zip(runs, runs[1:]):
        if current[0] < previous[1]:
            raise Unknown(f"overlapping runs at 0x{current[0]:08X}")
    if not runs:
        raise Unknown("no runs")
    return runs


def table(name: str, kind: str, values: list[str]) -> str:
    lines = [f"static const {kind} {name}[{len(values)}] DOLRECOMP_UNUSED = {{"]
    lines += [f"    {value}," for value in values]
    lines.append("};")
    return "\n".join(lines) + "\n"


def fast_lookup(suffix: str, runs: list[tuple[int, int, int, list[str]]]) -> str:
    prefix = f"srzgs_lookup{suffix}"
    base = runs[0][0] & ~((1 << PAGE_SHIFT) - 1)
    limit = runs[-1][1]
    pages = ((limit - base) >> PAGE_SHIFT) + 1
    # page_first[p]: the first run that ends after page p starts. The run
    # holding an address of page p is between page_first[p] and
    # page_first[p + 1], both included.
    page_first = []
    run = 0
    for page in range(pages + 1):
        page_start = base + (page << PAGE_SHIFT)
        while run < len(runs) and runs[run][1] <= page_start:
            run += 1
        page_first.append(run)
    run_base = []
    chunks = []
    for _, _, _, funcs in runs:
        run_base.append(len(chunks))
        chunks += funcs
    return (
        f"\n{MARK}\n"
        f"#define SRZGS_LOOKUP_RUNS{suffix} {len(runs)}u\n"
        f"#define SRZGS_LOOKUP_BASE{suffix} 0x{base:08X}u\n"
        f"#define SRZGS_LOOKUP_PAGES{suffix} {pages}u\n"
        + table(f"{prefix}_start", "u32", [f"0x{r[0]:08X}u" for r in runs])
        + table(f"{prefix}_end", "u32", [f"0x{r[1]:08X}u" for r in runs])
        + table(f"{prefix}_stride", "u32", [f"0x{r[2]:08X}u" for r in runs])
        + table(f"{prefix}_base", "u32", [f"{b}u" for b in run_base])
        + table(f"{prefix}_page_first", "u32", [f"{p}u" for p in page_first])
        + table(f"{prefix}_chunks", "DolRecompFunction", chunks)
        + f"\nstatic inline DolRecompFunction dolrecomp_find_original{suffix}(u32 address) {{\n"
        f"    u32 page, low, high, offset;\n"
        f"    if (address < SRZGS_LOOKUP_BASE{suffix}) return NULL;\n"
        f"    page = (address - SRZGS_LOOKUP_BASE{suffix}) >> {PAGE_SHIFT}u;\n"
        f"    if (page >= SRZGS_LOOKUP_PAGES{suffix}) return NULL;\n"
        f"    low = {prefix}_page_first[page];\n"
        f"    high = {prefix}_page_first[page + 1u] + 1u;\n"
        f"    if (high > SRZGS_LOOKUP_RUNS{suffix}) high = SRZGS_LOOKUP_RUNS{suffix};\n"
        f"    while (low < high) {{\n"
        f"        u32 middle = low + (high - low) / 2u;\n"
        f"        if ({prefix}_end[middle] <= address) low = middle + 1u;\n"
        f"        else high = middle;\n"
        f"    }}\n"
        f"    if (low >= SRZGS_LOOKUP_RUNS{suffix} || address < {prefix}_start[low]) return NULL;\n"
        f"    offset = address - {prefix}_start[low];\n"
        f"    if ((offset & 3u) != 0u) return NULL;\n"
        f"    return {prefix}_chunks[{prefix}_base[low] + offset / {prefix}_stride[low]];\n"
        f"}}\n"
    )


def rewrite(header: str) -> tuple[str, int]:
    """The header with every linear lookup replaced, and how many."""
    out = []
    position = 0
    count = 0
    for start in FUNCTION_START.finditer(header):
        close = header.find("\n}\n", start.end())
        if close < 0:
            raise Unknown("unterminated dolrecomp_find_original")
        runs = parse_body(header[start.end():close])
        suffix = start["suffix"]
        out.append(header[position:start.start()])
        out.append(
            f"static inline DOLRECOMP_UNUSED DolRecompFunction "
            f"dolrecomp_find_original{suffix}_linear(u32 address) {{\n"
        )
        out.append(header[start.end():close + 3])
        out.append(fast_lookup(suffix, runs))
        position = close + 3
        count += 1
    out.append(header[position:])
    return "".join(out), count


def main(argv: list[str]) -> int:
    if len(argv) != 2 or not (Path(argv[1]) / "generated.h").is_file():
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    header_path = Path(argv[1]) / "generated.h"
    header = header_path.read_text(encoding="utf-8")
    if MARK in header:
        print("fast dispatch lookup: already in generated.h")
        return 0
    try:
        new_header, count = rewrite(header)
    except Unknown as error:
        print(f"fast dispatch lookup: left as it was ({error})")
        return 0
    if count == 0:
        print("fast dispatch lookup: left as it was (no dolrecomp_find_original)")
        return 0
    header_path.write_text(new_header, encoding="utf-8")
    print(f"fast dispatch lookup: {count} lookup(s) rewritten in generated.h")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
