/* =============================================================================
 * SR-Source - a function DolRecomp's LLVM backend calls that the pinned
 * GXRuntime doesn't have yet.
 *
 * Each block of code the LLVM backend compiles first asks whether it may run
 * natively from start to end, or whether the host wants to stop it (a mod
 * hooking an address inside it): ppc_native_region_available(). DolRecomp
 * defines it in its own runtime (src/cpu/cpu.c); the copy of that runtime the
 * module template builds (RecompCore's GXRuntime) is older and lacks it, so a
 * module made of LLVM objects couldn't be loaded. src/recompiled/CMakeLists.txt
 * adds this file only to such a module, and only while GXRuntime lacks it.
 *
 * It asks the same way DolRecomp's does. One difference: when the host
 * doesn't answer the question (the chassis doesn't yet), the block runs.
 * DolRecomp's would stop it, and stop it again on every try. The chassis
 * keeps mods' hooks out of native code by itself, chunk by chunk
 * (StaticRecompCore's host-call state), and only asks while a mod is loaded.
 * ========================================================================== */

#include "core/cpu.h"

#define SRZGS_HOST_CALL_NATIVE_REGION_QUERY 0xFFFFFFFCu
#define SRZGS_NATIVE_REGION_QUERY_PENDING 0xFEu
#define SRZGS_NATIVE_REGION_QUERY_HANDLED 0xFFu

bool ppc_native_region_available(CPUState* cpu, u32 start, u32 end)
{
    if (!cpu || !cpu->host_call)
        return true;

    const u32 saved_addr = cpu->external_addr;
    const u32 saved_value = cpu->external_value;
    const u8 saved_rid = cpu->external_rid;
    cpu->external_addr = start;
    cpu->external_value = end;
    cpu->external_rid = SRZGS_NATIVE_REGION_QUERY_PENDING;
    const bool blocked = cpu->host_call(cpu, SRZGS_HOST_CALL_NATIVE_REGION_QUERY);
    const bool answered = cpu->external_rid == SRZGS_NATIVE_REGION_QUERY_HANDLED;
    cpu->external_addr = saved_addr;
    cpu->external_value = saved_value;
    cpu->external_rid = saved_rid;
    return !answered || !blocked;
}
