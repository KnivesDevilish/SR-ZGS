/*
 * replacements.c - guest-function override table (Phase 1 hook point).
 *
 * DolRecomp's generated dispatcher calls dolrecomp_dispatch_replacement()
 * before running recompiled code for a guest address. Return 1 to say "I
 * handled this call", 0 to let the recompiled function run as usual.
 *
 * This is how Phase 1 fixes are made WITHOUT editing src/recompiled/ (which is
 * regenerated from the game binary and never committed).
 *
 * Adding a replacement:
 *   1. Find the guest address of the function (decomp symbols / Ghidra / Dolphin).
 *   2. Add `case 0x80xxxxxx:` below and call your implementation.
 *   3. `return 1` only if the call is fully handled; follow the PowerPC ABI
 *      (results in ctx->gpr[3] / ctx->fpr[1], then return to the caller).
 */
#include "generated.h" /* CPUState, u32 and the dispatcher prototype */

int dolrecomp_dispatch_replacement(CPUState* ctx, u32 address)
{
    (void)ctx;

    switch (address) {
    /* case 0x80000000: return my_replacement(ctx); */
    default:
        return 0; /* not replaced: run the recompiled code */
    }
}
