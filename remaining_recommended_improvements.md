# Remaining Recommended Kernel Improvements

Date: 2026-07-25

This file tracks recommended modularity, clarity, and reasoning improvements for the kernel. It now includes explicit progress markers so completed slices remain visible while remaining work stays prioritized.

Progress markers:

- `[x]` completed in the current working tree;
- `[ ]` not yet implemented;
- `[~]` partially implemented or intentionally staged.

## Progress Summary

Completed so far:

- [x] Added hierarchical `kernel_common.memory_management` exports via `src/common/memory_management/main.zig`.
- [x] Preserved compatibility aliases in `src/kernel_common.zig` for existing `pmm`, `vmm`, `kernel_heap`, and `heap` imports.
- [x] Renamed VMM backing storage from `VMAList` to `virtual_memory_areas`.
- [x] Added VMM map validation for backing capacity, invalid/empty ranges, and page alignment.
- [x] Added VMM validation tests for capacity, invalid ranges, and unaligned ranges.
- [x] Split VMM demand-fault resolution into fallible `resolveFault()` and boundary-only `faultHandler()` panic behavior.
- [x] Added explicit VMM protection-fault handling for present/write/user/instruction-fetch violations.
- [x] Improved mock MMU page-mapping behavior enough for VMM tests to assert mapped physical pages and permissions.
- [x] Added VMM fault tests for early faults, faults outside VMAs, present-page faults, and permission violations.
- [x] Rewrote the generic heap internals around clearer block/free-list helpers while preserving the public `Heap` API.
- [x] Added targeted heap coverage for freeing and reusing highly aligned allocations.
- [x] Simplified `kernel_heap.kfree()` so normal frees no longer hide MMU/PMM page decommit policy.
- [x] Fixed kernel heap accounting to track allocated block bytes consistently.
- [x] Added a dedicated legacy PIC fallback module at `src/architecture/x86/interrupts/pic.zig`.
- [x] Replaced raw PIC setup/EOI port writes with named PIC operations.
- [x] Explicitly masks all PIC IRQs after remap, unmasks keyboard during interrupt initialization, and unmasks timer when PIT setup is requested.

Highest-value remaining next steps:

- [ ] Introduce an x86 interrupt-controller abstraction so the current PIC fallback can later be replaced by Local APIC/I/O APIC routing cleanly.
- [ ] Add ACPI discovery, especially MADT parsing, before implementing APIC in a production-grade way.
- [ ] Fix PMM `reserve()` silent out-of-bounds behavior.
- [ ] Clean up PMM state transitions and accounting.

The remaining work below is ordered to reduce architectural coupling first, then improve subsystem correctness and test credibility.

---

## Critical / Fix First

### 1. [x] Fix x86 PIC initialization and masking — completed as legacy fallback

Relevant files:

- `src/architecture/x86/interrupts/pic.zig`
- `src/architecture/x86/interrupts/interrupt_descriptor_table.zig`
- `src/architecture/x86/interrupts/main.zig`
- `src/architecture/x86/platform/time/main.zig`

Status: completed as the **legacy PIC fallback/disable path** that will still be useful when APIC support is added.

Completed deliverables:

- Introduced a small x86 PIC module with named operations:
  - `remap(master_offset, slave_offset)`;
  - `maskAll()`;
  - `setMask(irq)`;
  - `clearMask(irq)`;
  - `sendEndOfInterrupt(vector)`;
  - `isHardwareInterrupt(vector)`.
- Initialized both master and slave PICs explicitly through `pic.remap()`.
- Replaced raw magic port writes in IDT setup and interrupt acknowledgement paths.
- Masked all PIC IRQs after remap, then explicitly unmasked keyboard IRQ during interrupt initialization.
- Unmasked timer IRQ when PIT timer initialization is requested.

Verification:

- `zig fmt` was run on the touched PIC/interrupt/time files.
- `timeout 60s zig build tests` completed with exit code `0`.
- `zig build` completed with exit code `0`.
- `git diff --check` reported no whitespace/check errors for the PIC-related files.

Follow-up:

- Keep this module as the legacy fallback and future APIC disable/masking path.
- Do not expand legacy PIC into the primary long-term interrupt controller; add an interrupt-controller abstraction and APIC backend instead.

---

### 1a. [ ] Introduce x86 interrupt-controller abstraction and APIC path

Relevant files:

- proposed: `src/architecture/x86/interrupts/controller.zig`
- future: `src/architecture/x86/interrupts/apic/local_apic.zig`
- future: `src/architecture/x86/interrupts/apic/io_apic.zig`
- future: ACPI/MADT discovery module

Modern x86 systems should use Local APIC and I/O APIC rather than the legacy 8259 PIC for normal interrupt delivery. This should be staged behind a small interrupt-controller boundary so the rest of the x86 interrupt code does not care whether the backend is PIC, APIC, or eventually x2APIC.

Recommended deliverables:

- Add an x86 interrupt-controller abstraction with operations such as:
  - `initialize()`;
  - `enableIrq(irq)`;
  - `disableIrq(irq)`;
  - `acknowledgeInterrupt(vector)`.
- Use the existing `pic.zig` as the first backend/fallback.
- Add ACPI MADT discovery before relying on APIC addresses/routing generally.
- Add Local APIC support:
  - map LAPIC MMIO;
  - enable LAPIC;
  - configure spurious vector;
  - send LAPIC EOI.
- Add I/O APIC support:
  - map I/O APIC MMIO;
  - program redirection-table entries;
  - honor IRQ source overrides from MADT.
- Mask/disable legacy PIC once APIC routing is active.

Success criteria:

- Interrupt code calls a controller boundary, not PIC/APIC internals directly.
- Legacy PIC remains available as bootstrap/fallback behavior.
- APIC routing is based on discovered platform data rather than hardcoded QEMU assumptions.

---

### 2. [~] Replace interrupt hot-path console spam with structured diagnostics

Relevant file:

- `src/architecture/x86/interrupts/main.zig`
- `src/architecture/x86/interrupts/diagnostics.zig`
- `src/architecture/x86/interrupts/vectors.zig`

Status: partially implemented for bring-up readability. Console diagnostics are still intentionally present, but normal interrupt output is bounded and the diagnostic policy has been separated from the main dispatcher.

Completed partial deliverables:

- Added first-hit/rate-limited interrupt diagnostics for bring-up verification.
- Moved temporary diagnostic state and policy into `diagnostics.zig`.
- Added named interrupt-vector constants in `vectors.zig`.
- Extracted page-fault decoding into a named helper to make the page-fault case easier to read.

Remaining concern:

The current interrupt handler still uses console output and direct switch-based dispatch. This is acceptable for early bring-up, but it should not be treated as the final interrupt diagnostics architecture.

Recommended deliverables:

- Remove or compile-gate console printing from normal interrupt paths once bring-up verification is complete.
- Keep detailed output for fatal exception paths only.
- Add a build-gated or comptime-gated tracing mechanism.
- Prefer counters/ring-buffer tracing for hot-path events.
- Continue separating x86 vector decoding from common fault/interrupt policy.

Success criteria:

- Timer interrupts do not print unconditionally.
- Successfully resolved page faults are silent.
- Fatal exceptions still provide useful diagnostics.

---

### 3. [x] Split VMM fault resolution from fatal interrupt-boundary behavior

Relevant file:

- `src/common/memory_management/vmm.zig`

Status: completed. `faultHandler()` is now a thin interrupt-boundary wrapper, while lower-level VMM fault resolution is explicitly fallible and testable.

Completed deliverables:

```zig
pub fn resolveFault(fault_info: arch.FaultInfo) VMMError!void
pub fn faultHandler(fault_info: arch.FaultInfo) void
```

- Moved demand-page resolution into `resolveFault()`.
- Let `faultHandler()` call `resolveFault()` and panic only at the top-level fatal boundary.
- Added VMM errors for:
  - early fault before memory management is active;
  - fault outside a VMA;
  - protection violation;
  - PMM allocation failure;
  - MMU mapping failure.
- Added tests for previously panic-only early fault and outside-VMA fault cases.

Verification:

- `zig fmt src/common/memory_management/vmm.zig src/architecture/mock/mmu/main.zig tests/vmm_tests.zig` completed with exit code `0`.
- `timeout 60s zig build tests` completed with exit code `0`.
- `zig build` completed with exit code `0`.
- `git diff --check` reported no whitespace/check errors for the VMM-related files.

Success criteria:

- Tests can assert unresolved/protection fault errors without expected-panic infrastructure.
- Existing successful demand-fault tests still pass.
- Panic behavior is isolated to the boundary where recovery is impossible.

---

### 4. [x] Handle VMM protection faults explicitly

Relevant file:

- `src/common/memory_management/vmm.zig`

Status: completed. Present-page faults and requested accesses that violate VMA permissions now return `VMMError.ProtectionViolation` from `resolveFault()` instead of disappearing silently.

Completed deliverables:

- Detect protection faults and return explicit errors from `resolveFault()`.
- Check requested access against VMA permissions:
  - write fault requires `writeable`;
  - user fault requires `user_accessible`;
  - instruction fetch requires `executable`.
- Documented the current 32-bit non-PAE x86 execute/NX limitation in the VMM permission check.
- Added VMM tests for present-page faults, write-to-read-only faults, user-to-supervisor faults, and instruction-fetch-from-non-executable faults.

Success criteria:

- Present-page faults do not disappear silently.
- Tests cover write/user/instruction-fetch violations.

---

### 5. Fix PMM `reserve()` silent out-of-bounds behavior

Relevant file:

- `src/common/memory_management/pmm.zig`

`reserve()` currently returns without error when a range exceeds `totalFrames`. Silent failure in memory reservation can corrupt later allocation assumptions.

Recommended deliverables:

- Return `PmmError.InvalidIndex` or a new `PmmError.InvalidRange` for invalid ranges.
- Add tests for out-of-bounds reservation.

Success criteria:

- Invalid reservations fail explicitly.
- Boot memory-map mistakes are easier to detect.

---

## High Priority

### 6. Extract host-testable kernel initialization

Relevant files:

- `src/kernel.zig`
- `tests/kernel_common_tests.zig` or a new integration test file

`kernelMain()` still mixes initialization, diagnostics, timer startup, and demo heap allocation behavior.

Recommended deliverables:

- Extract a non-exported or public testable initialization function:

```zig
fn kernelInitialize() KernelInitError!void
```

- Split boot into named stages:
  - terminal initialization;
  - kernel address-space setup;
  - PMM initialization;
  - boot finalization;
  - interrupt initialization;
  - kernel heap VMA setup;
  - kernel heap initialization.
- Move the hardcoded 10 MiB allocation/write probe behind a debug self-test option or into tests.

Success criteria:

- `kernelMain()` is a thin exported wrapper.
- Initialization order is clear and testable.
- Demo/probing behavior is not always part of boot.

---

### 7. [x] Improve mock MMU behavioral parity

Relevant file:

- `src/architecture/mock/mmu/main.zig`

Status: completed for page-mapping behavior needed by current VMM tests. Mock memory-map lifecycle stability remains tracked separately in item 8.

Completed deliverables:

```zig
const MockPageMapping = struct {
    virtual_page: usize,
    physical_page: usize,
    protection: arch.PageProtection,
    present: bool,
};
```

- Implemented meaningful `mapPage()` with page-table presence validation.
- Implemented meaningful `unmapPage()` that marks mapped pages non-present.
- Implemented `getPhysicalAddress()` using stored page mappings.
- Stored and exposed mapped-page permissions for tests.
- Added test helpers:

```zig
pub fn resetForTest() void
pub fn getMappedPageForTest(virtual_address: usize) ?MockPageMapping
```

- Added VMM tests that assert mapped pages, physical-address lookup availability, and propagated permissions.

Success criteria:

- VMM tests can assert physical-address mappings and permissions.
- Duplicate/missing mappings can be detected in tests.

---

### 8. Stabilize mock memory-map lifecycle

Relevant file:

- `src/architecture/mock/mmu/main.zig`

`getMemoryMap()` allocates a new 64 MiB host region on every call. Tests currently rely on this behavior, but it leaks host memory and hides lifecycle bugs.

Recommended deliverables:

- Add explicit setup/reset helpers:

```zig
pub fn resetForTest() void
pub fn initializeTestMemory(size: usize) !void
```

- Make `getMemoryMap()` return stable mock state rather than allocate implicitly.

Success criteria:

- Test memory setup is explicit.
- Repeated memory-map reads are stable and do not allocate unexpectedly.

---

### 9. Make x86 `mmu.unmapPage()` safe for absent tables/pages

Relevant file:

- `src/architecture/x86/mmu/main.zig`

`unmapPage()` currently assumes the page directory entry is present before retrieving the page table.

Recommended deliverables:

- Define explicit semantics:
  - either absent mappings are a no-op;
  - or absent mappings return `arch.MmuError.PageTableNotPresent`.
- Update the architecture interface if `unmapPage()` becomes fallible.
- Keep mock behavior in parity with x86 behavior.

Success criteria:

- Unmapping an unmapped page cannot access an invalid page table.
- Common code can reason about unmap failure/no-op behavior.

---

### 10. Clean up PMM state transitions and accounting

Relevant file:

- `src/common/memory_management/pmm.zig`

PMM accounting can drift when reserving over already-reserved frames, freeing unused frames, or using `trackAllocationsAsReserved`.

Recommended deliverables:

- Model frame state transitions explicitly:
  - `Free -> Used`;
  - `Free -> Reserved`;
  - `Used -> Free`;
  - reserved frames cannot be freed.
- Decide whether reservation is idempotent or an error.
- Add tests for:
  - double-free;
  - freeing unused frames;
  - reserve-over-used;
  - reserve-over-reserved;
  - invalid ranges.

Success criteria:

- `totalAvailableFrames`, `currentAvailableFrames`, and `totalSystemFrames` stay consistent across tested transitions.

---

### 11. Replace or improve PMM linear allocation scan

Relevant file:

- `src/common/memory_management/pmm.zig`

PMM allocation currently performs an O(n) scan over all frames. This is acceptable temporarily but not as a long-term kernel allocator path.

Recommended staged path:

1. Add a `next_search_frame` cursor for a low-risk short-term improvement.
2. Move to a bitmap allocator for used/free state.
3. Consider a buddy allocator later if contiguous multi-frame allocations become common.

Success criteria:

- Allocation behavior remains correct under fragmentation tests.
- Performance-sensitive allocation paths no longer always scan from frame zero.

---

### 12. [x] Fix kernel heap dynamic allocation accounting

Relevant file:

- `src/common/memory_management/kernel_heap.zig`

Status: completed for the current block-based accounting metric. The old API name remains as a compatibility alias, but the tracked value now represents allocated heap block bytes rather than originally requested payload bytes.

Completed deliverables:

- Renamed the internal counter to `allocatedBlockBytes`.
- `kmalloc()` now adds the actual allocated heap block size.
- `kfree()` subtracts the same heap block size before returning the block to the generic heap.
- Added `getAllocatedBlockBytes()`.
- Kept `getDynamicAllocationSize()` as a compatibility alias.
- Removed hidden MMU/PMM page decommit from the normal `kfree()` path.

Success criteria:

- Allocation accounting cannot underflow or misrepresent dynamic usage after frees.

---

### 12a. [x] Rewrite generic heap internals for readability

Relevant files:

- `src/common/memory_management/heap.zig`
- `src/common/memory_management/kernel_heap.zig`
- `tests/heap_tests.zig`

Status: completed for the generic heap allocator. `kernel_heap.zig` still has separate policy/accounting issues tracked in item 12 and later heap-reclamation work.

Completed deliverables:

- Rewrote `heap.zig` around named concepts:
  - allocation layout calculation;
  - block initialization;
  - allocation tags for recovering headers from aligned user pointers;
  - free-list insertion/removal;
  - next/previous coalescing;
  - in-place resize helpers.
- Preserved the public `Heap` API:
  - `initialize`;
  - `allocate`;
  - `free`;
  - `resize`;
  - `allocator`.
- Updated `kernel_heap.zig` to use `heap.getBlockHeaderFromAllocation()` instead of assuming the block header is immediately before the user pointer.
- Added a focused test for freeing and reusing a highly aligned allocation.

Success criteria:

- `zig build tests` passes.
- `zig build` passes.
- `allocate()`, `free()`, and `resize()` are organized around named helpers rather than large inline pointer-arithmetic workflows.

---

## Medium Priority

### 13. Decouple architecture MMU mechanisms from kernel heap sizing policy

Relevant files:

- `src/architecture/x86/mmu/main.zig`
- `src/kernel.zig`
- `src/common/memory_management/kernel_heap.zig`

The x86 MMU currently imports `kernel_common` to compute heap size from PMM state. Heap sizing is kernel policy, not an MMU mechanism.

Recommended deliverables:

- Make x86 MMU expose address-space layout constants/capabilities only.
- Move heap-size calculation into kernel initialization or a common memory policy module.
- Eventually remove `arch.addImport("kernel_common", kernel_common)` from `build.zig`.

Success criteria:

- Architecture implementation no longer depends on common kernel policy for heap sizing.

---

### 14. Introduce a kernel fault/interrupt dispatch boundary

Relevant files:

- `src/architecture/x86/interrupts/main.zig`
- proposed: `src/common/interrupts/main.zig` or `src/common/faults/main.zig`

x86 interrupt code currently decodes the page fault and directly calls `kernel_common.vmm.faultHandler()`.

Recommended deliverables:

- Keep x86-specific register/error-code decoding in x86 code.
- Route decoded architecture-independent fault records to common kernel dispatch.
- Let common dispatch call VMM, scheduler, or future process fault policy.

Success criteria:

- x86 interrupt code does not import broad `kernel_common` policy.
- Fault handling has a clear architecture-independent policy boundary.

---

### 15. Add architecture MMU capabilities

Relevant files:

- `src/architecture/architecture.zig`
- `src/architecture/x86/mmu/main.zig`
- `src/architecture/mock/mmu/main.zig`
- `src/common/memory_management/vmm.zig`

`arch.PageProtection.execute` exists, but 32-bit non-PAE x86 cannot enforce NX.

Recommended deliverables:

```zig
pub const MmuCapabilities = struct {
    supports_no_execute: bool,
    supports_user_pages: bool,
    supports_global_pages: bool,
};
```

- Add `getCapabilities()` or equivalent to the MMU interface.
- Let VMM reject unsupported permissions or document them as advisory.

Success criteria:

- Permission semantics are explicit per architecture.
- Tests can assert behavior for unsupported permission combinations.

---

### 16. Make mock platform and interrupts observable

Relevant files:

- `src/architecture/mock/platform/main.zig`
- `src/architecture/mock/interrupts/main.zig`

Mock platform/interrupt implementations currently have shape parity but little behavior.

Recommended deliverables:

- Track interrupt enabled/disabled state.
- Track registered interrupt vectors.
- Track acknowledgement counters.
- Buffer console output for assertions.
- Track timer initialization frequency.

Success criteria:

- Kernel initialization and interrupt behavior can be integration-tested on host.

---

### 17. Rework kernel heap page reclamation policy

Relevant file:

- `src/common/memory_management/kernel_heap.zig`

`kfree()` currently attempts to unmap and return physical pages for fully contained pages on every free. This couples normal heap freeing to physical decommit policy.

Recommended deliverables:

- Separate heap free-list behavior from physical page reclamation.
- Track reserved heap range separately from committed physical pages.
- Add an explicit shrink/decommit path for memory pressure or thresholds.

Success criteria:

- Normal `free()` is cheap and local to heap metadata.
- Physical reclamation is explicit and testable.

---

## Lower Priority / Strategic

### 18. Split QEMU run and debug build steps

Relevant file:

- `build.zig`

`zig build run` currently starts QEMU paused under GDB with `-S -s`.

Recommended deliverables:

- `zig build run`: normal unpaused QEMU execution.
- `zig build debug-qemu`: paused GDB-oriented execution.
- Later: QEMU smoke-test mode with deterministic success marker.

Success criteria:

- Normal run and debugger run workflows are distinct.

---

### 19. Add more verification build steps

Relevant file:

- `build.zig`

Recommended deliverables:

- Add or document formatting check.
- Add compile-only/check step if supported by the current Zig version.
- Split unit and future integration test steps.
- Consider automated QEMU smoke tests once serial output or exit signaling is stable.

Success criteria:

- Development workflow has fast, explicit validation modes.

---

### 20. Decide and document physical address width policy

Relevant files:

- `src/common/memory_management/pmm.zig`
- `src/architecture/early_allocator.zig`
- `src/architecture/architecture.zig`

Several common paths truncate `u64` memory-map addresses to `usize`. On 32-bit x86 this may be acceptable temporarily, but it should be explicit.

Recommended deliverables:

- If the near-term target is 32-bit only, reject or cap memory-map regions above the addressable range.
- If x86_64 is planned soon, introduce explicit `PhysicalAddress` typing in common interfaces.

Success criteria:

- Address-width limitations are explicit and checked.

---

### 21. Define the initial microkernel object model

Relevant future domains:

- scheduler/thread model;
- address-space objects;
- IPC endpoints/messages;
- capability or handle table;
- syscall ABI;
- interrupt-to-driver delivery.

Recommended deliverables:

- Write a short design note before adding many drivers or services.
- Define how address spaces, threads, and IPC endpoints relate.
- Decide how hardware interrupts become driver-visible events.

Success criteria:

- Future subsystems are added around a microkernel direction rather than a growing monolithic core.

---

### 22. Remove or justify unused PMM helper `markFrames()`

Relevant file:

- `src/common/memory_management/pmm.zig`

`markFrames()` currently has no callers.

Recommended deliverables:

- Remove it if obsolete, or
- reintroduce it deliberately as part of a clearer PMM initialization/state-transition pipeline.

Success criteria:

- No unused helper remains without a documented purpose.

---

## Suggested Next Implementation Slices

Two good next slices are available, depending on whether the next focus should be interrupt architecture or memory-management correctness.

### Option A: Interrupt-controller/APIC direction

1. Add `src/architecture/x86/interrupts/controller.zig` as a small controller boundary.
2. Route current interrupt acknowledgement and IRQ enable/disable calls through the controller boundary.
3. Keep `pic.zig` as the initial backend.
4. Start ACPI RSDP/SDT/MADT discovery as the prerequisite for proper APIC support.

Recommended verification for this slice:

```sh
zig fmt src/architecture/x86/interrupts/controller.zig src/architecture/x86/interrupts/*.zig
zig build
```

### Option B: [x] VMM fault correctness and testability

Status: completed.

1. Split `vmm.resolveFault()` from `vmm.faultHandler()`.
2. Added explicit VMM protection fault handling.
3. Improved mock MMU page mapping behavior enough to assert physical addresses and permissions.
4. Added tests for fault-outside-VMA and protection faults.

Recommended verification for this slice:

```sh
zig fmt src/common/memory_management/vmm.zig src/architecture/mock/mmu/main.zig tests/vmm_tests.zig
timeout 60s zig build tests
zig build
```
