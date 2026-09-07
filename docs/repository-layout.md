# Repository Layout

The project is split into three repositories:

- `os-kernel`: the kernel, architecture code, kernel subsystems, kernel tests,
  and boot-image packaging.
- `os-shared`: stable user/kernel ABI definitions and implementation helpers
  usable from both kernel and userspace.
- `os-root-task`: the initial userspace root task, built independently as a
  freestanding ELF executable.

## Dependency direction

```text
os-shared
  ^
  |
  +-- os-kernel
  |
  +-- os-root-task
```

The kernel consumes the root task as an ELF artifact. It must not compile the
root task from source.

## Local development checkout

The current local build scripts expect sibling-style checkouts under the same
workspace root:

```text
/workspace/os-kernel
/workspace/os-shared
/workspace/os-root-task
```

In this transitional workspace, the kernel repository is `/workspace`, while
`/workspace/os-shared` and `/workspace/os-root-task` are independent nested Git
repositories ignored by the kernel repository.

Build order:

```sh
cd /workspace/os-shared
zig build tests

cd /workspace/os-root-task
zig build -Darch=x86_64
zig build -Darch=x86_32

cd /workspace
zig build -Darch=x86_64
zig build -Darch=x86_32
```

The kernel can also consume an explicit root-task artifact path:

```sh
zig build -Darch=x86_64 \
  -Droot-task=/workspace/os-root-task/zig-out/x86_64/bin/root_process.elf
```

## Future package-release step

The current local integration uses direct paths to the sibling checkouts. Once
the independent repositories are hosted and release tags exist, replace those
path imports with pinned Zig package dependencies.