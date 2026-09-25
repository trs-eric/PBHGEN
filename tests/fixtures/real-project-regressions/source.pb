; Representative syntax collected from real PBHGEN consumers.
Procedure.s QuotedColon(text.s = "a:b")
  ProcedureReturn text
EndProcedure

Procedure.i ManyValues(first.i,
                       second.i,
                       *typed.Model::Value,
                       label.s = ~"escaped \"value:one\"")
  ProcedureReturn first + second
EndProcedure

Macro HiddenProcedure()
  Procedure MustNotAppear()
  EndProcedure
EndMacro

DeclareModule Sample
EndDeclareModule

Module Sample
  Procedure Visible(List values.i())
  EndProcedure
EndModule
