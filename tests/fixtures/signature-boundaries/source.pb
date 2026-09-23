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
