# Critical Analysis of Current Kernel State

Date: 2026-07-25

Scope: current repository state inspected against `.clinerules`, with particular attention to a future general-purpose microkernel direction, common-code-first design, explicit error handling, static interface validation, mock parity, and testability.

---

## Executive Summary

The kernel is moving in a promising direction for an early hobby kernel: there is a clear architecture abstraction layer, a mock architecture for host tests, common PMM/VMM/heap code, and tests are kept under `tests/` rather than embedded in source files. The codebase also uses Zig `comptime` interface validation, which aligns well with the goal of static polymorphism and low-overhead abstraction.

However, the current implementation is still closer to a monolithic prototype than to a production-grade microkernel foundation. The biggest risks are:

1. **Boot/init code still contains demo behavior and policy decisions** instead of a clean staged kernel initialization path.
2. **Interrupt handling contains debug console output on hot paths**, including timer interrupts.
3. **Memory management APIs lack explicit failure semantics in critical paths**; several functions panic, silently return, or swallow errors.
4. **The PMM/VMM data structures are simple linear arrays**, acceptable for early boot but not suitable as long-term kernel structures.
5. **The mock architecture has interface shape parity but weak behavioral parity**, so tests can pass while real MMU/interrupt behavior remains untested.
6. **The module graph is workable but not cleanly layered**; `kernel_common.zig` is a flat re-export bag and architecture/common dependencies are tightly coupled.

The current `kernel_analysis.md` contained several good recommendations, but some were stale after recent changes. This update corrects those items and re-prioritizes the roadmap.

---

## Verified Current Status

Observed commands:

- `zig build` completed for the freestanding x86 kernel artifact.
- `timeout 30s zig build tests 2>&1; echo "EXIT:$?"` exited with `EXIT:0`, indicating the host test step completed successfully within the timeout.

Important repository-state caveat:

- `git status --short` showed many modified files and `kernel_analysis.md` as untracked at the time of analysis. This document analyzes the working tree as presented, not necessarily the last committed state.

---

## Current Strengths

### 1. Architecture abstraction exists and uses static validation

Relevant files:

- `src/architecture/architecture.zig`
- `src/architecture/x86/arch.zig`
- `src/architecture/mock/arch.zig`

`architecture.zig` defines common types and validates required architecture components at comptime:

- `early_allocator`
- `boot`
- `cpu`
- `interrupts`
- `mmu`
- `platform`

This matches the `.clinerules` preference for static polymorphism and common interfaces before hardware implementations. It is one of the strongest architectural foundations currently in the tree.

### 2. Common memory code is testable on host

Relevant files:

- `src/common/memory_management/pmm.zig`
- `src/common/memory_management/vmm.zig`
- `src/common/memory_management/heap.zig`
- `tests/pmm_tests.zig`
- `tests/vmm_tests.zig`
- `tests/heap_tests.zig`

The mock architecture is sufficient for many PMM/VMM/heap tests. This is important: the project is already set up to test architecture-independent code outside QEMU.

### 3. Tests are correctly separated under `tests/`

The testing layout follows `.clinerules`:

- tests are not injected into source files;
- tests are grouped under `tests/`;
- `tests/tests.zig` imports the test suites.

### 4. The heap allocator has meaningful invariants and allocator integration

`src/common/memory_management/heap.zig` is comparatively well documented and exposes a `std.mem.Allocator`. The block header/footer invariant comments are useful and justified because the allocator has non-trivial layout constraints.

---

## Corrections to Previous Recommendations

### Corrected: `kernel_common` self-import no longer exists

The previous analysis claimed both `arch` and `kernel_common` self-imported in `build.zig`:

```zig
kernel_common.addImport("kernel_common", kernel_common);
```

That is no longer present. The current relevant imports are:

```zig
arch.addImport("arch", arch);
arch.addImport("kernel_common", kernel_common);
kernel_common.addImport("arch", arch);
```

The remaining issue is not a direct `kernel_common` self-import. The issue is a **layering smell**:

- architecture implementation files import `@import("arch")` and therefore require `arch.addImport("arch", arch)`;
- architecture code also imports `kernel_common` in places such as interrupt handling and MMU heap sizing;
- common memory code imports `arch`.

This works, but it creates tight coupling between architecture and common kernel modules.

### Corrected: VMM `faultHandler` tests now exist

The previous analysis said `faultHandler()` had no tests. That is stale. `tests/vmm_tests.zig` now includes tests for:

- mapping a page within a VMA;
- zeroing the mapped page;
- reusing a page table on a second fault in the same table region;
- propagating permissions enough to reach `mapTable`.

Remaining issue: `faultHandler()` still panics for several important cases, and the tests explicitly document that these panic paths cannot be tested with the current test structure. The recommendation should shift from “add `faultHandler` tests” to **make VMM fault handling return explicit errors or expose a testable lower-level fault-resolution function**.

### Corrected: mock MMU has partial, not zero, behavior

The previous analysis described the mock MMU as entirely no-op. It now tracks page-table mappings enough for `isTablePresent()` and VMM fault-handler tests.

Still valid: `mapPage()`, `unmapPage()`, and `getPhysicalAddress()` remain behaviorally weak:

- `getPhysicalAddress()` always returns `null`;
- `mapPage()` discards virtual address, physical address, and flags;
- `unmapPage()` discards the virtual address;
- page permissions cannot be asserted;
- mapped pages cannot be queried.

So mock parity has improved but is still incomplete.

### Corrected: heap `resize()` previous-block critique was too strong

The previous analysis claimed `Heap.resize()` should coalesce with the previous block. That critique is misleading.

A simple in-place `resize()` generally cannot grow backward into a previous free block without moving the user pointer. Moving belongs in allocator `remap`/`realloc` behavior, not necessarily in an in-place resize primitive. The current `resize()` growing into the next free block is normal.

Better recommendation:

- keep `resize()` as in-place-only;
- implement richer `realloc`/`remap` behavior later if needed;
- add tests around realloc fallback behavior and fragmentation patterns.

### Corrected: PMM dead-code claim should be narrowed

The previous analysis called out commented-out PMM functions. In the current inspected file, the notable issue is narrower:

- `markFrames()` exists but has no callers.

Recommendation: remove it if it is obsolete, or reintroduce it deliberately as part of a clearer PMM initialization pipeline.

---

## Critical Findings and Recommendations

## A. Architecture and Module Boundaries

### A1. `kernel_common.zig` is a flat re-export bag

Relevant file: `src/kernel_common.zig`

Current contents are only flat re-exports:

```zig
pub const terminal = @import("common/terminal/main.zig");
pub const pmm = @import("common/memory_management/pmm.zig");
pub const vmm = @import("common/memory_management/vmm.zig");
pub const kernel_heap = @import("common/memory_management/kernel_heap.zig");
pub const heap = @import("common/memory_management/heap.zig");
```

This is acceptable for a small prototype but does not scale well. It hides module boundaries and encourages broad imports.

**Recommendation:** introduce a hierarchical common module structure, for example:

```zig
pub const memory_management = @import("common/memory_management/main.zig");
pub const terminal = @import("common/terminal/main.zig");
```

Then `src/common/memory_management/main.zig` can own:

```zig
pub const physical_memory = @import("pmm.zig");
pub const virtual_memory = @import("vmm.zig");
pub const heap = @import("heap.zig");
pub const kernel_heap = @import("kernel_heap.zig");
```

This better matches the goal of modularity and common-code organization.

**Severity:** Medium.

### A2. Architecture and common code are tightly coupled

Relevant files:

- `build.zig`
- `src/architecture/architecture.zig`
- `src/architecture/x86/interrupts/main.zig`
- `src/architecture/x86/mmu/main.zig`
- `src/common/memory_management/*.zig`

Examples:

- common memory code imports `arch`;
- x86 interrupt handling imports `kernel_common` to call `kernel_common.vmm.faultHandler()`;
- x86 MMU imports `kernel_common` to calculate heap size from PMM state;
- `arch.addImport("arch", arch)` exists because architecture internals import the public architecture module.

This creates practical cycles at the conceptual layer even if Zig can compile it.

**Recommendation:** invert some dependencies through narrow interfaces:

- keep low-level architecture code unaware of `kernel_common` where possible;
- route page faults through a registered common fault callback or a thin kernel interrupt dispatch layer;
- avoid having MMU determine heap size from PMM; kernel policy should size the heap and ask MMU for address-space constants/capabilities.

**Severity:** Medium-high for long-term architecture.

### A3. Microkernel direction is not yet reflected in subsystems

The `.clinerules` target a general-purpose microkernel, but current code has no clear boundaries for:

- scheduler/thread model;
- process/task address spaces;
- IPC;
- capability or handle model;
- userspace/kernelspace transition policy;
- driver isolation;
- syscall ABI.

This is not a defect for an early memory-management-focused stage, but it should influence upcoming design choices.

**Recommendation:** before adding many drivers or kernel services, define the minimal microkernel abstractions:

1. thread/context model;
2. address-space object model;
3. IPC endpoint or message primitive;
4. kernel object/capability handles;
5. interrupt-to-driver delivery model.

**Severity:** Strategic / medium.

---

## B. Boot and Kernel Initialization

### B1. `kernel.zig` mixes initialization, diagnostics, and demo allocation behavior

Relevant file: `src/kernel.zig`

`kernelMain()` performs real initialization but also contains a hardcoded 10 MiB heap allocation and writes test offsets:

```zig
const allocation: [*]u8 = @as([*]u8, @ptrCast(kernelHeap.kmalloc(10 * 1024 * 1024) catch |err| {
    ...
}));

allocation[100000] = 12;
allocation[200000] = 22;
...
```

This is demo/probing code and should not live in the primary boot path.

**Recommendation:** split initialization into stages:

- `initializeTerminal()`
- `initializeAddressSpace()`
- `initializePhysicalMemory()`
- `initializeInterrupts()`
- `initializeKernelHeap()`
- optional `runKernelSelfTest()` gated by a build option

Move allocation probes into tests or an explicit debug/self-test mode.

**Severity:** High.

### B2. Error-reporting paths frequently swallow writer errors

Relevant files:

- `src/kernel.zig`
- `src/common/terminal/print.zig`
- `src/architecture/x86/interrupts/main.zig`

Many calls use `catch {}`. This is sometimes reasonable for last-ditch panic output, but it conflicts with the rule that error handling should be explicit.

**Recommendation:** centralize fallible boot diagnostics:

- for normal initialization, return or propagate errors;
- for panic/unrecoverable output, use a specifically named helper such as `bestEffortWritePanicMessage()` so the intentional swallowing is visible.

**Severity:** Medium.

### B3. Boot flow lacks a host-testable integration path

Relevant files:

- `src/kernel.zig`
- `tests/tests.zig`
- `src/architecture/mock/*`

There is no test that runs the full initialization sequence against the mock architecture. Current tests cover PMM/VMM/heap pieces, not the orchestration in `kernelMain()`.

**Recommendation:** extract a non-exported `kernelInitialize()` function that returns an error union and can be called from tests with the mock architecture. Keep `kernelMain()` as the freestanding wrapper that reports errors and halts.

**Severity:** Medium-high.

---

## C. Physical Memory Manager

### C1. PMM allocation is O(n) linear first-fit over all frames

Relevant file: `src/common/memory_management/pmm.zig`

`get_start_frame()` scans from frame 0 to `totalFrames` for each allocation. With `MAX_FRAMES = 2,097,152`, this will become expensive and unpredictable.

This is a performance-sensitive path. `.clinerules` explicitly allow efficiency to take precedence in MMU/memory-management hot paths when documented.

**Recommendation:** replace `FrameInfo { used, reserved }` scanning with a bitmap allocator or segmented free-area structure.

Possible staged path:

1. bitmap for used/free state;
2. separate reserved bitmap or immutable reserved ranges;
3. maintain a next-search cursor for short-term improvement;
4. later, buddy allocator for page frames if contiguous allocations become common.

**Severity:** High.

### C2. PMM `reserve()` silently returns on out-of-bounds ranges

Relevant file: `src/common/memory_management/pmm.zig`

Current behavior:

```zig
if (end_frame > totalFrames) {
    return;
}
```

This can hide boot memory-map bugs or allocator range errors.

**Recommendation:** return `PmmError.InvalidIndex` or add a more specific error such as `PmmError.InvalidRange`.

**Severity:** High because silent failure in memory reservation can corrupt later allocation assumptions.

### C3. PMM accounting can become inaccurate

Relevant file: `src/common/memory_management/pmm.zig`

Potential issues:

- `reserve()` increments `totalSystemFrames` and subtracts from `currentAvailableFrames` without checking whether frames were already reserved/used;
- `free()` increments availability for every frame after checking only `reserved`, not whether it was actually allocated;
- `trackAllocationsAsReserved` increments `totalSystemFrames` when allocating, but does not mark `reserved = true`, so later freeing behavior/accounting can be surprising.

**Recommendation:** make PMM state transitions explicit:

- `Free -> Used`
- `Free -> Reserved`
- `Used -> Free`
- prohibit or explicitly handle idempotent reservation;
- test double-free, reserve-over-used, reserve-over-reserved, and freeing unused frames.

**Severity:** Medium-high.

### C4. 64-bit physical addresses are truncated in common paths

Relevant files:

- `src/common/memory_management/pmm.zig`
- `src/architecture/early_allocator.zig`

There are multiple `@truncate()` conversions from `u64` memory-map addresses/sizes to `usize`. On 32-bit x86 this limits practical support to the 32-bit address space, but the project also defines `MAX_FRAMES` as 64 GiB worth of 4 KiB frames.

**Recommendation:** decide explicitly:

- if current target is strictly 32-bit x86, cap and reject memory-map regions above addressable space;
- if x86_64 is planned, keep physical addresses as `u64`/`PhysicalAddress` in common interfaces and only narrow at architecture boundaries with checked conversions.

**Severity:** Medium.

---

## D. Virtual Memory Manager

### D1. `vmm.map()` does not validate VMA capacity

Relevant file: `src/common/memory_management/vmm.zig`

`map()` writes:

```zig
addressSpace.VMAList[addressSpace.length] = ...
addressSpace.length += 1;
```

It only checks whether `VMAList.len == 0`, not whether `length >= VMAList.len`.

**Recommendation:** add an explicit error such as `VMMError.OutOfVirtualMemoryAreas` before writing.

**Severity:** High because this is an out-of-bounds write risk.

### D2. `vmm.map()` does not validate range shape or alignment

Relevant file: `src/common/memory_management/vmm.zig`

Missing validation:

- `startAddress < endAddress`;
- page alignment of both addresses;
- overflow in range calculations;
- permission consistency, e.g. readable currently exists but is not represented in `arch.PageProtection`.

**Recommendation:** add validation errors for invalid range/alignment. Define whether VMA ranges are always page-granular.

**Severity:** Medium-high.

### D3. `faultHandler()` ignores protection faults

Relevant file: `src/common/memory_management/vmm.zig`

Current logic only handles `present == false`. If `present == true`, the function returns without reporting a write/user/instruction-fetch protection violation.

**Recommendation:** handle protection faults explicitly:

- write to read-only VMA;
- user access to supervisor VMA;
- instruction fetch from non-executable VMA;
- reserved-bit/page-table faults when architecture exposes them.

Prefer returning an error from a lower-level resolver rather than panicking directly.

**Severity:** High.

### D4. `faultHandler()` panics instead of returning explicit errors

Relevant file: `src/common/memory_management/vmm.zig`

The current handler panics for:

- early page fault;
- PMM allocation failure;
- MMU mapping failure;
- fault outside any VMA.

Panic may be correct at the top-level interrupt boundary, but it makes behavior hard to test and violates the spirit of explicit error handling in lower-level code.

**Recommendation:** split into two layers:

```zig
pub fn resolveFault(faultInfo: arch.FaultInfo) VMMError!void
pub fn faultHandler(faultInfo: arch.FaultInfo) void
```

`faultHandler()` can call `resolveFault()` and panic/halt at the final boundary. Tests can exercise `resolveFault()`.

**Severity:** High.

### D5. VMA lookup is O(n)

Relevant file: `src/common/memory_management/vmm.zig`

Linear VMA lookup is acceptable with two kernel VMAs, but it is not viable once processes, shared mappings, memory-mapped objects, stacks, guard pages, and user regions exist.

**Recommendation:** keep the simple array for early boot, but design `AddressSpace` so the VMA storage can later become a sorted array, tree, interval tree, or architecture-independent map without changing callers.

**Severity:** Medium now, high later.

### D6. Naming does not follow Zig conventions

Relevant file: `src/common/memory_management/vmm.zig`

`AddressSpace.VMAList` should be renamed to something like `virtual_memory_areas` or `vma_list`. The acronym is acceptable, but field casing should follow Zig style.

**Severity:** Low.

---

## E. Heap and Kernel Heap

### E1. `kernel_heap.kmalloc()` / `kfree()` duplicate allocator behavior

Relevant file: `src/common/memory_management/kernel_heap.zig`

`heap.Heap` already exposes a `std.mem.Allocator`, but kernel code also exposes custom `kmalloc()` and `kfree()` wrappers.

**Recommendation:** prefer `kernelAllocator` / `allocator()` style APIs and phase out raw `kmalloc()`/`kfree()` except perhaps as tiny compatibility wrappers.

**Severity:** Medium.

### E2. `kernel_heap.kfree()` dynamic allocation accounting is likely wrong

Relevant file: `src/common/memory_management/kernel_heap.zig`

`kmalloc(size)` increments:

```zig
dynamicAllocationSize += size;
```

`kfree(bytes)` decrements:

```zig
dynamicAllocationSize -= blockOriginalSize;
```

`blockOriginalSize` includes allocator metadata and alignment effects, not the originally requested size. This can underflow or report incorrect dynamic allocation usage.

**Recommendation:** either:

- track requested size in allocation metadata;
- track actual block size consistently on both allocate and free;
- remove this metric until it can be made correct.

**Severity:** Medium-high.

### E3. `kernel_heap.kfree()` releases physical pages on every free

Relevant file: `src/common/memory_management/kernel_heap.zig`

`kfree()` unmaps fully contained pages and returns frames to the PMM. This is aggressive for a general kernel heap:

- frequent TLB invalidations;
- increased PMM churn;
- possible heap fragmentation interactions;
- hard-to-reason accounting, especially with coalescing.

**Recommendation:** decouple virtual heap freeing from physical page reclamation. Prefer a heap arena/page-cache policy:

- normal `free()` returns memory to heap free lists;
- page reclamation happens under pressure, by threshold, or through an explicit heap shrinker;
- track committed vs reserved heap separately.

**Severity:** Medium.

### E4. `kernel_heap.kfree()` swallows PMM free errors

Relevant file: `src/common/memory_management/kernel_heap.zig`

Current code:

```zig
pmm.free(physicalFrame, 1) catch {};
```

This hides serious allocator/MMU state inconsistencies.

**Recommendation:** return an error from a fallible decommit function, or use a named best-effort path that documents why failure is recoverable.

**Severity:** Medium.

---

## F. x86 Interrupts

### F1. PIC initialization masking appears wrong/misleading

Relevant file: `src/architecture/x86/interrupts/interrupt_descriptor_table.zig`

Current code:

```zig
port_io.out8(0x21, 0x01); // ICW4: 8086 mode

// Disable timer for now.
port_io.out8(0x21, 0x01); // ICW4: 8086 mode
```

After ICW4, writes to port `0x21` are interrupt-mask writes. `0x01` masks IRQ0 and leaves other master IRQs enabled depending on PIC state; the comment and value are inconsistent. If the intent is to mask all IRQs, use `0xFF`. If the intent is to enable only keyboard/timer, encode that explicitly.

Also, slave PIC initialization is missing in this file. A complete PIC remap normally initializes both master and slave PICs.

**Recommendation:** implement a small PIC module with named operations:

- `remap(master_offset, slave_offset)`;
- `setMask(irq)` / `clearMask(irq)`;
- `maskAll()`;
- `sendEndOfInterrupt(vector)`.

**Severity:** High.

### F2. Interrupt handler prints on hot paths

Relevant file: `src/architecture/x86/interrupts/main.zig`

`interruptHandler()` writes to the platform console for almost every interrupt, including timer interrupts:

```zig
arch.platform.writer().writeAll("Timer.\n") catch {};
```

This will dominate execution once the timer is enabled and can make the kernel appear hung or extremely slow.

**Recommendation:** remove unconditional printing from interrupt paths. Use one of:

- compile-time debug flag;
- rate-limited tracing;
- per-vector counters;
- serial-only diagnostic channel;
- panic-only exception reporting.

**Severity:** High.

### F3. Page fault handler prints after successful demand mapping

Relevant file: `src/architecture/x86/interrupts/main.zig`

After `kernel_common.vmm.faultHandler(fault_info);`, the handler prints `"Page fault.\n"`. For demand paging, page faults can be normal. Printing for every resolved demand fault is undesirable.

**Recommendation:** only report unresolved or fatal page faults. Let successful demand faults return silently.

**Severity:** Medium.

### F4. Exception handling is not structured

Relevant file: `src/architecture/x86/interrupts/main.zig`

The handler has a large switch with printing and limited semantics. For a production-grade kernel, exceptions should be decoded into structured fault records and routed to the kernel fault subsystem.

**Recommendation:** create architecture-independent exception/fault dispatch types and keep x86-specific register decoding in x86 code.

**Severity:** Medium.

---

## G. x86 MMU

### G1. `unmapPage()` assumes page table presence

Relevant file: `src/architecture/x86/mmu/main.zig`

`unmapPage()` calls `getPageTableFromDirectory()` without checking whether the PDE is present. Unmapping an unmapped VMA range can therefore access an invalid page table.

**Recommendation:** make `unmapPage()` return an error or no-op safely when the table/page is absent:

```zig
pub fn unmapPage(virtualAddress: usize) arch.MmuError!void
```

or define no-op semantics explicitly and implement the presence checks.

**Severity:** High.

### G2. Execute permissions are modeled but not enforced on 32-bit x86

Relevant files:

- `src/architecture/architecture.zig`
- `src/architecture/x86/mmu/main.zig`
- `src/architecture/x86/mmu/common.zig`

`arch.PageProtection` includes `execute`, and VMM passes executable permissions, but 32-bit non-PAE x86 page entries do not have NX support. The flag is effectively ignored.

**Recommendation:** expose architecture capabilities:

```zig
pub const MmuCapabilities = struct {
    supports_no_execute: bool,
    supports_user_pages: bool,
    supports_global_pages: bool,
};
```

Then VMM can reject unsupported permission combinations or document that they are advisory.

**Severity:** Medium.

### G3. Heap sizing belongs in kernel policy, not MMU implementation

Relevant file: `src/architecture/x86/mmu/main.zig`

`getKernelHeapSize()` imports `kernel_common.pmm` and calculates heap size from total available RAM.

This couples architecture MMU implementation to PMM policy.

**Recommendation:** MMU should expose address-space layout constants/capabilities. Kernel initialization should calculate heap size from PMM state and map the region.

**Severity:** Medium.

### G4. Early direct map is limited and x86-only

Relevant files:

- `src/architecture/x86/mmu/early_boot.zig`
- `src/architecture/x86/mmu/common.zig`

The direct map is 768 MiB:

```zig
pub const DIRECT_MAP_SIZE = 768 * 1024 * 1024;
```

For 32-bit x86 this may be a practical temporary compromise. For a general-purpose kernel, the architecture plan should define whether the near-term target remains i386 or moves to x86_64.

**Recommendation:** document the 32-bit limitation explicitly and prioritize x86_64 once the PMM/VMM interfaces stabilize.

**Severity:** Strategic / medium.

---

## H. Mock Architecture and Testing Fidelity

### H1. Mock MMU does not provide full behavioral parity

Relevant file: `src/architecture/mock/mmu/main.zig`

Current mock MMU limitations:

- `getPhysicalAddress()` always returns `null`;
- `mapPage()` is a no-op;
- `unmapPage()` is a no-op;
- permissions are not stored;
- repeated mapping/unmapping behavior is not testable;
- `getKernelHeapVirtualAddress()` and `getKernelHeapSize()` return `0`.

This means common code that depends on actual mappings can pass tests without being correct.

**Recommendation:** implement a real mock page map:

```zig
const MockPageMapping = struct {
    virtual_page: usize,
    physical_page: usize,
    flags: arch.PageProtection,
    present: bool,
};
```

Then support:

- querying physical address;
- testing flags;
- unmapping;
- duplicate mapping detection;
- missing-table errors.

**Severity:** High for test credibility.

### H2. Mock MMU allocates a fresh 64 MiB region in `getMemoryMap()`

Relevant file: `src/architecture/mock/mmu/main.zig`

`getMemoryMap()` allocates host memory every time it is called. Tests currently rely on this behavior in comments, but repeated calls can leak host memory and hide lifecycle bugs.

**Recommendation:** add explicit mock reset/setup helpers for tests, for example:

```zig
pub fn resetForTest() void
pub fn initializeTestMemory(size: usize) !void
```

Then `getMemoryMap()` should return stable state rather than allocate implicitly.

**Severity:** Medium-high.

### H3. Mock interrupts and platform are shape-compatible but not behaviorally useful

Relevant files:

- `src/architecture/mock/interrupts/main.zig`
- `src/architecture/mock/platform/main.zig`

Mock interrupts do not track enabled/disabled state, registered vectors, or acknowledgements. Mock writer discards all output.

**Recommendation:** make mock components observable:

- interrupt enabled flag;
- IDT registration table;
- acknowledgement counters;
- buffered console output;
- timer frequency state.

This will support integration tests for boot flow and interrupt behavior.

**Severity:** Medium.

---

## I. Build, Run, and Debug Workflow

### I1. Build supports kernel and tests, but not enough verification modes

Relevant file: `build.zig`

Current useful steps:

- default kernel build;
- `zig build tests`;
- `zig build run` with QEMU.

Missing useful steps:

- formatting check;
- static analysis/lint conventions if available;
- QEMU smoke test that exits or writes a success marker;
- separate debug/release-safe build verification;
- architecture selection options.

**Recommendation:** add build steps incrementally:

- `zig build check` for compile-only validation if supported by current Zig version;
- `zig build fmt-check` or documented formatting command;
- `zig build test-unit` and later `zig build test-integration`;
- QEMU smoke mode without `-S` for automated runs.

**Severity:** Medium.

### I2. QEMU run step always starts paused under GDB

Relevant file: `build.zig`

`zig build run` includes:

```zig
"-S",
"-s",
"-daemonize",
```

This is useful for debugging but not for a normal smoke run.

**Recommendation:** split into:

- `zig build run` for normal execution;
- `zig build debug-qemu` for `-S -s` paused debugging.

**Severity:** Low-medium.

---

## Priority-Ordered Roadmap

## Critical / Fix First

1. **Fix PIC initialization and masking**
   - File: `src/architecture/x86/interrupts/interrupt_descriptor_table.zig`
   - Implement explicit master/slave PIC remap and mask operations.

2. **Remove interrupt hot-path console spam**
   - File: `src/architecture/x86/interrupts/main.zig`
   - Timer and normal demand page faults must not print unconditionally.

3. **Add VMM capacity/range validation**
   - File: `src/common/memory_management/vmm.zig`
   - Prevent VMA backing-array overflow and invalid ranges.

4. **Make VMM fault resolution explicitly fallible and testable**
   - File: `src/common/memory_management/vmm.zig`
   - Add `resolveFault() VMMError!void`; keep panic/halt behavior only at interrupt boundary.

5. **Fix PMM `reserve()` silent out-of-bounds behavior**
   - File: `src/common/memory_management/pmm.zig`
   - Return explicit errors for invalid ranges.

## High Priority

6. **Remove demo allocation from `kernelMain()`**
   - File: `src/kernel.zig`
   - Move to tests or build-gated self-test.

7. **Improve mock MMU behavioral parity**
   - File: `src/architecture/mock/mmu/main.zig`
   - Track page mappings, physical addresses, flags, and unmaps.

8. **Fix kernel heap accounting**
   - File: `src/common/memory_management/kernel_heap.zig`
   - Track requested size vs actual block size consistently or remove the metric.

9. **Make `x86.mmu.unmapPage()` safe for absent tables/pages**
   - File: `src/architecture/x86/mmu/main.zig`
   - Return error or no-op with documented semantics.

10. **Replace PMM linear scan with a bitmap or cursor-backed allocator**
    - File: `src/common/memory_management/pmm.zig`
    - At minimum, add a next-search cursor; preferably move to a bitmap design.

## Medium Priority

11. **Refactor `kernel_common` into hierarchical modules**
    - Files: `src/kernel_common.zig`, new `src/common/memory_management/main.zig`

12. **Extract host-testable kernel initialization**
    - File: `src/kernel.zig`
    - Enable mock architecture integration tests.

13. **Separate architecture MMU mechanisms from kernel heap sizing policy**
    - File: `src/architecture/x86/mmu/main.zig`

14. **Add observable mock platform/interrupt state**
    - Files: `src/architecture/mock/platform/main.zig`, `src/architecture/mock/interrupts/main.zig`

15. **Clean up PMM state transition accounting**
    - File: `src/common/memory_management/pmm.zig`
    - Add tests for reserve/free/double-free/interleaved fragmentation.

16. **Split QEMU run/debug build steps**
    - File: `build.zig`

## Lower Priority / Later

17. **Rename VMM fields to Zig-style names**
    - `VMAList` -> `vma_list` or `virtual_memory_areas`.

18. **Document x86 permission limitations**
    - Especially execute/NX behavior on 32-bit non-PAE x86.

19. **Decide and document x86_64 migration path**
    - Current architecture is i386-only. That is acceptable temporarily, but a modern general-purpose kernel should target x86_64 soon.

20. **Remove or justify unused PMM helper `markFrames()`**
    - Keep only if it becomes part of a clearer initialization design.

---

## Suggested Next Implementation Slice

A practical next slice with high value and limited blast radius:

1. Fix PIC initialization and remove unconditional interrupt printing.
2. Add VMM map validation errors and tests.
3. Split `vmm.resolveFault()` from `vmm.faultHandler()` and convert existing panic-path notes into tests.
4. Improve mock MMU to track `mapPage()`/`unmapPage()`/`getPhysicalAddress()`.
5. Remove `kernelMain()` demo allocation or gate it behind a debug self-test build option.

Success criteria for that slice:

- `zig build` succeeds.
- `zig build tests` succeeds.
- VMM tests cover invalid ranges, VMA capacity exhaustion, fault outside VMA as an error, and protection fault behavior.
- Mock MMU can verify mapped physical addresses and permissions.
- Timer interrupts do not spam console output.
- Kernel boot path contains initialization only, not allocation demos.

---

## Bottom Line

The project has a solid early skeleton: architecture selection, comptime interface validation, common memory modules, and host tests. The most important shift now is to stop letting prototype conveniences harden into architecture: remove demo code from boot, make fault/memory errors explicit and testable, improve mock behavioral parity, and separate architecture mechanisms from kernel policy. Those changes will align the codebase much more closely with the stated `.clinerules` goal of a modular, common-code-first, production-grade microkernel design.
