; Parser boundary fixture.
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

Procedure.s QuotedColon(text.s = "a:b")
  ProcedureReturn text
EndProcedure

Procedure.s EscapedQuotedColon(text.s = ~"a\":b")
  ProcedureReturn text
EndProcedure

Procedure.s CommentColon(text.s = "keep") ; comment: this is not a statement
  ProcedureReturn text
EndProcedure

Procedure.i FirstColon(): ProcedureReturn 1 : EndProcedure : Procedure.i SecondColon(): ProcedureReturn 2 : EndProcedure
