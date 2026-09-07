# Repository Layout

The project is split into three repositories:

- `OS-Development-Project`: the kernel, architecture code, kernel subsystems, kernel tests,
  and boot-image packaging.
- `OS-ABI-Library`: stable user/kernel ABI definitions and implementation helpers
  usable from both kernel and userspace.
- `OS-Root-Task`: the initial userspace root task, built independently as a
  freestanding ELF executable.

## Dependency direction

```text
OS-ABI-Library
  ^
  |
  +-- OS-Development-Project
  |
  +-- OS-Root-Task
```

The kernel consumes the root task as an ELF artifact. It must not compile the
root task from source.

## Submodule checkout

`OS-ABI-Library` and `OS-Root-Task` are tracked by the kernel repository as Git
submodules:

```text
/workspace/OS-Development-Project
/workspace/OS-ABI-Library
/workspace/OS-Root-Task
```

Clone with submodules:

```sh
git clone --recurse-submodules https://github.com/bcrew1375/OS-Development-Project.git
```

Initialize submodules in an existing checkout:

```sh
git submodule update --init --recursive
```

Update submodules to their configured remote branch tips when intentionally
advancing dependencies:

```sh
git submodule update --remote --merge
```

Build order:

```sh
cd /workspace/OS-ABI-Library
zig build tests

cd /workspace/OS-Root-Task
zig build -Darch=x86_64
zig build -Darch=x86_32

cd /workspace
zig build -Darch=x86_64
zig build -Darch=x86_32
```

The kernel build automatically builds the `OS-Root-Task` submodule when
`-Droot-task` is not supplied, so a clean checkout can run `zig build` directly
after submodules are initialized.

The kernel can also consume an explicit root-task artifact path:

```sh
zig build -Darch=x86_64 \
  -Droot-task=/workspace/OS-Root-Task/zig-out/x86_64/bin/root_process.elf
```

## Future package-release step

The current integration uses direct paths to the submodule checkouts. Once
release tags exist and Zig package metadata is finalized, these direct paths can
be replaced with pinned Zig package dependencies.