#!/usr/bin/env python3
"""SR-Source: let DolRecomp's C code run on after dcbf, dcbst and dcbi.

    python3 tools/dolrecomp/fast_cache_ops.py src/recompiled/<GAME_ID>
    python3 tools/dolrecomp/fast_cache_ops.py --undo src/recompiled/<GAME_ID>

DolRecomp hands these data-cache instructions to the chassis
(ppc_fallback_instruction) and then returns to its dispatcher. A loop that
flushes a buffer 32 bytes at a time - the SDK's DCFlushRange, DCStoreRange and
DCInvalidateRange, which games call for every texture, display list and movie
frame they hand to the GPU - so pays a whole dispatcher round trip per line:
in Sonic Riders that was over a third of all dispatches.

The chassis runs the three of them on a fast path that changes no register and
leaves pc at the next instruction (StaticRecompCore::HookInstructionFallback),
so the recompiled code can simply go on. It still returns, as before, when pc
is anything else or an exception was raised (the slow path: data-cache
emulation on, or dcbi outside supervisor mode). icbi is left as it is: it
invalidates code, which the dispatcher has to check again.

Edits the generated C in place (only the files that change, so a build
recompiles only those) and can be run again: what it changed no longer matches.
--undo puts back the plain return. tools/dolrecomp/recompile.sh runs it on
every new recompilation.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Primary opcode 31, extended opcodes of the data-cache instructions.
CACHE_OPS = {86: "dcbf", 54: "dcbst", 470: "dcbi"}

FALLBACK_THEN_RETURN = re.compile(
    r"^(?P<indent>[ \t]*)ppc_fallback_instruction\(ctx, 0x(?P<raw>[0-9A-Fa-f]{8})u, "
    r"0x(?P<cia>[0-9A-Fa-f]{8})u\);\n(?P=indent)return;\n",
    re.MULTILINE,
)

MARK = "/* SR-Source: fast cache op, tools/dolrecomp/fast_cache_ops.py */"


def cache_op(raw: int) -> str | None:
    if raw >> 26 != 31:
        return None
    return CACHE_OPS.get((raw >> 1) & 0x3FF)


def rewrite(text: str, counts: dict[str, int]) -> str:
    def replace(match: re.Match) -> str:
        raw = int(match["raw"], 16)
        name = cache_op(raw)
        if name is None:
            return match.group(0)
        counts[name] += 1
        indent = match["indent"]
        following = (int(match["cia"], 16) + 4) & 0xFFFFFFFF
        return (
            f"{indent}ppc_fallback_instruction(ctx, 0x{match['raw']}u, 0x{match['cia']}u);\n"
            f"{indent}if (ctx->pc != 0x{following:08X}u || ctx->exception) return; {MARK}\n"
        )

    return FALLBACK_THEN_RETURN.sub(replace, text)


UNDO = re.compile(
    r"^(?P<indent>[ \t]*)if \(ctx->pc != 0x[0-9A-F]{8}u \|\| ctx->exception\) return; "
    + re.escape(MARK) + r"\n",
    re.MULTILINE,
)


def undo(generated: Path) -> int:
    restored = 0
    for path in sorted(generated.rglob("*.c")):
        text = path.read_text(encoding="utf-8")
        if MARK not in text:
            continue
        new_text, count = UNDO.subn(lambda match: f"{match['indent']}return;\n", text)
        if count:
            path.write_text(new_text, encoding="utf-8")
            restored += count
    print(f"fast cache ops: {restored} put back as they were")
    return 0


def main(argv: list[str]) -> int:
    args = argv[1:]
    undoing = bool(args) and args[0] == "--undo"
    if undoing:
        args = args[1:]
    if len(args) != 1 or not Path(args[0]).is_dir():
        print("usage: fast_cache_ops.py [--undo] src/recompiled/<GAME_ID>", file=sys.stderr)
        return 2
    generated = Path(args[0])
    if undoing:
        return undo(generated)
    counts = {name: 0 for name in CACHE_OPS.values()}
    changed_files = 0
    for path in sorted(generated.rglob("*.c")):
        text = path.read_text(encoding="utf-8")
        if "ppc_fallback_instruction" not in text:
            continue
        new_text = rewrite(text, counts)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed_files += 1
    already = sum(
        path.read_text(encoding="utf-8").count(MARK) for path in generated.rglob("*.c")
    )
    print(
        f"fast cache ops: {counts['dcbf']} dcbf, {counts['dcbst']} dcbst and {counts['dcbi']} dcbi "
        f"changed in {changed_files} files ({already} in all)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
