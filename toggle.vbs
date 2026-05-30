Dim shell
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\20942\.claude\toggle-notifier.ps1""", 0, True
Set shell = Nothing
