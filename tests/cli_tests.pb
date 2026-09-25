; PBHGEN command-line regression tests.
;
; Compile as a console program, then pass the PBHGEN executable and an optional
; case name. Every child process has a finite timeout.

EnableExplicit

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

  DeleteDirectory(TestRoot, "*", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
  If Failures
    PrintN(Str(Failures) + " test(s) failed")
    ProcedureReturn 1
  EndIf
  PrintN("PASS")
  ProcedureReturn 0
EndProcedure

End Main()
