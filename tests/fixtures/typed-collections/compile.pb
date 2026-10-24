; Independently compile complete typed collection declarations.
Structure Entry
  value.i
EndStructure
DeclareModule Model
  Structure Entry
    value.i
  EndStructure
EndDeclareModule
Module Model
EndModule
IncludeFile "expected.pbi"
IncludeFile "source.pb"
OpenConsole()
NewMap records.Entry()
NewList items.Entry()
Dim entries.Entry(0)
NewMap qualified.Model::Entry()
records("value")\value = 17
AddElement(items()) : items()\value = 23
entries(0)\value = 31
qualified("value")\value = 37
If ReadMap(records()) <> 17 Or ReadList(items()) <> 23 Or ReadArray(entries()) <> 31 Or ReadQualified(qualified(), 4) <> 41
  End 1
EndIf
PrintN("Typed map/list/array declarations compile and execute.")
End 0
