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
    Text = ReadString(File, #PB_File_IgnoreEOL)
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

  DeleteDirectory(TestRoot, "*", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
  If Failures
    PrintN(Str(Failures) + " test(s) failed")
    ProcedureReturn 1
  EndIf
  PrintN("PASS")
  ProcedureReturn 0
EndProcedure

End Main()
