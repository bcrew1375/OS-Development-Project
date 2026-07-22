# Project: OS Development - an early development hobby kernel.

## General Instructions:
- Aim for a general purpose kernel with modern production-grade design patterns.
- Aim for code clarity. Avoid internal abbreviations, but prefer industry-standard acronyms (e.g., ACPI, MMU, PCIe) where they aid recognition.
- Aim for common code whenever possible. Architecture-dependent code should be minimal.
- If a compromise must absolutely be made between efficiency and clarity, prefer clarity, except in performance-critical paths (e.g., context switching, MMU hot-paths) where efficiency may take precedence if documented.
- Prefer static polymorphism (e.g., Zig's comptime) over dynamic dispatch to maintain performance with high abstraction.
- Error handling must be explicit. Use Zig's error union types; avoid catching errors unless they can be recovered from.

## Coding style
- Use typical Zig or C++ identifier casing. Do not abbreviate identifiers.
- Prefer abstraction and generic interfaces whenever possible.
- Define common interfaces for architectural components before implementing them for specific hardware or mocks.
- Prefer "self-commenting" code. Use explicit comments sparingly only when complexity necessitates it.
- Architecture component code should be kept in a related folder managed by a main.zig file when possible.

## Testing
- Tests should be categorized under the 'tests' subfolder. Do not inject tests into source files.
- The mock architecture should be capable of testing any arch-independent and common code.
- The mock architecture must maintain 1:1 interface parity with physical architecture implementations.
- Mock architecture functions and code should always be kept in a related component folder managed by a main.zig file.
