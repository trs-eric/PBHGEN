# PBHGEN build and compatibility matrix

This matrix records configurations that have actually compiled PBHGEN and run
the complete bounded parser and command-line regression suite. A configuration
not listed as verified is not necessarily unsupported; it has not yet supplied
repeatable evidence for this checkout.

## Verified configurations

| Date | PureBasic compiler | Host | Architecture | Result |
| --- | --- | --- | --- | --- |
| 2026-09-24 | PureBasic 6.41 | Windows NT 10.0.26200 | x64 | Full CLI and golden suite passed; two clean builds were byte-identical |

PureBasic 5.73 remains the historical source-compatibility target and the
current PBHGEN public version name. It is not marked verified here because that
compiler was not available for this test cycle.

## Reproducible build

Compile the tracked PureBasic build entry point with the compiler being tested:

```powershell
& 'C:\path\to\pbcompiler.exe' `
  'scripts\build.pb' /CONSOLE /OUTPUT 'build\pbhgen-build.exe'
```

Then use the helper with explicit paths:

```powershell
& 'build\pbhgen-build.exe' `
  --compiler 'C:\path\to\pbcompiler.exe' `
  --source 'Entry.pb' `
  --output 'build\PBHGEN.exe' `
  --timeout 60
```

The helper applies the fixed `/CONSOLE /THREAD /OUTPUT` compiler options,
enforces the requested timeout, relays compiler output, and launches the result
with `--version`. It never discovers, copies, or modifies a compiler.

## Verification

Compile the public black-box suite and give every executable an outer timeout:

```powershell
& 'C:\path\to\pbcompiler.exe' `
  'tests\cli_tests.pb' /CONSOLE /OUTPUT 'build\cli_tests.exe'

& 'build\cli_tests.exe' `
  'build\PBHGEN.exe' stage7 `
  'C:\path\to\pbcompiler.exe' `
  'build\pbhgen-build.exe'
```

Stage 7 builds PBHGEN twice in an isolated test directory, compares SHA-256
digests, and launches the result. Running `cli_tests.exe` with only the PBHGEN
path executes the parser, output-safety, batch, and automation-option cases.
Every process wait in the tracked harness has a finite timeout.
