; ----------------------------------------------------------------------- ;
;  -- PureBasic Header Generator                                      --  ;
;  -- Copyright © Henry de Jongh 2013-2021                            --  ;
;  -- http://00laboratories.com/                                      --  ;
;  -- License: MIT                                                    --  ;
; ----------------------------------------------------------------------- ;
;IncludeFile #PB_Compiler_File + "i" ;- PBHGEN

;IncludeFile "Test.pb"

Structure ProgramData
  SourceFileName$         ; the name of the source file being read.
  HeaderFileName$         ; the name of the header file being written.
  SourceFileHandle.i      ; the file read handle of the source file.
  HeaderFileHandle.i      ; the file write handle of the header file.
  
  CurrentLineNumber.l     ; the line number of the line currently parsing.
  CurrentLine$            ; the line text currently being parsed.
  
  CurrentState.a          ; global state flag to identify where we are in syntax.
  
  ModuleName$             ; the name of the module when parsing a module.
  IsSpiderBasic.a         ; whether the source belongs to spider basic.
EndStructure
Global Program.ProgramData

Structure DiagnosticData
  SourceFileName.s
  LineNumber.i
  Code.s
  Message.s
EndStructure
Global LastDiagnostic.DiagnosticData

Enumeration
  #PBHGEN_STATE_GLOBAL
  #PBHGEN_STATE_PROCEDURE
  #PBHGEN_STATE_MACRO
  #PBHGEN_STATE_MODULE_GLOBAL
  #PBHGEN_STATE_MODULE_PROCEDURE
  #PBHGEN_STATE_MODULE_MACRO
EndEnumeration

Program\CurrentLineNumber = 0
Program\CurrentState = #PBHGEN_STATE_GLOBAL

; -----------------------------------------------------------------------------
; Removes horizontal whitespace from both ends of a logical statement.
; -----------------------------------------------------------------------------
Procedure.s TrimStatement(Line$)
  While Len(Line$) > 0 And (Left(Line$, 1) = " " Or Left(Line$, 1) = Chr(9))
    Line$ = Mid(Line$, 2)
  Wend
  While Len(Line$) > 0 And (Right(Line$, 1) = " " Or Right(Line$, 1) = Chr(9))
    Line$ = Left(Line$, Len(Line$) - 1)
  Wend
  ProcedureReturn Line$
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when a quote is preceded by an odd number of backslashes.
; -----------------------------------------------------------------------------
Procedure IsQuoteEscaped(Line$, QuoteIndex.i)
  Protected Index.i = QuoteIndex - 1
  Protected BackslashCount.i
  While Index > 0 And Mid(Line$, Index, 1) = Chr(92)
    BackslashCount + 1
    Index - 1
  Wend
  ProcedureReturn BackslashCount % 2
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when a procedure's outer argument list is balanced.
; -----------------------------------------------------------------------------
Procedure IsProcedureSignatureComplete(Line$)
  Protected Index.i, Depth.i, Started.i, InString.i, EscapedString.i
  Protected Character$
  For Index = 1 To Len(Line$)
    Character$ = Mid(Line$, Index, 1)
    If Character$ = #DQUOTE$
      If InString
        If Not EscapedString Or Not IsQuoteEscaped(Line$, Index)
          InString = #False
          EscapedString = #False
        EndIf
      Else
        InString = #True
        EscapedString = Bool(Index > 1 And Mid(Line$, Index - 1, 1) = "~")
      EndIf
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

; -----------------------------------------------------------------------------
; Removes a trailing comment while preserving semicolons inside strings.
; -----------------------------------------------------------------------------
Procedure.s StripTrailingComment(Line$)
  Protected Index.i, InString.i, EscapedString.i
  Protected Character$
  For Index = 1 To Len(Line$)
    Character$ = Mid(Line$, Index, 1)
    If Character$ = #DQUOTE$
      If InString
        If Not EscapedString Or Not IsQuoteEscaped(Line$, Index)
          InString = #False
          EscapedString = #False
        EndIf
      Else
        InString = #True
        EscapedString = Bool(Index > 1 And Mid(Line$, Index - 1, 1) = "~")
      EndIf
    ElseIf Not InString And Character$ = ";"
      ProcedureReturn TrimStatement(Left(Line$, Index - 1))
    EndIf
  Next
  ProcedureReturn TrimStatement(Line$)
EndProcedure

#PBHGEN_VERSION$ = "5.73"






Procedure ExplodeStringArray(Array a$(1), s$, delimeter$)
  Protected count, i
  count = CountString(s$,delimeter$); + 1
  Dim a$(count)
  For i = 1 To count +1
    a$(i - 1) = StringField(s$,i,delimeter$)
  Next
  ProcedureReturn count ;return count of substrings
EndProcedure

; -----------------------------------------------------------------------------
; * explodes a line of code with module :: and colon : detection.
; -----------------------------------------------------------------------------
; INPUT:
; "line1:myModule::Test():line3:*someModule::Wat::Where():line5"
; -----------------------------------------------------------------------------
; RESULT:
; line1
; myModule::Test()
; line3
; *someModule::Wat::Where()
; line5
; -----------------------------------------------------------------------------
Procedure ExplodeCodeLine(Array Results$(1), Code$)
  Protected Results.l = 0
  Protected Length.l = Len(Code$)
  Protected Index.l = 1
  Protected Accumulator$ = ""
  Protected Character$
  Protected InString.a
  Protected EscapedString.a

  While Index <= Length
    Character$ = Mid(Code$, Index, 1)
    If InString
      Accumulator$ + Character$
      If Character$ = #DQUOTE$ And (Not EscapedString Or Not IsQuoteEscaped(Code$, Index))
        InString = #False
        EscapedString = #False
      EndIf
    Else
      Select Character$
        Case #DQUOTE$
          Accumulator$ + Character$
          InString = #True
          EscapedString = Bool(Index > 1 And Mid(Code$, Index - 1, 1) = "~")
        Case ";"
          Accumulator$ + Mid(Code$, Index, Length - Index + 1)
          Index = Length
        Case ":"
          If Index < Length And Mid(Code$, Index + 1, 1) = ":"
            Accumulator$ + "::"
            Index + 1
          Else
            ReDim Results$(Results)
            Results$(Results) = Accumulator$
            Results + 1
            Accumulator$ = ""
          EndIf
        Default
          Accumulator$ + Character$
      EndSelect
    EndIf
    Index + 1
  Wend

  If Accumulator$ <> "" Or Results = 0
    ReDim Results$(Results)
    Results$(Results) = Accumulator$
    Results + 1
  EndIf

  ProcedureReturn Results
EndProcedure

Global Dim CodeLines$(0)
Global Dim CodeLineNumbers.i(0)
Global CodeLinesCount.l = 0

; -----------------------------------------------------------------------------
; Joins logical statements until the complete procedure signature is present.
; -----------------------------------------------------------------------------
Procedure.s CollectProcedureSignature(StartIndex.i, *LastIndex)
  Protected *ResultIndex.Integer = *LastIndex
  Protected Index.i = StartIndex
  Protected Signature$ = StripTrailingComment(TrimStatement(CodeLines$(Index)))
  Protected NextStatement$
  While Not IsProcedureSignatureComplete(Signature$) And Index + 1 < CodeLinesCount
    Index + 1
    NextStatement$ = StripTrailingComment(TrimStatement(CodeLines$(Index)))
    If NextStatement$ <> ""
      If Right(Signature$, 1) = "," Or Left(NextStatement$, 1) = ")"
        Signature$ + NextStatement$
      Else
        Signature$ + " " + NextStatement$
      EndIf
    EndIf
  Wend
  *ResultIndex\i = Index
  ProcedureReturn Signature$
EndProcedure

Procedure.s FilterArguments(Line$)
  NewL$ = ""
  IsInArguments.c = #False
  IsInString.c = #False
  IsEscapedString.c = #False
  IsAtUnwanted.c = #False
  Skipping.c = #False
  
  CheckDefaultType.c = #False
  FindDefaultType$ = ""
  
  ; For each character in the line
  For i=1 To Len(Line$)
    NextChar.s = Mid(Line$, i, 1)
    
    ; Is in the arguments list
    If IsInArguments = #True
      
      If NextChar = #DQUOTE$ ; chr(34) " double quote
        If IsInString
          If Not IsEscapedString Or Not IsQuoteEscaped(Line$, i)
            IsInString = #False
            IsEscapedString = #False
          EndIf
        Else
          IsInString = #True
          IsEscapedString = Bool(i > 1 And Mid(Line$, i - 1, 1) = "~")
        EndIf
      EndIf
      
      If Not IsInString And LCase(Right(NewL$, 5)) = "list "
        IsAtUnwanted = #True
        CheckDefaultType = #True
      EndIf
      
      If Not IsInString And LCase(Right(NewL$, 6)) = "array "
        IsAtUnwanted = #True
        CheckDefaultType = #True
      EndIf
      
      If Not IsInString And LCase(Right(NewL$, 4)) = "map "
        IsAtUnwanted = #True
        CheckDefaultType = #True
      EndIf
      
      If Not IsInString And NextChar = "." And IsAtUnwanted
        Skipping = #True
      EndIf
      
      If Not IsInString And NextChar = ","
        Skipping = #False
        IsAtUnwanted = #False
      EndIf
      
      If Not IsInString And NextChar = "="
        Skipping = #False
        IsAtUnwanted = #False
      EndIf
      
      If Not IsInString And NextChar = "("
        Skipping = #False
        If CheckDefaultType
          Select LCase(FindDefaultType$)
            Case ".b" : NewL$ + ".b"
            Case ".a" : NewL$ + ".a"
            Case ".c" : NewL$ + ".c"
            Case ".w" : NewL$ + ".w"
            Case ".u" : NewL$ + ".u"
            Case ".c" : NewL$ + ".c"
            Case ".l" : NewL$ + ".l"
            Case ".i" : NewL$ + ".i"
            Case ".f" : NewL$ + ".f"
            Case ".q" : NewL$ + ".q"
            Case ".d" : NewL$ + ".d"
            Case ".s" : NewL$ + ".s"
          EndSelect
          CheckDefaultType = #False
          FindDefaultType$ = ""
        EndIf
      EndIf
      
      If Not IsInString And NextChar = ")"
        Skipping = #False
      EndIf
      
      If Not IsInString And NextChar = ";" ; comment
        Break
      EndIf
      
      If Not Skipping
        NewL$ + NextChar
      Else
        If CheckDefaultType
          FindDefaultType$ + NextChar
        EndIf
      EndIf
      
    EndIf
    
    ; Did not reach arguments yet
    If Not IsInArguments
      If NextChar = "("
        IsInArguments = #True
      EndIf
  
      NewL$ + NextChar
    EndIf
    
  Next
  
  ProcedureReturn NewL$
EndProcedure

; -----------------------------------------------------------------------------
; Output a string to the header file.
; -----------------------------------------------------------------------------
Procedure WriteHeader(Str$)
  WriteString(Program\HeaderFileHandle, Str$)
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this line is a comment otherwise false.
; -----------------------------------------------------------------------------
Procedure IsComment(Line$)
  If Len(Line$) > 0
    If Mid(Line$, 1, 1) = ";"
      ProcedureReturn #True
    EndIf
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is an empty line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsEmpty(Line$)
  If Len(Line$) = 0
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is a procedure statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsBeginProcedure(Line$)
  If Not Len(Line$) >= 10 : ProcedureReturn #False : EndIf ; don't bother when it's too small, speed!
  If LCase(Left(Line$, 10)) = "procedure " ; without return type
    ProcedureReturn #True
  EndIf
  If LCase(Left(Line$, 10)) = "procedure." ; with return type (whatever it may be)
    ProcedureReturn #True
  EndIf
  
  If LCase(Left(Line$, 11)) = "procedurec " ; without return type
    ProcedureReturn #True
  EndIf
  If LCase(Left(Line$, 11)) = "procedurec." ; with return type (whatever it may be)
    ProcedureReturn #True
  EndIf
  
  If LCase(Left(Line$, 13)) = "proceduredll " ; without return type
    ProcedureReturn #True
  EndIf
  If LCase(Left(Line$, 13)) = "proceduredll." ; with return type (whatever it may be)
    ProcedureReturn #True
  EndIf
  
  If LCase(Left(Line$, 14)) = "procedurecdll " ; without return type
    ProcedureReturn #True
  EndIf
  If LCase(Left(Line$, 14)) = "procedurecdll." ; with return type (whatever it may be)
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is an endprocedure statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsEndProcedure(Line$)
  If LCase(Left(Line$, 12)) = "endprocedure"
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is a module statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsBeginModule(Line$)
  If Not Len(Line$) >= 6 : ProcedureReturn #False : EndIf ; don't bother when it's too small, speed!
  If LCase(Left(Line$, 7)) = "module "
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is an endmodule statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsEndModule(Line$)
  If LCase(Left(Line$, 9)) = "endmodule"
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is a macro statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsBeginMacro(Line$)
  If Not Len(Line$) >= 6 : ProcedureReturn #False : EndIf ; don't bother when it's too small, speed!
  If LCase(Left(Line$, 6)) = "macro "
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Returns true when this is an endmacro statement line otherwise false.
; -----------------------------------------------------------------------------
Procedure IsEndMacro(Line$)
  If LCase(Left(Line$, 8)) = "endmacro"
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; -----------------------------------------------------------------------------
; Transforms procedure statement into appropriate declare statement.
; -----------------------------------------------------------------------------
Procedure.s ParseProcedure(Line$)
  If LCase(Left(Line$, 9)) = "procedure"
    ProcedureReturn "Declare" + Mid(Line$, 10)
  EndIf
  
  If LCase(Left(Line$, 10)) = "procedurec"
    ProcedureReturn "DeclareC" + Mid(Line$, 11)
  EndIf
  
  If LCase(Left(Line$, 12)) = "proceduredll"
    ProcedureReturn "DeclareDLL" + Mid(Line$, 13)
  EndIf
  
  If LCase(Left(Line$, 13)) = "procedurecdll"
    ProcedureReturn "DeclareCDLL" + Mid(Line$, 14)
  EndIf
  
  ProcedureReturn "ERROR" ; this can never happen I believe.
EndProcedure

; -----------------------------------------------------------------------------
; Returns the name of the module.
; -----------------------------------------------------------------------------
Procedure.s ParseModuleName(Line$)
  ProcedureReturn Trim(Mid(Line$, 7))
EndProcedure

; -----------------------------------------------------------------------------
; Store and print one precise diagnostic for the current source.
; -----------------------------------------------------------------------------
Procedure SetDiagnostic(SourceFileName.s, LineNumber.i, Code.s, Message.s)
  LastDiagnostic\SourceFileName = SourceFileName
  LastDiagnostic\LineNumber = LineNumber
  LastDiagnostic\Code = Code
  LastDiagnostic\Message = Message
  CompilerIf #PB_Compiler_Console
    PrintN(SourceFileName + "(" + Str(LineNumber) + "): error " + Code + ": " + Message)
  CompilerEndIf
EndProcedure

; -----------------------------------------------------------------------------
; Validate procedure signatures before a destination file can be changed.
; -----------------------------------------------------------------------------
Procedure ValidateLogicalStatements()
  Protected Index.i, LastIndex.i
  Protected State.i = #PBHGEN_STATE_GLOBAL
  Protected Signature.s, Declaration.s

  For Index = 0 To CodeLinesCount - 1
    Select State
      Case #PBHGEN_STATE_GLOBAL, #PBHGEN_STATE_MODULE_GLOBAL
        If IsBeginProcedure(CodeLines$(Index))
          Signature = CollectProcedureSignature(Index, @LastIndex)
          If Not IsProcedureSignatureComplete(Signature)
            SetDiagnostic(Program\SourceFileName$, CodeLineNumbers(Index),
                          "PARSE001", "Incomplete procedure signature")
            ProcedureReturn #False
          EndIf
          Declaration = FilterArguments(ParseProcedure(Signature))
          If Left(Declaration, 7) <> "Declare"
            SetDiagnostic(Program\SourceFileName$, CodeLineNumbers(Index),
                          "PARSE002", "Procedure declaration cannot be represented")
            ProcedureReturn #False
          EndIf
          Index = LastIndex
          If State = #PBHGEN_STATE_GLOBAL
            State = #PBHGEN_STATE_PROCEDURE
          Else
            State = #PBHGEN_STATE_MODULE_PROCEDURE
          EndIf
        ElseIf IsBeginMacro(CodeLines$(Index))
          If State = #PBHGEN_STATE_GLOBAL
            State = #PBHGEN_STATE_MACRO
          Else
            State = #PBHGEN_STATE_MODULE_MACRO
          EndIf
        ElseIf State = #PBHGEN_STATE_GLOBAL And IsBeginModule(CodeLines$(Index))
          State = #PBHGEN_STATE_MODULE_GLOBAL
        ElseIf State = #PBHGEN_STATE_MODULE_GLOBAL And IsEndModule(CodeLines$(Index))
          State = #PBHGEN_STATE_GLOBAL
        EndIf

      Case #PBHGEN_STATE_PROCEDURE
        If IsEndProcedure(CodeLines$(Index))
          State = #PBHGEN_STATE_GLOBAL
        EndIf

      Case #PBHGEN_STATE_MODULE_PROCEDURE
        If IsEndProcedure(CodeLines$(Index))
          State = #PBHGEN_STATE_MODULE_GLOBAL
        EndIf

      Case #PBHGEN_STATE_MACRO
        If IsEndMacro(CodeLines$(Index))
          State = #PBHGEN_STATE_GLOBAL
        EndIf

      Case #PBHGEN_STATE_MODULE_MACRO
        If IsEndMacro(CodeLines$(Index))
          State = #PBHGEN_STATE_MODULE_GLOBAL
        EndIf
    EndSelect
  Next
  ProcedureReturn #True
EndProcedure

; -----------------------------------------------------------------------------
; Write the generated header prologue independently of source parsing.
; -----------------------------------------------------------------------------
Procedure WriteHeaderPrologue()
  WriteHeader(";==============================================================================" + #CRLF$ +
              "; ** " + GetFilePart(Program\SourceFileName$) + " header file by PBHGEN."  + #CRLF$ +
              ";------------------------------------------------------------------------------" + #CRLF$ +
              ";  WARNING: This file is automatically generated each time you save!" + #CRLF$ +
              ";  Any manual changes to this file may be permanently lost upon regeneration." + #CRLF$ +
              ";  If you came here because of a syntax error, double-check your own code." + #CRLF$ +
              ";  For more information, visit https://github.com/00laboratories/PBHGEN" + #CRLF$ +
              ";==============================================================================" + #CRLF$ + #CRLF$)
  WriteHeader("CompilerIf #PB_Compiler_Module = " + #DQUOTE$ + #DQUOTE$ + #CRLF$)
EndProcedure

; -----------------------------------------------------------------------------
; Parse the next line of the source file and output to the header file.
; -----------------------------------------------------------------------------
Procedure ParseLine(Line$)
    ; Leave out empty lines regardless.
    If Not IsEmpty(Line$)
      
      ;WriteHeader("; RAW: " + Line$ + #CRLF$)
      Select Program\CurrentState
          
        Case #PBHGEN_STATE_GLOBAL
          ; Global -> Procedure
          If IsBeginProcedure(Line$)
            Program\CurrentState = #PBHGEN_STATE_PROCEDURE
            Line$ = ParseProcedure(Line$)
            Line$ = FilterArguments(Line$)
            WriteHeader(Line$ + #CRLF$)
          EndIf
          ; Global -> Module
          If IsBeginModule(Line$)
            Program\CurrentState = #PBHGEN_STATE_MODULE_GLOBAL
            Program\ModuleName$ = ParseModuleName(Line$)
            WriteHeader("CompilerEndIf" + #CRLF$ + "CompilerIf #PB_Compiler_Module = " + #DQUOTE$ + Program\ModuleName$ + #DQUOTE$ + #CRLF$)
          EndIf
          ; Global -> Macro
          If IsBeginMacro(Line$)
            Program\CurrentState = #PBHGEN_STATE_MACRO
          EndIf
          
        Case #PBHGEN_STATE_MACRO
          ; Global Macro -> EndMacro
          If IsEndMacro(Line$)
            Program\CurrentState = #PBHGEN_STATE_GLOBAL
          EndIf
          
        Case #PBHGEN_STATE_PROCEDURE
          ; Global Procedure -> EndProcedure
          If IsEndProcedure(Line$)
            Program\CurrentState = #PBHGEN_STATE_GLOBAL
          EndIf
          
        Case #PBHGEN_STATE_MODULE_GLOBAL
          ; Module -> Procedure
          If IsBeginProcedure(Line$)
            Program\CurrentState = #PBHGEN_STATE_MODULE_PROCEDURE
            Line$ = ParseProcedure(Line$)
            Line$ = FilterArguments(Line$)
            WriteHeader(Line$ + #CRLF$)
          EndIf
          ; Module -> EndModule
          If IsEndModule(Line$)
            Program\CurrentState = #PBHGEN_STATE_GLOBAL
            WriteHeader("CompilerEndIf" + #CRLF$ + "CompilerIf #PB_Compiler_Module = " + #DQUOTE$ + #DQUOTE$ + #CRLF$)
          EndIf
          ; Module -> Macro
          If IsBeginMacro(Line$)
            Program\CurrentState = #PBHGEN_STATE_MODULE_MACRO
          EndIf
          
        Case #PBHGEN_STATE_MODULE_MACRO
          ; Module -> EndMacro
          If IsEndMacro(Line$)
            Program\CurrentState = #PBHGEN_STATE_MODULE_GLOBAL
          EndIf
          
        Case #PBHGEN_STATE_MODULE_PROCEDURE
          ; Module -> EndProcedure
          If IsEndProcedure(Line$)
            Program\CurrentState = #PBHGEN_STATE_MODULE_GLOBAL
          EndIf
          
      EndSelect
      
    EndIf
  
  Program\CurrentLineNumber + 1
EndProcedure






; -----------------------------------------------------------------------------
; Generate one adjacent header and return a stable process exit code.
; -----------------------------------------------------------------------------
Procedure.i GenerateSource(SourceFileName.s)
  Protected i.i, ParseIndex.i, LastLineIndex.i, PhysicalLineNumber.i
  Protected CommentDetected.a
  Dim CodeChunks$(0)

  Program\SourceFileName$ = SourceFileName
  Program\CurrentLineNumber = 0
  Program\CurrentState = #PBHGEN_STATE_GLOBAL
  Program\ModuleName$ = ""
  CodeLinesCount = 0
  ReDim CodeLines$(0)
  ReDim CodeLineNumbers(0)
  Select LCase(GetExtensionPart(Program\SourceFileName$))
    Case "pb"
      Program\IsSpiderBasic = #False
    Case "sb"
      Program\IsSpiderBasic = #True
    Default
      SetDiagnostic(Program\SourceFileName$, 0, "IO001", "Unsupported source extension")
      ProcedureReturn 3
  EndSelect

  Program\HeaderFileName$ = Program\SourceFileName$ + "i"
  Program\SourceFileHandle = ReadFile(#PB_Any, Program\SourceFileName$)
  If Not Program\SourceFileHandle
    SetDiagnostic(Program\SourceFileName$, 0, "IO002", "Unable to read source file")
    ProcedureReturn 3
  EndIf

  While Not Eof(Program\SourceFileHandle)
    PhysicalLineNumber + 1
    Program\CurrentLine$ = ReadString(Program\SourceFileHandle)
    ExplodeCodeLine(CodeChunks$(), Program\CurrentLine$)
    CommentDetected = #False

    For i = 0 To ArraySize(CodeChunks$())
      ReDim CodeLines$(CodeLinesCount)
      ReDim CodeLineNumbers(CodeLinesCount)
      CodeLines$(CodeLinesCount) = TrimStatement(CodeChunks$(i))
      CodeLineNumbers(CodeLinesCount) = PhysicalLineNumber

      If LCase(Left(CodeLines$(CodeLinesCount), 8)) = "runtime "
        CodeLines$(CodeLinesCount) = Trim(Mid(CodeLines$(CodeLinesCount), 8))
      EndIf

      If IsComment(CodeLines$(CodeLinesCount))
        CommentDetected = #True
      EndIf
      If CommentDetected
        CodeLines$(CodeLinesCount) = ";" + CodeLines$(CodeLinesCount)
      EndIf

      CodeLinesCount + 1
    Next
  Wend

  CloseFile(Program\SourceFileHandle)
  Program\SourceFileHandle = 0

  If Not ValidateLogicalStatements()
    ProcedureReturn 4
  EndIf

  Program\HeaderFileHandle = CreateFile(#PB_Any, Program\HeaderFileName$)
  If Not Program\HeaderFileHandle
    SetDiagnostic(Program\SourceFileName$, 0, "IO003", "Unable to create destination file")
    ProcedureReturn 3
  EndIf

  WriteHeaderPrologue()

  For ParseIndex = 0 To CodeLinesCount - 1
    Program\CurrentLine$ = CodeLines$(ParseIndex)
    If (Program\CurrentState = #PBHGEN_STATE_GLOBAL Or Program\CurrentState = #PBHGEN_STATE_MODULE_GLOBAL) And
       IsBeginProcedure(Program\CurrentLine$)
      Program\CurrentLine$ = CollectProcedureSignature(ParseIndex, @LastLineIndex)
      ParseIndex = LastLineIndex
    EndIf
    ParseLine(Program\CurrentLine$)
  Next

  WriteHeader("CompilerEndIf")
  CloseFile(Program\HeaderFileHandle)
  Program\HeaderFileHandle = 0
  ProcedureReturn 0
EndProcedure

; -----------------------------------------------------------------------------
; Preserve the legacy IDE behavior that joins an unquoted path containing
; spaces into one source argument.
; -----------------------------------------------------------------------------
Procedure.s LegacySourceArgument()
  Protected Index.i
  Protected SourceFileName.s

  If CountProgramParameters() = 0
    ProcedureReturn ""
  EndIf
  SourceFileName = ProgramParameter(0)
  For Index = 1 To CountProgramParameters() - 1
    SourceFileName + " " + ProgramParameter(Index)
  Next
  ProcedureReturn SourceFileName
EndProcedure

CompilerIf #PB_Compiler_Console
  OpenConsole()
CompilerEndIf
End GenerateSource(LegacySourceArgument())
; IDE Options = PureBasic 5.73 LTS (Windows - x86)
; Folding = ---
; EnableXP
; UseIcon = ..\_Resources [R]\Icons\headers.ico
; Executable = PBHGEN.exe
; Compiler = PureBasic 4.60 (Windows - x86)
; IncludeVersionInfo
; VersionField2 = 00laboratories
; VersionField3 = PB Header Generator
; VersionField6 = Generate PB Header
; VersionField9 = copyright ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© 00laboratories 2013
