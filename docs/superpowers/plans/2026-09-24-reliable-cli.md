# PBHGEN Reliable CLI and Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. The user
> requested local execution without delegated agents.

**Goal:** Complete all seven PBHGEN reliability backlog items with a stable CLI,
safe output, exact diagnostics, public regression coverage, and reproducible
Windows build evidence.

**Architecture:** Retain one public executable and the existing parser state
machine. Refactor `Entry.pb` into explicit command-line, generation,
diagnostic, comparison, and replacement procedures. Generate fully before any
destination mutation, and exercise the executable through a timeout-bounded
PureBasic black-box suite.

**Tech stack:** PureBasic, PBHGEN-generated `Entry.pbi`, Git golden fixtures,
Windows process and atomic-file APIs behind narrow adapters

**Spec:** `docs/superpowers/specs/2026-09-24-reliable-cli-design.md`

## Global constraints

- Work only in the standalone PBHGEN repository worktree.
- Keep changes suitable for all public PBHGEN users and preserve the MIT
  license and upstream attribution.
- Push only to `trs-eric/PBHGEN`, and only after explicit user instruction.
- Do not add or commit PowerShell test files.
- Build with the explicitly selected external compiler; never modify or copy
  the compiler into the repository.
- Give every compiler and child executable a finite timeout.
- Use test-driven development: observe the focused failure before each
  behavioral implementation.
- Rebuild PBHGEN after parser changes, regenerate `Entry.pbi`, and rerun the
  focused golden fixture.
- Keep each of the seven stage commits independently reviewable.

## Stage 1: Deterministic synchronous execution

**Files:**

- Create: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add a bounded black-box test proving success exits only after the complete
      adjacent header can be opened and compared.
- [ ] Add failing cases for missing source and unwritable destination exit
      status.
- [ ] Refactor the current top-level flow into `GenerateSource()` and `Main()`
      procedures returning explicit exit codes.
- [ ] Ensure all file handles close before success and every error returns
      nonzero.
- [ ] Regenerate `Entry.pbi`, run the focused CLI tests, run existing golden
      fixtures, and check the diff.
- [ ] Commit: `Add deterministic synchronous generation`

## Stage 2: Golden regressions and precise failures

**Files:**

- Create: golden `source.pb` and `expected.pbi` files under new
  `tests/fixtures/real-project-regressions/` and
  `tests/fixtures/incomplete-signature/`
- Modify: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add byte-exact fixtures combining real multiline, quoted-colon,
      escaped-string, module, macro, collection, and typed-pointer syntax.
- [ ] Add a red test for an incomplete signature that expects exit `4`, exact
      diagnostic code `PARSE001`, the declaration's starting line, and no
      destination modification.
- [ ] Carry physical source origins into logical statements and add a diagnostic
      record with human and JSON serialization helpers.
- [ ] Reject incomplete or structurally invalid recognized declarations before
      output installation.
- [ ] Regenerate `Entry.pbi`, run all parser goldens and CLI diagnostics, and
      check the diff.
- [ ] Commit: `Add precise parser diagnostics`

## Stage 3: Preserve the first logical statement

**Files:**

- Create: `tests/fixtures/first-statement/source.pb`
- Create: `tests/fixtures/first-statement/expected.pbi`
- Modify: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add a red golden test whose first byte begins a procedure declaration.
- [ ] Separate header-prologue emission from `ParseLine()` so line zero is
      parsed normally.
- [ ] Verify first-line procedures globally and inside representative normal
      files without changing the header layout.
- [ ] Regenerate `Entry.pbi`, run all goldens, and check the diff.
- [ ] Commit: `Preserve first source declaration`

## Stage 4: Atomic, content-stable output

**Files:**

- Modify: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add red tests proving an identical generation preserves last-write time,
      a changed generation replaces the complete file, and a parser or I/O
      failure preserves the old bytes.
- [ ] Generate complete content before opening any destination.
- [ ] Write a unique sibling temporary file, flush and close it, compare bytes,
      and remove it when content is identical.
- [ ] Add a narrow Windows atomic-replace adapter and cleanup on all handled
      failures.
- [ ] Regenerate `Entry.pbi`, run atomic-output and complete regression tests,
      and check for leaked temporary files.
- [ ] Commit: `Write generated headers atomically`

## Stage 5: Explicit batch invocation

**Files:**

- Create: batch golden `source.pb` and `expected.pbi` files under
  `tests/fixtures/batch-first/` and `tests/fixtures/batch-second/`
- Modify: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add red tests for `--batch`, ordered results, paths containing spaces,
      stop-on-first-failure, and preserved completed outputs.
- [ ] Parse explicit batch sources without changing the legacy joined single
      path behavior.
- [ ] Reset all parser state between sources and process each exactly once.
- [ ] Regenerate `Entry.pbi`, run focused batch and full tests, and check the
      diff.
- [ ] Commit: `Add batch header generation`

## Stage 6: Check, output, version, and JSON diagnostics

**Files:**

- Modify: `tests/cli_tests.pb`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

- [ ] Add red tests for `--check` current, stale, and missing outcomes;
      `--output`; `--version`; JSON success and error records; JSON escaping;
      and invalid combinations.
- [ ] Implement the approved option parser and exit-code table.
- [ ] Reuse in-memory generation and comparison for `--check` without writing.
- [ ] Restrict `--output` to one source and read `--version` from
      `#PBHGEN_VERSION$`.
- [ ] Emit one compact JSON object per source event when requested.
- [ ] Regenerate `Entry.pbi`, run all CLI and golden tests, and check the diff.
- [ ] Commit: `Add automation-friendly CLI options`

## Stage 7: Reproducible build and compatibility matrix

**Files:**

- Create: `scripts/build.pb`
- Create: `COMPATIBILITY.md`
- Modify: `tests/cli_tests.pb`
- Modify: `README.md`
- Modify locally only: ignored `TODO.md`

- [ ] Add a red reproducibility test that builds twice from clean temporary
      directories and compares executable metadata and functional output that
      PBHGEN controls. Document unavoidable compiler-produced differences
      rather than hiding them.
- [ ] Implement the bounded PureBasic build entry point with explicit compiler,
      source, and output paths plus fixed flags.
- [ ] Run the entire suite using the available PureBasic 6.41 Windows x64
      compiler and record the exact tested environment and results.
- [ ] Document build and verification commands and distinguish verified rows
      from historical compatibility intent.
- [ ] Mark all seven ignored local TODO entries complete.
- [ ] Run a clean final build, full bounded suite, complete golden comparison,
      `git diff --check`, and repository status inspection.
- [ ] Commit: `Document reproducible Windows builds`

## Final review gate

- [ ] Inspect the seven commits individually and as a combined diff.
- [ ] Confirm no executable, temporary file, ignored runner, agent file, or TODO
      file is tracked.
- [ ] Confirm the origin still points only to `trs-eric/PBHGEN` and upstream was
      not modified.
- [ ] Present the implementation, fresh verification evidence, compatibility
      limitations, and commit list to the user before any merge or push.
