# PBHGEN Parser Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Privately retain the PBHGEN backlog, correctly generate declarations for tab-indented and multiline procedures of arbitrary practical parameter count, and preserve typed structure pointers.

**Architecture:** Keep the existing statement splitter and state machine. Add a timeout-enforced black-box golden-file harness, normalize horizontal whitespace at the statement boundary, collect a complete procedure signature by balancing parentheses outside strings, and narrow `FilterArguments()` so it no longer removes valid pointer types.

**Tech Stack:** PureBasic 5.73 source, Windows PowerShell 5.1-compatible test harness, Git golden fixtures

**Spec:** `docs/superpowers/specs/2026-09-23-parser-boundaries-design.md`

## Global Constraints

- Work only in the standalone PBHGEN repository.
- Keep all changes generally useful and compatible with the MIT-licensed public project.
- Preserve the existing single-source CLI and generated-header layout.
- Use `C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe` only as an explicitly invoked external compiler; never modify it.
- Give every compiler and generated executable process a finite external timeout.
- Do not push, tag, publish, or write to the original `00laboratories/PBHGEN` project.
- Commit each task independently on `master`.

## Review Focus

- An ordinary quoted string containing parentheses must not end signature collection early; covered by the signature-boundaries fixture.
- A closing parenthesis on its own physical line must be included in the declaration; covered by the signature-boundaries fixture.
- An eight-parameter procedure must retain all eight names in order; covered by the signature-boundaries fixture.
- Module-qualified pointer types must retain the `Module::Structure` suffix; covered by the typed-pointers fixture.
- Structured `List`, `Array`, and `Map` parameters must retain their prior generated form; covered by the existing `Test.pb` compatibility fixture.

---

### Task 1: Keep the backlog local

**Files:**
- Modify: `.gitignore`
- Untrack but retain locally: `TODO.md`

**Interfaces:**
- Consumes: the currently tracked root `TODO.md`
- Produces: an ignored local `/TODO.md` whose edits cannot enter later commits accidentally

- [ ] **Step 1: Add the root ignore rule**

Append this repository-root rule beneath the local-agent rule:

```gitignore
# Local development backlog; public work is documented in releases and commits.
/TODO.md
```

- [ ] **Step 2: Remove only the index entry**

Run:

```powershell
git rm --cached -- TODO.md
```

Expected: Git stages `TODO.md` as deleted while the local file still exists.

- [ ] **Step 3: Verify ignore behavior and retained content**

Run:

```powershell
Test-Path -LiteralPath TODO.md
git check-ignore -v TODO.md
git diff --check
```

Expected: `True`, an ignore match for `/TODO.md`, and exit code 0 from `git diff --check`.

- [ ] **Step 4: Commit**

```powershell
git add -- .gitignore
git commit -m "Keep development backlog local"
```

### Task 2: Correct signature boundary parsing

**Files:**
- Create: `tests/run.ps1`
- Create: `tests/fixtures/signature-boundaries/source.pb`
- Create: `tests/fixtures/signature-boundaries/expected.pbi`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `README.md`

**Interfaces:**
- Consumes: `Entry.pb` as the compiler input and fixture directories containing `source.pb` plus `expected.pbi`
- Produces: `tests/run.ps1 -Compiler <path> -Case signature-boundaries`, `TrimStatement(Line$)`, `IsProcedureSignatureComplete(Line$)`, and `CollectProcedureSignature(StartIndex, *LastIndex)`

- [ ] **Step 1: Add the timeout-enforced black-box harness**

Create `tests/run.ps1` with parameters `Compiler`, optional `Case`, and `TimeoutSeconds = 20`. It must:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [string]$Case = '*',
    [ValidateRange(1, 300)][int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('pbhgen-tests-' + [guid]::NewGuid().ToString('N'))
```

Use `Start-Process -PassThru` plus `WaitForExit($TimeoutSeconds * 1000)` for both `pbcompiler.exe` and PBHGEN. Kill and fail any process that exceeds the deadline. Build `Entry.pb` to the scratch directory, copy each selected fixture's `source.pb` there under a unique folder, run PBHGEN on that copy, read both generated and expected files as bytes, and fail with the fixture name when the byte arrays differ. Remove only the GUID-named scratch directory in `finally` after confirming it is under the system temporary directory.

- [ ] **Step 2: Add the failing signature fixture**

Create a source fixture containing a tab-indented procedure and this multiline procedure:

```purebasic
	Procedure.i Tabbed(value.i)
	EndProcedure

Procedure.s ManyParameters(first.i,
                           second.i,
                           third.i,
                           fourth.i,
                           fifth.i,
                           sixth.i,
                           seventh.s = "text (inside)",
                           eighth.i = Max(1, 2)
                          )
  ProcedureReturn seventh
EndProcedure
```

The golden file must contain both complete declarations, including all eight parameters and the final outer `)`.

- [ ] **Step 3: Build and run RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Compiler "C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe" -Case signature-boundaries -TimeoutSeconds 20
```

Expected: FAIL because the current parser does not recognize the leading tab and stops multiline collection before the outer closing parenthesis.

- [ ] **Step 4: Add statement normalization and balanced collection**

In `Entry.pb`, add:

```purebasic
Procedure.s TrimStatement(Line$)
  ProcedureReturn Trim(Trim(Line$), Chr(9))
EndProcedure

Procedure IsProcedureSignatureComplete(Line$)
  Protected Index.i, Depth.i, Started.i, InString.i
  Protected Character$ 
  For Index = 1 To Len(Line$)
    Character$ = Mid(Line$, Index, 1)
    If Character$ = #DQUOTE$
      InString = Bool(Not InString)
    ElseIf Not InString
      If Character$ = ";"
        Break
      ElseIf Character$ = "("
        Depth + 1
        Started = #True
      ElseIf Character$ = ")"
        Depth - 1
        If Started And Depth = 0
          ProcedureReturn #True
        EndIf
      EndIf
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.s CollectProcedureSignature(StartIndex.i, *LastIndex)
  Protected *ResultIndex.Integer = *LastIndex
  Protected Index.i = StartIndex
  Protected Signature$ = TrimStatement(CodeLines$(Index))
  While Not IsProcedureSignatureComplete(Signature$) And Index + 1 < CodeLinesCount
    Index + 1
    Signature$ + " " + TrimStatement(CodeLines$(Index))
  Wend
  *ResultIndex\i = Index
  ProcedureReturn Signature$
EndProcedure
```

Use `TrimStatement()` when logical statements are stored. Before each call to `ParseLine()`, detect a procedure start, call `CollectProcedureSignature()`, and advance the loop index to the last consumed statement. Remove `ContinueNextLine` and the recursive line-consumption block from `FilterArguments()` so it filters exactly one already-complete signature.

- [ ] **Step 5: Run GREEN and the compatibility fixture**

Run the signature fixture command from Step 3.

Expected: PASS for `signature-boundaries`.

Then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Compiler "C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe" -Case existing -TimeoutSeconds 20
```

Expected: PASS against a harness case that copies root `Test.pb` and compares it with root `Test.pbi`.

- [ ] **Step 6: Regenerate the checked-in header and document support**

Build PBHGEN with the bounded harness, run it on a temporary copy of `Entry.pb`, and replace `Entry.pbi` only with that generated result. Update README remarks to state that tab indentation, multiline procedure signatures, and signatures beyond six parameters are supported.

- [ ] **Step 7: Verify and commit**

Run both harness cases together with `-Case '*'`, then run `git diff --check`.

Expected: all selected fixtures pass, all child processes finish within 20 seconds, and the diff check exits 0.

```powershell
git add -- Entry.pb Entry.pbi README.md tests
git commit -m "Handle complete procedure signatures"
```

### Task 3: Preserve typed structure pointers

**Files:**
- Create: `tests/fixtures/typed-pointers/source.pb`
- Create: `tests/fixtures/typed-pointers/expected.pbi`
- Modify: `Entry.pb`
- Modify: `Entry.pbi`
- Modify: `Test.pbi`
- Modify: `README.md`

**Interfaces:**
- Consumes: the Task 2 golden harness and `FilterArguments(Line$)`
- Produces: declarations that retain `.Structure` and `.Module::Structure` suffixes on pointer parameters

- [ ] **Step 1: Add the failing pointer fixture**

Use this source:

```purebasic
Procedure UsePointers(*plain, *typed.Widget, *qualified.Model::Widget, *optional.Widget = #Null)
EndProcedure
```

The expected declaration is:

```purebasic
Declare UsePointers(*plain, *typed.Widget, *qualified.Model::Widget, *optional.Widget = #Null)
```

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Compiler "C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe" -Case typed-pointers -TimeoutSeconds 20
```

Expected: FAIL because `FilterArguments()` currently removes every pointer's structure suffix.

- [ ] **Step 3: Narrow the argument filter**

Remove only this branch from `FilterArguments()`:

```purebasic
If Not IsInString And NextChar = "*"
  IsAtUnwanted = #True
EndIf
```

Keep the `List`, `Array`, and `Map` compatibility behavior unchanged.

- [ ] **Step 4: Run GREEN and update checked-in goldens**

Run the typed-pointer case.

Expected: PASS with all pointer suffixes preserved.

Regenerate `Test.pbi`; its `StructureThing` and `OnVstMain` declarations must now preserve their typed suffixes. Regenerate `Entry.pbi` and update README remarks to document typed structure-pointer support.

- [ ] **Step 5: Run the complete suite**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Compiler "C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe" -Case '*' -TimeoutSeconds 20
git diff --check
```

Expected: signature-boundaries, typed-pointers, and existing compatibility cases all pass; no process times out; diff check exits 0.

- [ ] **Step 6: Commit**

```powershell
git add -- Entry.pb Entry.pbi Test.pbi README.md tests/fixtures/typed-pointers
git commit -m "Preserve typed pointer declarations"
```

### Task 4: Final verification

**Files:**
- Verify only: all files changed by Tasks 1 through 3

**Interfaces:**
- Consumes: all three focused commits
- Produces: fresh evidence that the complete requested scope builds and passes together

- [ ] **Step 1: Inspect scope and repository state**

```powershell
git status --short
git log -4 --oneline
git diff HEAD~3..HEAD --check
```

Expected: only the ignored local `TODO.md` is absent from status; the requested focused commits are present; diff check exits 0.

- [ ] **Step 2: Run the complete bounded suite from a clean scratch directory**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Compiler "C:\Users\eric\Documents\Projects\6dev09\pb-compiler\Compilers\pbcompiler.exe" -Case '*' -TimeoutSeconds 20
```

Expected: every fixture passes and the harness reports zero failures.

- [ ] **Step 3: Inspect final generated declarations**

Verify exact occurrences in the generated goldens:

```powershell
rg -n "Declare\.s ManyParameters|eighth\.i = Max\(1, 2\)|Declare UsePointers|\*qualified\.Model::Widget" tests Test.pbi Entry.pbi
```

Expected: complete multiline and typed-pointer declarations are present with no missing parameters.
