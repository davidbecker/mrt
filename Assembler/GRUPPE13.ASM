TITLE Loesung des Assembler-Praktikums MRT1 der Gruppe 13
;v2013-01-06, David Becker, Winnie T. SAHA SILATSA, Julia Wolff, Patrick Ziegler

;###############################################################################
;Aufgabe A 05
;Ein Punkt soll von oben links der Displayanzeige des Matrixdisplays nach oben
;rechts wandern, eine Position nach unten ruecken, dann wieder nach links laufen
;usw., bis alle 24 LED-Reihen abgearbeitet sind. Diese Prozedur soll sich
;solange wiederholen, bis das Programm durch eine Tastatureingabe beendet wird.
;Nach Druck der INT-Taste sollen alle nach der Betaetigung gesetzten Punkte
;leuchten bleiben, so dass solange eine Punktschlange entsteht. Nach Betaetigung
;der INT-Taste soll die Schlange verschwinden und der Punkt wieder einzeln
;wandern.
;###############################################################################

dosseg
.286
.model small
.stack 200h

include bit.bib
include light.bib
include display.bib
include abort.bib


.data
currentoffset	db	0		;aktuelles Offset(0/64/128)

basisoffset	db	64		;zum aufaddieren(Breite des Displays)
					;auf das currentoffset

customflag	db	110b		;Bit 0: Richtung(0->rechts)
					;Bit 1: Rand(1->auf dem Rand)
					;Bit 2: Modus (0:Punkt, 1:Schlange)

aktuellepos	db	0		;an welcher Position sind wir gerade
					;(0-191)

maske		db	1b		;Maske fuer LED (1->LED an)

badr		dw	0		;Hier steht spaeter die "Segment-
					;-adresse" der Displayabbildung

display		db	192 dup (66h)	;192 Byte fuer Inhalt des Displays als
					;Zwischenspeicher fuer uns (0-191)


.code
;###############################################################################
;Unterprogram "newpos" zur Berechnung neuer Adressen und Masken (Position)
;###############################################################################
newpos		proc
testrand:	push ax
		push bx

		xor ax, ax		;Register auf 0 setzen
		xor bx, bx

		mov bl, aktuellepos
		sub bl, currentoffset
		cmp bl, 0		;bl=0 => linker Rand
		je rand
		cmp bl, 63		;bl=63 => rechter Rand
		je rand
		jmp nichtrand

rand:		cmp bl, 0
		jne endrand		;springe bei rechtem rand
		;dieser Teil wird nur fuer den linken Rand gebraucht
		cmp maske, 10000000b	;sind wir an Position D7?
		jne endrand		;nicht an D7 => endrand

		mov al, currentoffset	;wir sind an D7 => das offset wird
		add al, basisoffset	;um Displayweite erhoeht
offsetcheck:	mov currentoffset, al	;currentoffset = aktuellepos
		mov aktuellepos, al
		cmp currentoffset, 192	;muessen wir wieder in die erste Zeile?
		jne endrand		;=> normale Randbetrachtung wenn nicht
					;ganz unten
		xor al, al		;wir springen wieder in 1. Zeile
		jmp offsetcheck		;currentoffset = aktuellepos = 0

endrand:	;dieser Teil wird immer fuer den Rand gebraucht
		biton customflag, 1
		mov customflag, al
		;Die Randmanipulation darf nur erfolgen wenn sie im letzten
		;Durchgang nicht erfolgt ist (sonst bleiben wir auf dem Rand)
		;linker Rand, Richtung rechts => keine Manipulation
		;rechter Rand, Richtung links => keine Manipulation
testlinks:	cmp bl, 0
		jne testrechts		;springe bei rechtem Rand
		flagstatus customflag, 0;Teste Richtung, Ausgabe in al
		cmp al, 0
		jne endrand2
		jmp nichtrand		;zum Verlassen des Randes
testrechts:	flagstatus customflag, 0;Teste Richtung, Ausgabe in al
		cmp al, 1
		jne endrand2
		jmp nichtrand		;zum Verlassen des Randes
endrand2:	bittoggle customflag, 0
		mov customflag, al	;Richtungsflag wird geaendert

		mov al, maske
		rol al, 1		;Maske wird nach links geschoben
					;(mit Uebertrag)
		mov maske, al

		jmp endtest

nichtrand:	bitoff customflag, 1
		mov customflag, al	;wendet bitoff auf speicher an
		;addressverschiebung
		flagstatus customflag, 0;lese Richtungsflag aus
		cmp al, 0
		je rechts
links:		dec aktuellepos
		jmp endtest
rechts:		inc aktuellepos

endtest:	pop bx
		pop ax
		ret
newpos		endp



;###############################################################################
;Das Hauptprogramm von dem aus alle Unterprogramme und Makros aufgerufen werden
;###############################################################################
hauptprogramm:	mov dx, @data
		mov ds, dx

		lea dx, display			;Segmentadresse der Display-
		mov badr, dx			;abbildung ermittlen

		mov al, 00001000b		;Initialisieren von
		mov dx, 37Ah			;Steuerport, /SLCT IN
		out dx, al			;gesetzt fuer Flanke

		writeall badr, 0FFh		;Display initialisieren,
		writeall badr, 0h		;und wieder zuruecksetzen

zyklus:		turnon badr, aktuellepos, maske
		turnoff badr, aktuellepos, maske, customflag
		call newpos
		abort badr, customflag
		jmp zyklus

end		hauptprogramm

