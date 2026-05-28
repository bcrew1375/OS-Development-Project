# Project: OS Development - an early development hobby kernel.

## General Instructions:
- Aim for a general purpose kernel with modern production-grade design patterns.
- Aim for code clarity. Avoid abbreviations. Prefer spelling things out, even if it's verbose.
- Aim for common code whenever possible. Architecture-dependent code should be minimal.
- If a compromise must absolutely be made between efficiency and clarity, prefer clarity.
- Avoid hobby kernel "tricks".

## Coding style
- Use typical Zig or C++ identifier casing. Do not abbreviate identifiers.
- Prefer abstraction and generic interfaces whenever possible.
- Prefer "self-commenting" code. Use explicit comments sparingly only when complexity necessitates it.
- Architecture component code should be kept in a related folder managed by a main.zig file when possible.

## Testing
- Tests should be categorized under the 'tests' subfolder. Do not inject tests into source files.
- The mock architecture should be capable of testing any arch-independent and common code.
- Mock architecture functions and code should always be kept in a related component folder managed by a main.zig file.
