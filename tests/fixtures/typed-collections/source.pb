; Complete collection element types are part of procedure signatures.
Procedure.i ReadMap(Map records.Entry())
  ProcedureReturn records("value")\value
EndProcedure
Procedure.i ReadList(List records.Entry())
  FirstElement(records())
  ProcedureReturn records()\value
EndProcedure
Procedure.i ReadArray(Array records.Entry(1))
  ProcedureReturn records(0)\value
EndProcedure
Procedure.i ReadQualified(Map records.Model::Entry(), fallback.i = 0)
  ProcedureReturn records("value")\value + fallback
EndProcedure
