Option Explicit
'*********************************************************
' Purpose: Takes screenshots in a loop and generate execution report
' Input: N/A
' Output: Generated Word file report
'*********************************************************
Const WD_STORY = 6 
Const WD_MOVE = 0 
Const RED_COLOR = 255 
Const BLACK_COLOR = 0 
Const FILE_EXT = ".docx"
Const RESERVED_KEYWORD = "RED_"
Const TEMPLATE_RELATIVE_PATH = "\modelo\modelo.dotx"

Dim scriptPath : scriptPath = WScript.ScriptFullName
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim fileScript : Set fileScript = fso.GetFile(scriptPath)
Dim workingDirectory : workingDirectory = fso.GetParentFolderName(fileScript)
Set fileScript = Nothing 

Dim wordApp : Set wordApp = CreateObject("Word.Application")
wordApp.Visible = False

Dim numLockInitialState : numLockInitialState = wordApp.NumLock  	' store the initial state of NUM LOCK
Dim capsLockInitialState : capsLockInitialState = wordApp.CapsLock 	' store the initial state of CAPS LOCK
Dim workingDoc : Set workingDoc = wordApp.Documents.Open(workingDirectory & TEMPLATE_RELATIVE_PATH)

Dim testerName 
Dim scenario 
Dim comments 

testerName = HandleInputBox("Informe o nome do responsável pelo teste:", "Responsável pelo Teste", "")
If testerName = "" Then 
	With CreateObject ("WScript.Network") 
		testerName = .UserName 
	End With
End If
scenario = HandleInputBox("Informe o nome do cenário:", "Nome do Cenário", "Nome do Cenário não fornecido")
comments = HandleInputBox("Informe o texto de observação, caso houver", "Observação", "Nenhuma Observação")

With workingDoc.Tables(1)
	.Cell(1, 2).Range = scenario
	.Cell(2, 2).Range = testerName
	.Cell(3, 2).Range = GetExecutionTime
	.Cell(5, 2).Range = comments
End With

Dim objSelection : Set objSelection = wordApp.Selection
objSelection.EndKey WD_STORY, WD_MOVE

Dim wordBasic : Set wordBasic = CreateObject("Word.Basic")	' To take screenshot
Dim shouldContinue : shouldContinue = True
Do While shouldContinue
	
	Dim printDescription 
	printDescription = HandleInputBox("Informe um texto descritivo para o printscreen", "Texto do Printscreen", "")
	With objSelection 
		.Font.Name = "Arial"
		.Font.Size = "10"
		If InStr(1, printDescription, RESERVED_KEYWORD, 1) = 1 Then
			printDescription = Mid(printDescription, Len(RESERVED_KEYWORD) + 1)
			.Font.Color = RED_COLOR
		Else
			.Font.Color = BLACK_COLOR
		End If
		.TypeText printDescription
	End With
	
	objSelection.TypeParagraph()
	WScript.Sleep 4000
	
	wordBasic.SendKeys "{prtsc}"
	WScript.Sleep 1000
	objSelection.Paste

	' SendKeys messes with NUMLOCK and CAPSLOCK (VBS known bug). These lines set them back to their original state
	If wordApp.NumLock <> numLockInitialState Then wordBasic.SendKeys "{NUMLOCK}"
	If wordApp.CapsLock <> capsLockInitialState Then wordBasic.SendKeys "{CAPSLOCK}"

	If MsgBox("Deseja tirar outro Print da tela?", vbYesNo, "Printscreen") = vbNo Then shouldContinue = False
	
	objSelection.EndKey WD_STORY, WD_MOVE
	objSelection.TypeParagraph()
	
Loop
Set wordBasic = Nothing

Dim fileNameSuffix
Dim subFolder : subFolder = "\evidencias\"
If MsgBox("O teste está Aprovado?", vbYesNo, "Resultado do teste") = vbYes Then
	workingDoc.Tables(1).Cell(4, 2).Range = "[X] APROVADO [ ] REPROVADO"
	fileNameSuffix = "_PASSOU"
	subFolder = subFolder & "APROVADOS\"
Else
	workingDoc.Tables(1).Cell(4, 2).Range.Font.Color = RED_COLOR
	workingDoc.Tables(1).Cell(4, 2).Range = "[ ] APROVADO [X] REPROVADO"
	fileNameSuffix = "_FALHOU"
	subFolder = subFolder & "REPROVADOS\"
End If

Dim fileName
Do 
	fileName = HandleInputBox("Entre com o nome do arquivo de evidências", "Nome do Arquivo", "")
Loop While fileName = "" OR InStrRev(fileName, "\") = Len(fileName)

fileName = workingDirectory & subFolder & fileName & fileNameSuffix
BuildFolderPath Left (fileName, InStrRev(fileName, "\") -1)
fileName = RenameFile(fileName)

workingDoc.SaveAs fileName & FILE_EXT, 12	' 12 = wdFormatXMLDocument - XML Document format.
wordApp.Visible = True

' Cleaning
' Set fso = Nothing
' Set wordApp = Nothing
' set workingDoc = Nothing

'*********************************************************
' Purpose: Checks if file exist in the path provided. If True, renames 
'      the file according to count, following pattern: fileName (index)
' Input: fileName - the full file name (without extension)
' Output: newFileName - the new file name (without extension)
'*********************************************************
Function RenameFile (ByVal fileName)
	Dim index : index = 0
	Dim newFileName : newFileName = fileName
	Do While fso.FileExists(newFileName & FILE_EXT)
		index = index + 1
		newFileName = fileName & " (" & index & ")"
	Loop
	RenameFile = newFileName
End Function

'*********************************************************
' Purpose: Recursively generates entire folder structure
' Input: fullPath - the full path to be built (only folders, without file)
' Output: N/A
'*********************************************************
Sub BuildFolderPath(ByVal fullPath)
	If Not fso.FolderExists(fullPath) Then
		BuildFolderPath fso.GetParentFolderName(fullPath)
		fso.CreateFolder fullPath
	End If
End Sub

'*********************************************************
' Purpose: Returns the value of InputBox provided by the user. 
'      If user dismisses the InputBox, it will call ExitScript
' Input: dialogText - the text to be displayed in the InputBox
'      dialogTitle - the title of the InputBox
'      defaultValue - the default value to be used in the textbox
' Output: userInput - the value provided by the user
'      If user confirms cancellation of InputBox, it will call ExitScript
'*********************************************************
Function HandleInputBox(ByVal dialogText, ByVal dialogTitle, ByVal defaultValue)
	Dim prompt : prompt = "Todas as alterações serão perdidas e o documento não será salvo." & _
				 vbNewLine & "Tem certeza de que deseja cancelar?"
	Dim CancelExecution
	Do
		Dim userInput : userInput = InputBox(dialogText, dialogTitle, defaultValue)
		If IsEmpty(userInput) Then
			CancelExecution = MsgBox(prompt, vbYesNo, "Confirmação")
			If CancelExecution = vbNo OR IsEmpty(CancelExecution) Then 
				userInput = HandleInputBox(dialogText, dialogTitle, defaultValue)
			Else
				ExitScript
			End If
		End If
	Loop While CancelExecution = vbNo AND IsEmpty(userInput)
	HandleInputBox = userInput
End Function

'*********************************************************
' Purpose: Close all open documents, release variables and quit the script
' Input: N/A
' Output: N/A
'*********************************************************
Sub ExitScript()
	workingDoc.Saved = TRUE
	wordApp.Quit
	' Set wordBasic = Nothing
	' Set fso = Nothing
	' Set wordApp = Nothing
	' set workingDoc = Nothing
	WScript.Quit
End Sub

'*********************************************************
' Purpose: Return Current Time in following pattern: dd/mm/yyyy hh:mm:ss (24h format)
' Input: N/A
' Output: dd/mm/yyyy hh:mm:ss
'*********************************************************
Function GetExecutionTime()
	Dim timeStamp : timeStamp = Now
	GetExecutionTime = Right("0" & Day(timeStamp),2) & "/" & _
					   Right("0" & Month(timeStamp),2) & "/" & _
					   Year(timeStamp) & " " & _
					   Right("0" & Hour(timeStamp),2) & ":" & _
					   Right("0" & Minute(timeStamp),2) & ":" & _
					   Right("0" & Second(timeStamp),2)
End Function