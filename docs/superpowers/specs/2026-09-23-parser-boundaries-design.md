# PBHGEN Parser Boundaries Design

## Goal

Complete only PBHGEN backlog items 1, 4, and 5 from the approved implementation outline: make the local backlog private to the checkout, correct the known procedure-signature boundary failures, and preserve typed structure pointers in generated declarations.

## Scope

The work has three independently reviewable deliverables:

1. Keep `TODO.md` in the local checkout while removing it from Git tracking and ignoring `/TODO.md` thereafter.
2. Recognize tab-indented procedures and `EndProcedure` statements, assemble multiline procedure signatures safely, and retain every parameter in signatures containing more than six parameters.
3. Preserve the structure suffix on typed pointer parameters, including module-qualified structure names.

The existing one-source-file command-line interface, generated-header layout, module state machine, macro exclusion behavior, and collection-parameter behavior remain compatible unless a scoped regression fixture proves a change is required for these three deliverables.

## Non-goals

This work does not add new CLI modes, batch invocation, atomic output, output selection, machine-readable diagnostics, version flags, reproducible-build automation, or a compatibility matrix. It does not rewrite PBHGEN as a full PureBasic grammar parser.

## Repository housekeeping

`/TODO.md` will be added to `.gitignore`. Because ignored rules do not affect a file already in the Git index, the tracked copy will be removed from the index without deleting the working-tree file. This is a standalone commit and makes no executable change.

## Signature collection and normalization

PBHGEN will continue to split physical source lines into logical colon-delimited statements before parsing. Before classifying each statement, it will remove leading and trailing horizontal whitespace so a leading tab is treated the same as leading spaces.

When a procedure begins, PBHGEN will assemble its declaration text across successive logical statements until the procedure argument list's parentheses are balanced outside string literals. This replaces the current assumption that a continued line is identifiable only by a trailing comma and prevents a fixed parameter-count boundary. The scanner will account for nested parentheses in default expressions and ignore parentheses inside quoted strings. End-of-line comments remain excluded from generated declarations.

The assembled signature will pass through a single argument filter. The filter may remove only syntax that PureBasic cannot accept in a generated `Declare`. It must not drop, reorder, or merge parameters, regardless of parameter count.

## Typed structure pointers

A pointer parameter such as `*value.Widget` will be emitted as `*value.Widget`, not `*value`. Module-qualified types such as `*value.Model::Widget` and default values such as `*value.Widget = #Null` will also remain intact. Pointer names without a type suffix remain unchanged.

This rule applies to procedure pointer parameters. Existing special handling for structured `List`, `Array`, and `Map` parameters is outside this scope and will be protected by a compatibility fixture.

## Tests

A Windows test harness will build PBHGEN using an explicitly supplied `pbcompiler.exe`, execute each fixture in an isolated temporary directory, and enforce finite compile and process timeouts. Golden files will compare complete generated headers byte-for-byte.

Parser fixtures will cover tab-indented procedure starts and ends, multiline signatures with nested default-expression parentheses, a signature with at least eight parameters, typed pointers using plain and module-qualified structure names, typed pointers with a default value, untyped pointers and structured collection parameters as compatibility cases, and existing representative syntax from `Test.pb`.

Each parser behavior will be introduced test-first: its golden fixture must fail against the preceding commit for the intended mismatch, then pass after the smallest parser change. Every child process receives a finite timeout.

## Compatibility and documentation

The implementation remains valid PureBasic 5.73 source and must build with the available Windows x64 compiler. The README will describe the newly supported signature forms and will not claim support for untested platforms or compiler versions. No executable or generated test output will be committed.
