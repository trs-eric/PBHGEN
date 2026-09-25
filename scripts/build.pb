; Reproducible, timeout-bounded PBHGEN build entry point.

EnableExplicit

#DefaultTimeoutSeconds = 60

Structure ProcessResult
  ExitCode.i
  TimedOut.i
  Output.s
EndStructure

Procedure PrintUsage()
  PrintN("Usage: build.exe --compiler path --source Entry.pb --output PBHGEN.exe [--timeout seconds]")
EndProcedure

Procedure RunBounded(Program.s, Arguments.s, WorkingDirectory.s,
                     TimeoutSeconds.i, *Result.ProcessResult)
  Protected Process.i
  Protected Started.i = ElapsedMilliseconds()

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
      *Result\Output + ReadProgramString(Process) + #LF$
    Wend
    If ElapsedMilliseconds() - Started >= TimeoutSeconds * 1000
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

Procedure.i Main()
  Protected Index.i
  Protected Argument.s
  Protected Compiler.s, Source.s, Output.s
  Protected TimeoutSeconds.i = #DefaultTimeoutSeconds
  Protected CompileArguments.s
  Protected Result.ProcessResult
  Protected VersionResult.ProcessResult
  Protected VersionText.s

  OpenConsole()
  Index = 0
  While Index < CountProgramParameters()
    Argument = LCase(ProgramParameter(Index))
    Select Argument
      Case "--compiler"
        Index + 1
        If Index < CountProgramParameters()
          Compiler = ProgramParameter(Index)
        EndIf
      Case "--source"
        Index + 1
        If Index < CountProgramParameters()
          Source = ProgramParameter(Index)
        EndIf
      Case "--output"
        Index + 1
        If Index < CountProgramParameters()
          Output = ProgramParameter(Index)
        EndIf
      Case "--timeout"
        Index + 1
        If Index < CountProgramParameters()
          TimeoutSeconds = Val(ProgramParameter(Index))
        EndIf
      Default
        PrintN("Unknown option: " + ProgramParameter(Index))
        PrintUsage()
        ProcedureReturn 2
    EndSelect
    Index + 1
  Wend

  If Compiler = "" Or Source = "" Or Output = "" Or
     TimeoutSeconds < 1 Or TimeoutSeconds > 600
    PrintUsage()
    ProcedureReturn 2
  EndIf
  If FileSize(Compiler) < 0
    PrintN("Compiler not found: " + Compiler)
    ProcedureReturn 3
  EndIf
  If FileSize(Source) < 0
    PrintN("Source not found: " + Source)
    ProcedureReturn 3
  EndIf
  If FileSize(GetPathPart(Output)) <> -2
    PrintN("Output directory not found: " + GetPathPart(Output))
    ProcedureReturn 3
  EndIf

  CompileArguments = #DQUOTE$ + Source + #DQUOTE$ +
                     " /CONSOLE /THREAD /OUTPUT " + #DQUOTE$ + Output + #DQUOTE$
  If Not RunBounded(Compiler, CompileArguments, GetPathPart(Source),
                    TimeoutSeconds, @Result)
    If Result\TimedOut
      PrintN("Compiler timed out after " + Str(TimeoutSeconds) + " seconds")
    Else
      PrintN("Unable to start compiler: " + Compiler)
    EndIf
    ProcedureReturn 3
  EndIf

  If Result\Output <> ""
    Print(Result\Output)
  EndIf
  If Result\ExitCode <> 0
    ProcedureReturn Result\ExitCode
  EndIf
  If Not RunBounded(Output, "--version", GetPathPart(Output), 10, @VersionResult) Or
     VersionResult\ExitCode <> 0
    PrintN("Built executable did not pass its version check: " + Output)
    ProcedureReturn 3
  EndIf
  VersionText = ReplaceString(VersionResult\Output, #CR$, "")
  VersionText = ReplaceString(VersionText, #LF$, "")
  PrintN("Built " + Trim(VersionText) + ": " + Output)
  ProcedureReturn 0
EndProcedure

End Main()
