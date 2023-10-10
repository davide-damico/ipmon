#NoTrayIcon
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3> 
#include <GUIConstantsEx.au3>
#include <GuiConstants.au3>
#include <StaticConstants.au3>
#include <Array.au3>
#include <FileConstants.au3>
#include <Date.au3>

; Imposta l'indirizzo IP da monitorare
$ipAddressesToMonitor = IniRead("ipmon.ini","General","IP","127.0.0.1")
Local $arrayAddressesToMonitor = StringSplit($ipAddressesToMonitor, ";")

; Trasformo l'Array in una matrice multidimensionale con 3 colonne, dove metterò lo stato attuale di ogni IP e se ha subito o meno un cambiamento di stato
Global $numRighe = UBound($arrayAddressesToMonitor) ; Ottieni il numero di elementi nell'array (righe della nuova matrice)
Global $numColonne = 3 ; Specifica il numero di colonne nella matrice multidimensionale

; Dichiaro la mia matrice, una tabellina contenente gli IP, il loro stato attuale ed un flag che indica se nell'ultimo check ha subito o meno un cambiamento.
Global $situazioneIP[$numRighe][$numColonne]

; Dichiaro la variabile che conterrà il report da mostrare a video con lo stato attuale degli IP 
Global $sReport = "";

; Riempio la matrice
For $i = 1 To $numRighe - 1
    $situazioneIP[$i][0] = $arrayAddressesToMonitor[$i] ; Nella prima colonna di ogni riga metto gli IP da monitorare
	$situazioneIP[$i][1] = "Null" ; Nella seconda andranno messi gli Stati
	$situazioneIP[$i][2] = False ; Nella terza annoto se c'è stato un cambiamento 
Next

; Imposta eventuale script esterno da eseguire nel caso il check rileva un cambio stato
$sExternalScript = IniRead("ipmon.ini","General","EXTERNALSCRIPT","")

; Imposta ogni quanto deve monitorare
$timeMonitor = IniRead("ipmon.ini","General","TIME","60000")

; Imposta ogni quanto deve monitorare
$pingTimeout = IniRead("ipmon.ini","General","PINGTIMEOUT","500")

; Imposto se voglio le notifiche oppure no
$sNotify =  IniRead("ipmon.ini","General","NOTIFY","S")

; Imposto se voglio il LOG oppure no
$sLog =  IniRead("ipmon.ini","General","LOG","S")

Opt("TrayMenuMode", 3) 

AdlibRegister("CheckIPStatus", $timeMonitor)

GestioneMenu()

Func GestioneMenu()
	
	Local $idDettagli = TrayCreateItem("Visualizza dettagli")
	TrayCreateItem("") 

	Local $idCSV = TrayCreateItem("Apri CSV")
	TrayCreateItem("") 

	Local $idAbout = TrayCreateItem("About")
	TrayCreateItem("") 

	Local $idExit = TrayCreateItem("Esci")

	TraySetState($TRAY_ICONSTATE_SHOW) 
	CheckIPStatus()

	While 1
		Switch TrayGetMsg()
		Case $idDettagli
			MsgBox ($MB_SYSTEMMODAL, "Dettagli IP Monitorati", "Di seguito l'elenco di tutti gli IP monitorati ed i loro stati attuali:" & @CRLF & $sReport)
		Case $idAbout 
			MsgBox($MB_SYSTEMMODAL, "About", "IPMon" & @CRLF & @CRLF & "Versione 3.1" & @CRLF & @CRLF & "Sviluppato da Davide D'Amico - www.novasoftonline.net" & @CRLF & @CRLF & "Con la collaborazione del gruppo Tecnici Informatici Italy") 
		Case $idCSV
			ShellExecute("registro.csv")
		Case $idExit 
			ExitLoop
		EndSwitch
	WEnd
	
EndFunc   

Func CheckIPStatus()
	
	$isChanged = False;
	
	FileDelete("temp.txt")
	
	For $i = 1 To UBound($situazioneIP, 1) - 1 
		
		$ipMonitorato = $situazioneIP[$i][0]
	
		; Controllo in che stato si trovava l'IP
		$ipStatoOld = $situazioneIP[$i][1] 

		; Controllo in che stato si trova ora l'IP
		$iResult = Ping($ipMonitorato, $pingTimeout)
		$iErrore = @error
		
		if $iResult == 0 Then
			Switch $iErrore
			Case 1
				$iMotivo = "Host OffLine"
			Case 2
				$iMotivo = "Host Irragiungibile"
			Case 3
				$iMotivo = "Destinazione errata"
			Case 4
				$iMotivo = "Errore Sconosciuto"
			EndSwitch
		Else
			$iMotivo = ""
		EndIf

		if $iResult > 0 Then
			$ipStatoNew = "OnLine"
		Else
			$ipStatoNew = "OffLine"
		EndIf
		
		; Controllo se la situazione è cambiata 
		If $ipStatoOld <> $ipStatoNew Then
			; Annoto il nuovo stato
			$situazioneIP[$i][1] = $ipStatoNew
			; Annoto che c'è stato un cambiamento
			$situazioneIP[$i][2]  = true
			$isChanged = True
			
			; Scrivo i cambiamenti in un file temporaneo, utile per un eventuale script esterno di notifica
			Local $hFileOpen = FileOpen("temp.txt", $FO_APPEND)
			FileWrite($hFileOpen, "Data: " & _NowCalc() &  " l'IP " & $ipMonitorato & " è cambiato in " &  $ipStatoNew & @CRLF)
			FileClose($hFileOpen)
			
			If $sLog = "S" Then 
			
				; Nel csv aggiungo l'evento di modifica stato
				; Prima testo se esiste, se non esiste lo inizializzo con le intestazioni di colonna
				If FileExists("registro.csv") Then
					Local $hFileOpen = FileOpen("registro.csv", $FO_APPEND)
					FileWrite($hFileOpen,  _NowCalc() & ";" & _NowTime() & ";" & $ipMonitorato & ";" & $ipStatoNew & ";" & $iMotivo & @CRLF)
					FileClose($hFileOpen)
				Else
					Local $hFileOpen = FileOpen("registro.csv", $FO_APPEND)
					FileWrite($hFileOpen, "Data;Ora;IP;Stato;Motivo" & @CRLF)
					FileWrite($hFileOpen,  _NowCalc() & ";" & _NowTime() & ";" & $ipMonitorato & ";" & $ipStatoNew & ";" & $iMotivo & @CRLF)
					FileClose($hFileOpen)
				EndIf
				
			EndIf
			
		EndIf
		
	Next

	; Se c'è stato qualche cambiamento lo notifico
	if $isChanged Then
		; Conto gli IP OnLine, e contestualmente mi creo una stringa che riporta il report dettagliato
		$nIPOnline = 0
		$nIPOffline = 0
		
		Global $sReport = "";
		
		For $i = 1 To UBound($situazioneIP, 1) - 1
			if $situazioneIP[$i][1] == "OnLine" Then
				$nIPOnline = $nIPOnline + 1;
				$sReport = $sReport & @CRLF & $situazioneIP[$i][0] & " : " & "OnLine"
			Else
				$nIPOffline =$nIPOffline + 1;
				$sReport = $sReport & @CRLF & $situazioneIP[$i][0] & " : " & "OffLine"
			EndIf
		Next
		
		If $sNotify = "S" Then 
			TrayTip("Situazione degli IP monitorati", "IP OnLine: " & $nIPOnline & " - IP OffLine: " & $nIPOffline, 3, $TIP_ICONASTERISK)
		EndIf
		
		TraySetToolTip("IP OnLine: " & $nIPOnline & " - IP OffLine: " & $nIPOffline)
		
		; Se gli IP Online sono uguali al numero totale degli IP totali imposto icona verde
		; Se gli IP Online sono 0 imposto icona rossa
		; Altrimenti imposto icona gialla
		
		$totIP = UBound($situazioneIP, 1) -1
		
		if $nIPOnline == $totIP Then
			TraySetIcon("led_green.ico")
		ElseIf $nIPOnline == 0 Then
			TraySetIcon("led_red.ico")
		Else
			TraySetIcon("led_yellow.ico")
		EndIf
		
		; Eseguo un eventuale .bat utile per esempio per mandare una email o una notifica sul telefono
		If FileExists ($sExternalScript) Then
			Run($sExternalScript, "", @SW_HIDE)
		EndIf
		
	EndIf

EndFunc

	



