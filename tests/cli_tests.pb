; PBHGEN command-line regression tests.
;
; Compile as a console program, then pass the PBHGEN executable and an optional
; case name. Every child process has a finite timeout.

EnableExplicit
UseSHA2Fingerprint()

#TestTimeoutMilliseconds = 20000

Structure ProcessResult
  ExitCode.i
  TimedOut.i
  Output.s
EndStructure

Global Failures.i
Global TestRoot.s
Global Generator.s

Procedure ReportFailure(Message.s)
  Failures + 1
  PrintN("FAIL: " + Message)
EndProcedure

Procedure AssertTrue(Condition.i, Message.s)
  If Not Condition
    ReportFailure(Message)
  EndIf
EndProcedure

Procedure.s ReadTextFile(Path.s)
  Protected File.i = ReadFile(#PB_Any, Path)
  Protected Text.s
  If File
    While Not Eof(File)
      Text + ReadString(File) + #LF$
    Wend
    CloseFile(File)
  EndIf
  ProcedureReturn Text
EndProcedure

Procedure WriteTextFile(Path.s, Text.s)
  Protected File.i = CreateFile(#PB_Any, Path)
  If Not File
    ProcedureReturn #False
  EndIf
  WriteString(File, Text, #PB_UTF8)
  CloseFile(File)
  ProcedureReturn #True
EndProcedure

Procedure RunBounded(Program.s, Arguments.s, WorkingDirectory.s, *Result.ProcessResult)
  Protected Process.i
  Protected Started.i = ElapsedMilliseconds()
  Protected Chunk.s

  *Result\ExitCode = -1
  *Result\TimedOut = #False
  *Result\Output = ""

  Process = RunProgram(Program, Arguments, WorkingDirectory,
                       #PB_Program_Open | #PB_Program_Read | #PB_Program_Error)
  If Not Process
    ProcedureReturn #False
  EndIf

  While ProgramRunning(Process)
    While AvailableProgramOutput(Process)
      Chunk = ReadProgramString(Process)
      *Result\Output + Chunk + #LF$
    Wend
    If ElapsedMilliseconds() - Started >= #TestTimeoutMilliseconds
      KillProgram(Process)
      *Result\TimedOut = #True
      CloseProgram(Process)
      ProcedureReturn #False
    EndIf
    Delay(10)
  Wend

  While AvailableProgramOutput(Process)
    *Result\Output + ReadProgramString(Process) + #LF$
  Wend
  *Result\ExitCode = ProgramExitCode(Process)
  CloseProgram(Process)
  ProcedureReturn #True
EndProcedure

Procedure TestSynchronousSuccess()
  Protected Source.s = TestRoot + "synchronous.pb"
  Protected Header.s = Source + "i"
  Protected Result.ProcessResult

  AssertTrue(WriteTextFile(Source,
             "; synchronous completion fixture" + #CRLF$ +
             "Procedure.i Immediate(value.i)" + #CRLF$ +
             "  ProcedureReturn value" + #CRLF$ +
             "EndProcedure" + #CRLF$),
             "create synchronous source")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "generator completes within timeout")
  AssertTrue(Bool(Result\TimedOut = #False), "generator does not time out")
  AssertTrue(Bool(Result\ExitCode = 0),
             "successful generation returns exit code 0 (actual " +
             Str(Result\ExitCode) + "; output " + Result\Output + ")")
  AssertTrue(Bool(FileSize(Header) >= 0), "header exists when process exits")
  AssertTrue(Bool(FindString(ReadTextFile(Header), "Declare.i Immediate(value.i)") > 0),
             "header is complete when process exits")
EndProcedure

Procedure TestMissingSourceStatus()
  Protected Result.ProcessResult
  Protected Missing.s = TestRoot + "missing.pb"

  AssertTrue(RunBounded(Generator, #DQUOTE$ + Missing + #DQUOTE$, TestRoot, @Result),
             "missing-source invocation completes")
  AssertTrue(Bool(Result\ExitCode = 3),
             "missing source returns filesystem exit code 3")
EndProcedure

Procedure TestRealProjectGolden()
  Protected FixtureRoot.s = GetCurrentDirectory() + "tests" + #PS$ +
                            "fixtures" + #PS$ + "real-project-regressions" + #PS$
  Protected Source.s = TestRoot + "source.pb"
  Protected Header.s = Source + "i"
  Protected Result.ProcessResult

  AssertTrue(CopyFile(FixtureRoot + "source.pb", Source),
             "copy real-project source fixture")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "real-project fixture completes")
  AssertTrue(Bool(Result\ExitCode = 0), "real-project fixture succeeds")
  AssertTrue(Bool(ReadTextFile(Header) = ReadTextFile(FixtureRoot + "expected.pbi")),
             "real-project fixture matches its complete golden header")
EndProcedure

Procedure TestIncompleteSignatureDiagnostic()
  Protected FixtureRoot.s = GetCurrentDirectory() + "tests" + #PS$ +
                            "fixtures" + #PS$ + "incomplete-signature" + #PS$
  Protected Source.s = TestRoot + "incomplete.pb"
  Protected Header.s = Source + "i"
  Protected Result.ProcessResult
  Protected ExpectedDiagnostic.s

  AssertTrue(CopyFile(FixtureRoot + "source.pb", Source),
             "copy incomplete-signature source fixture")
  AssertTrue(CopyFile(FixtureRoot + "expected.pbi", Header),
             "create existing header sentinel")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "incomplete-signature invocation completes")
  ExpectedDiagnostic = Source + "(2): error PARSE001: Incomplete procedure signature"
  AssertTrue(Bool(Result\ExitCode = 4),
             "incomplete signature returns parser exit code 4")
  AssertTrue(Bool(FindString(Result\Output, ExpectedDiagnostic) > 0),
             "incomplete signature reports exact source line and code")
  AssertTrue(Bool(ReadTextFile(Header) = ReadTextFile(FixtureRoot + "expected.pbi")),
             "parser failure preserves the existing header")
EndProcedure

Procedure TestFirstLogicalStatement()
  Protected FixtureRoot.s = GetCurrentDirectory() + "tests" + #PS$ +
                            "fixtures" + #PS$ + "first-statement" + #PS$
  Protected Source.s = TestRoot + "source.pb"
  Protected Result.ProcessResult
  Protected Actual.s, Expected.s

  AssertTrue(CopyFile(FixtureRoot + "source.pb", Source),
             "copy first-statement source fixture")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "first-statement fixture completes")
  AssertTrue(Bool(Result\ExitCode = 0), "first-statement fixture succeeds")
  Actual = ReadTextFile(Source + "i")
  Expected = ReadTextFile(FixtureRoot + "expected.pbi")
  AssertTrue(Bool(Actual = Expected),
             "first logical procedure is preserved")
EndProcedure

Procedure TestIdenticalOutputPreservesTimestamp()
  Protected Source.s = TestRoot + "stable.pb"
  Protected Header.s = Source + "i"
  Protected Result.ProcessResult
  Protected OriginalDate.i, CurrentDate.i

  AssertTrue(WriteTextFile(Source,
             "; stable output fixture" + #CRLF$ +
             "Procedure Stable()" + #CRLF$ +
             "EndProcedure" + #CRLF$),
             "create stable-output source")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "initial stable-output generation completes")
  AssertTrue(Bool(Result\ExitCode = 0), "initial stable-output generation succeeds")
  OriginalDate = GetFileDate(Header, #PB_Date_Modified)
  Delay(2100)
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "repeated stable-output generation completes")
  CurrentDate = GetFileDate(Header, #PB_Date_Modified)
  AssertTrue(Bool(Result\ExitCode = 0), "repeated stable-output generation succeeds")
  AssertTrue(Bool(OriginalDate = CurrentDate),
             "identical generation preserves the destination timestamp")
  AssertTrue(WriteTextFile(Source,
             "; changed output fixture" + #CRLF$ +
             "Procedure Stable()" + #CRLF$ +
             "EndProcedure" + #CRLF$ +
             "Procedure Changed()" + #CRLF$ +
             "EndProcedure" + #CRLF$),
             "change stable-output source")
  AssertTrue(RunBounded(Generator, #DQUOTE$ + Source + #DQUOTE$, TestRoot, @Result),
             "changed output generation completes")
  AssertTrue(Bool(Result\ExitCode = 0), "changed output generation succeeds")
  AssertTrue(Bool(FindString(ReadTextFile(Header), "Declare Changed()") > 0),
             "changed output replaces the destination completely")
EndProcedure

Procedure TestBatchGeneration()
  Protected FixtureRoot.s = GetCurrentDirectory() + "tests" + #PS$ +
                            "fixtures" + #PS$
  Protected FirstDirectory.s = TestRoot + "batch-first" + #PS$
  Protected SecondDirectory.s = TestRoot + "batch-second" + #PS$
  Protected FirstSource.s = FirstDirectory + "source.pb"
  Protected SecondSource.s = SecondDirectory + "source.pb"
  Protected Result.ProcessResult
  Protected Arguments.s
  Protected FirstActual.s, FirstExpected.s
  Protected SecondActual.s, SecondExpected.s

  AssertTrue(CreateDirectory(FirstDirectory), "create first batch directory")
  AssertTrue(CreateDirectory(SecondDirectory), "create second batch directory")
  AssertTrue(CopyFile(FixtureRoot + "batch-first" + #PS$ + "source.pb", FirstSource),
             "copy first batch fixture")
  AssertTrue(CopyFile(FixtureRoot + "batch-second" + #PS$ + "source.pb", SecondSource),
             "copy second batch fixture")
  Arguments = "--batch " + FirstSource + " " + SecondSource
  AssertTrue(RunBounded(Generator, Arguments, TestRoot, @Result),
             "batch generation completes")
  AssertTrue(Bool(Result\ExitCode = 0), "batch generation succeeds")
  FirstActual = ReadTextFile(FirstSource + "i")
  FirstExpected = ReadTextFile(FixtureRoot + "batch-first" + #PS$ + "expected.pbi")
  SecondActual = ReadTextFile(SecondSource + "i")
  SecondExpected = ReadTextFile(FixtureRoot + "batch-second" + #PS$ + "expected.pbi")
  AssertTrue(Bool(FirstActual = FirstExpected), "first batch header matches")
  AssertTrue(Bool(SecondActual = SecondExpected), "second batch header matches")
EndProcedure

Procedure TestAutomationOptions()
  Protected Source.s = TestRoot + "options.pb"
  Protected Header.s = Source + "i"
  Protected Selected.s = TestRoot + "selected-output.pbi"
  Protected Result.ProcessResult
  Protected OriginalHeader.s
  Protected JSON.i

  AssertTrue(WriteTextFile(Source,
             "; command-line options fixture" + #CRLF$ +
             "Procedure Options()" + #CRLF$ +
             "EndProcedure" + #CRLF$),
             "create command-line options source")

  AssertTrue(RunBounded(Generator, "--check " + Source, TestRoot, @Result),
             "missing check completes")
  AssertTrue(Bool(Result\ExitCode = 1), "missing check returns stale exit code 1")
  AssertTrue(Bool(FileSize(Header) = -1), "check mode does not create a header")

  AssertTrue(RunBounded(Generator, Source, TestRoot, @Result),
             "options source generation completes")
  OriginalHeader = ReadTextFile(Header)
  AssertTrue(RunBounded(Generator, "--check " + Source, TestRoot, @Result),
             "current check completes")
  AssertTrue(Bool(Result\ExitCode = 0), "current check succeeds")

  AssertTrue(WriteTextFile(Source,
             "; changed command-line options fixture" + #CRLF$ +
             "Procedure Options()" + #CRLF$ +
             "EndProcedure" + #CRLF$ +
             "Procedure Stale()" + #CRLF$ +
             "EndProcedure" + #CRLF$),
             "change command-line options source")
  AssertTrue(RunBounded(Generator, "--check " + Source, TestRoot, @Result),
             "stale check completes")
  AssertTrue(Bool(Result\ExitCode = 1), "stale check returns exit code 1")
  AssertTrue(Bool(ReadTextFile(Header) = OriginalHeader),
             "stale check leaves the header unchanged")

  DeleteFile(Header, #PB_FileSystem_Force)
  AssertTrue(RunBounded(Generator,
             "--output " + Selected + " " + Source, TestRoot, @Result),
             "selected output generation completes")
  AssertTrue(Bool(Result\ExitCode = 0), "selected output succeeds")
  AssertTrue(Bool(FileSize(Selected) >= 0), "selected output is created")
  AssertTrue(Bool(FileSize(Header) = -1), "selected output does not create adjacent output")

  AssertTrue(RunBounded(Generator, "--version", TestRoot, @Result),
             "version query completes")
  AssertTrue(Bool(Result\ExitCode = 0), "version query succeeds")
  AssertTrue(Bool(FindString(Result\Output, "PBHGEN 5.73") > 0),
             "version query uses the public version constant")

  AssertTrue(RunBounded(Generator,
             "--diagnostics json " + TestRoot + "does-not-exist.pb", TestRoot, @Result),
             "JSON error invocation completes")
  AssertTrue(Bool(Result\ExitCode = 3), "JSON filesystem error returns exit code 3")
  AssertTrue(Bool(FindString(Result\Output, ~"\"status\":\"error\"") > 0),
             "JSON diagnostic reports error status")
  AssertTrue(Bool(FindString(Result\Output, ~"\"code\":\"IO002\"") > 0),
             "JSON diagnostic reports stable code")

  AssertTrue(RunBounded(Generator,
             "--diagnostics json " + Source, TestRoot, @Result),
             "JSON success invocation completes")
  AssertTrue(Bool(Result\ExitCode = 0), "JSON success invocation succeeds")
  AssertTrue(Bool(FindString(Result\Output, ~"\"status\":\"ok\"") > 0),
             "JSON diagnostic reports success status")
  JSON = ParseJSON(#PB_Any, Trim(Result\Output))
  AssertTrue(Bool(JSON <> 0), "JSON diagnostic is syntactically valid")
  If JSON
    FreeJSON(JSON)
  EndIf

  AssertTrue(RunBounded(Generator,
             "--batch --output " + Selected + " " + Source, TestRoot, @Result),
             "invalid option combination completes")
  AssertTrue(Bool(Result\ExitCode = 2),
             "batch output selection returns usage exit code 2")
EndProcedure

Procedure TestReproducibleBuild()
  Protected Compiler.s
  Protected Builder.s
  Protected Source.s = GetCurrentDirectory() + "Entry.pb"
  Protected FirstOutput.s = TestRoot + "reproducible-first.exe"
  Protected SecondOutput.s = TestRoot + "reproducible-second.exe"
  Protected Result.ProcessResult
  Protected Arguments.s
  Protected FirstHash.s, SecondHash.s

  If CountProgramParameters() < 4
    ReportFailure("stage7 requires compiler and build-helper paths")
    ProcedureReturn
  EndIf
  Compiler = ProgramParameter(2)
  Builder = ProgramParameter(3)

  Arguments = "--compiler " + Compiler + " --source " + Source +
              " --output " + FirstOutput + " --timeout 30"
  AssertTrue(RunBounded(Builder, Arguments, GetCurrentDirectory(), @Result),
             "first reproducible build completes")
  AssertTrue(Bool(Result\ExitCode = 0), "first reproducible build succeeds")

  Arguments = "--compiler " + Compiler + " --source " + Source +
              " --output " + SecondOutput + " --timeout 30"
  AssertTrue(RunBounded(Builder, Arguments, GetCurrentDirectory(), @Result),
             "second reproducible build completes")
  AssertTrue(Bool(Result\ExitCode = 0), "second reproducible build succeeds")
  AssertTrue(Bool(FindString(Result\Output, #LF$ + ": ") = 0),
             "build summary keeps the version and output path on one line")

  FirstHash = FileFingerprint(FirstOutput, #PB_Cipher_SHA2, 256)
  SecondHash = FileFingerprint(SecondOutput, #PB_Cipher_SHA2, 256)
  AssertTrue(Bool(FirstHash <> ""), "first reproducible build has a SHA-256 digest")
  AssertTrue(Bool(FirstHash = SecondHash), "repeated builds are byte-for-byte reproducible")

  AssertTrue(RunBounded(FirstOutput, "--version", TestRoot, @Result),
             "reproducible executable launches")
  AssertTrue(Bool(Result\ExitCode = 0), "reproducible executable succeeds")
  AssertTrue(Bool(FindString(Result\Output, "PBHGEN 5.73") > 0),
             "reproducible executable reports the expected version")
EndProcedure

Procedure Main()
  Protected CaseName.s

  OpenConsole()
  If CountProgramParameters() < 1
    PrintN("Usage: cli_tests.exe PBHGEN.exe [case]")
    ProcedureReturn 2
  EndIf

  Generator = ProgramParameter(0)
  If CountProgramParameters() > 1
    CaseName = LCase(ProgramParameter(1))
  EndIf

  TestRoot = GetCurrentDirectory() + "build" + #PS$ + "pbhgen-cli-tests-" +
             Str(Date()) + "-" + Str(ElapsedMilliseconds()) + #PS$
  If Not CreateDirectory(TestRoot)
    PrintN("FAIL: unable to create test directory " + TestRoot)
    ProcedureReturn 1
  EndIf

  If CaseName = "" Or CaseName = "stage1"
    TestSynchronousSuccess()
    TestMissingSourceStatus()
  EndIf
  If CaseName = "" Or CaseName = "stage2"
    TestRealProjectGolden()
    TestIncompleteSignatureDiagnostic()
  EndIf
  If CaseName = "" Or CaseName = "stage3"
    TestFirstLogicalStatement()
  EndIf
  If CaseName = "" Or CaseName = "stage4"
    TestIdenticalOutputPreservesTimestamp()
  EndIf
  If CaseName = "" Or CaseName = "stage5"
    TestBatchGeneration()
  EndIf
  If CaseName = "" Or CaseName = "stage6"
    TestAutomationOptions()
  EndIf
  If CaseName = "stage7"
    TestReproducibleBuild()
  EndIf

  DeleteDirectory(TestRoot, "*", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
  If Failures
    PrintN(Str(Failures) + " test(s) failed")
    ProcedureReturn 1
  EndIf
  PrintN("PASS")
  ProcedureReturn 0
EndProcedure

End Main()
