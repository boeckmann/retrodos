; RetroDOS/86
; DUMP - OUTPUT FILE TO CONSOLE IN HEXADECIMAL AND ASCII

		ORG     100H

;---------------------------------------------------------------------
; CONSTANTS

; Interrupts
DOS:            EQU     21H
TERMINATE:      EQU     20H

; DOS functions
CHROUTF:        EQU     02H
CHRINF:         EQU     08H
STROUTF:        EQU     09H
OPENF:          EQU     0FH
CLOSEF:         EQU     10H
SETDTAF:        EQU     1AH
SETINTF:        EQU     25H
RNDREADF:       EQU     27H
PARSEFNF:       EQU     29H

; PSP
INT23SAV:       EQU     0EH
CMDLEN:         EQU     80H
CMDLINE:        EQU     81H
FCB:            EQU     5CH
FILENAME:       EQU     FCB+1
FILESIZE:       EQU     FCB+10H
RNDRECOFF:      EQU     21H

; common constants
CR:             EQU     0DH
LF:             EQU     0AH
SCRLINES:       EQU     25


;---------------------------------------------------------------------
; MAIN ROUTINE

MAIN:
		MOV     SP,STACKEND
		MOV     AH,SETINTF
		MOV     AL,23H
		MOV     DX,INT23
		INT     DOS
		CALL    PARSECMD
		JC      USAGE
		CALL    OPENFILE
		JC      OPENERR
		CALL    CALCRNG
		JC      RNGERR
		CALL    CALCBLKS
;                CALL    DISPRNG 
		CALL    DISPFILE
		CALL    CLOSEFILE
EXIT:           INT     TERMINATE

USAGE:          MOV     DX,USAGEMSG
		MOV     AH,STROUTF
		INT     DOS
		INT     TERMINATE

OPENERR:
		MOV     DX,OPENERRMSG
		MOV     AH,STROUTF
		INT     DOS
		INT     TERMINATE

RNGERR:
		MOV     DX,RNGERRMSG
		MOV     AH,STROUTF
		INT     DOS
		INT     TERMINATE

INT23:
		CMP     B,[FILEOPEN],0
		JE      INT23A
		CALL    CLOSEFILE
  INT23A:       JMP     L,[INT23SAV]


;---------------------------------------------------------------------
; SUBROUTINES

DISPFILE:
		MOV     DX,FILEBUF
		MOV     AH,SETDTAF
		INT     DOS
		MOV     AX,[STARTBLK]
		MOV     [FCB+RNDRECOFF],AX
		MOV     AL,[STARTBLK+2]
		MOV     [FCB+RNDRECOFF+2],AL
		MOV     AX,[DISPSTART]
		AND     AX,0FFF0H
		MOV     [CURRPARA],AX
		MOV     AX,[DISPSTART+2]
		MOV     [CURRPARA+2],AX
		CALL    FILLBUF
		MOV     AX,[DISPSTART]
		AND     AX,70H  ; add start offset into block
		ADD     SI,AX
		XOR     CX,CX
  DISPFILE1: 
		CMP     SI,FILLBUF+8192
		JB      DISPFILE2
		CALL    FILLBUF
		JNC     DISPFILE2
		MOV     DX,READERRMSG
		MOV     AH,STROUTF
		INT     DOS
		RET
  DISPFILE2: 
		CALL    DISPPARA
		INC     CX
		CMP     CX,SCRLINES-2
		JBE     DISPFILE3
		CALL    WAITKEY
		XOR     CX,CX
  DISPFILE3:
		MOV     AX,[CURRPARA]
		MOV     DX,[CURRPARA+2]
		ADD     AX,16
		ADC     DX,0
		MOV     [CURRPARA],AX
		MOV     [CURRPARA+2],DX
		CMP     DX,[DISPEND+2]
		JB      DISPFILE1
		CMP     AX,[DISPEND]
		JBE     DISPFILE1
		RET

DISPPARA:
		PUSH    AX
		PUSH    BX
		PUSH    DX
		PUSH    CX
		PUSH    SI
		MOV     AX,[CURRPARA+2]
		CALL    PRINTWHEX
		MOV     AX,[CURRPARA]
		CALL    PRINTWHEX
		MOV     CX,16
		CALL    PRINTSPC
  DISPPARA1:
		CALL    PRINTSPC
		MOV     DX,[CURRPARA+2]
		MOV     AX,16
		SUB     AX,CX
		ADD     AX,[CURRPARA]
		MOV     BX,DISPSTART
		CALL    CMPDB
		JB      DISPPARA4 
		MOV     BX,DISPEND
		CALL    CMPDA
		JA      DISPPARA4
		LODB
		CALL    PRINTBHEX
		LOOP    DISPPARA1
		JMP     DISPPARA5
  DISPPARA4:
		CALL    PRINTSPC
		CALL    PRINTSPC
		INC     SI
		LOOP    DISPPARA1
  DISPPARA5: 
		CALL    PRINTSPC
		CALL    PRINTSPC
		MOV     CX,16
		POP     SI
  DISPPARA2:
		MOV     DX,[CURRPARA+2]
		MOV     AX,16
		SUB     AX,CX
		ADD     AX,[CURRPARA]
		MOV     BX,DISPSTART
		CALL    CMPDB
		JB      DISPPARA6 
		MOV     BX,DISPEND
		CALL    CMPDA
		JA      DISPPARA6
		LODB
		CMP     AL,' '
		JAE     DISPPARA3
		MOV     AL,'.'
		JMP     DISPPARA3
  DISPPARA6:
		MOV     AL,' '
  DISPPARA3:
		MOV     AH,CHROUTF
		MOV     DL,AL
		INT     DOS
		LOOP    DISPPARA2
		CALL    NEWLINE
		POP     CX
		POP     DX
		POP     BX
		POP     AX
		RET

FILLBUF:
		PUSH    DX
		PUSH    CX
		MOV     AH,RNDREADF
		MOV     CX,64   ; FILEBUF/128 blocks
		MOV     DX,FCB
		INT     DOS
		MOV     SI,FILEBUF
		POP     CX
		POP     DX
		CMP     AL,2
		JE      FILLBUFF
		CLC
		RET
  FILLBUFF:     STC
		RET

PARSECMD:       CMP     B,[CMDLEN],0
		JE      PARSEERR 
		MOV     SI,CMDLINE
		MOV     DI,FCB
		MOV     AH,PARSEFNF
		MOV     AL,1
		INT     DOS
		TEST    AL,AL
		JNE     PARSEERR
		CMP     [FILENAME],' '
		JE      PARSEERR 
		CALL    SKIPSPC
		CMP     B,[SI],CR
		JE      PARSERET
		CMP     B,[SI],','
		JE      PARSEEND
  PARSECMD3:    CMP     B,[SI],'-'
		JNE     PARSECMD1
		INC     SI
		MOV     B,[DISPSTARTEOF],1
  PARSECMD1:    CALL    PARSEDNUM
		JC      PARSEERR
		MOV     W,[DISPSTART+2],DX
		MOV     W,[DISPSTART],AX
		CMP     B,[SI],','
		JE      PARSEEND
		CMP     B,[SI],CR
		JNE     PARSEERR
		CLC
		RET
  PARSEEND:     INC     SI
		CMP     B,[SI],'-'
		JNE     PARSECMD2
		INC     SI
		MOV     B,[DISPENDEOF],1
  PARSECMD2:    CALL    PARSEDNUM
		JC      PARSEERR
		MOV     W,[DISPEND+2],DX
		MOV     W,[DISPEND],AX
  PARSERET:     CLC 
		RET
  PARSEERR:     STC
		RET 

OPENFILE:
		MOV     AH,OPENF
		MOV     DX,FCB
		INT     DOS
		TEST    AL,AL
		JNZ     OPENFILEE
		CLC
		MOV     B,[FILEOPEN],1
		RET
  OPENFILEE:
		STC 
		RET

CLOSEFILE:
		MOV     AH,CLOSEF
		MOV     DX,FCB
		INT     DOS
		MOV     B,[FILEOPEN],0
		RET

CALCRNG:
		CMP     W,[DISPEND],0FFFFH
		JNE     CALCRNG3
		CMP     W,[DISPEND+2],0FFFFH
		JNE     CALCRNG3
	      ; set display end to eof if not given
		MOV     AX,[FILESIZE]
		SUB     AX,1
		MOV     [DISPEND],AX
		MOV     AX,[FILESIZE+2]
		SBC     AX,0
		MOV     [DISPEND+2],AX
	      ; calculate display start relative to eof 
  CALCRNG3:     MOV     AL,[DISPSTARTEOF]
		TEST    AL,AL
		JZ      CALCRNG1
		MOV     AX,[FILESIZE]
		SUB     AX,[DISPSTART]
		MOV     [DISPSTART],AX
		MOV     AX,[FILESIZE+2]
		SBC     AX,[DISPSTART+2]
		MOV     [DISPSTART+2],AX
		JC      RET
	      ; calculate display end relative to eof 
  CALCRNG1:     MOV     AL,[DISPENDEOF]
		TEST    AL,AL
		JZ      CALCRNG2
		MOV     AX,[FILESIZE]
		SUB     AX,[DISPEND]
		MOV     [DISPEND],AX
		MOV     AX,[FILESIZE+2]
		SBC     AX,[DISPEND+2]
		MOV     [DISPEND+2],AX
		JC      RET
	      ; check for display range out of bounds
  CALCRNG2:     MOV     AX,[FILESIZE]
		CMP     [DISPSTART],AX
		JAE     ERRCALCRNG
		CMP     [DISPEND],AX
		JAE     ERRCALCRNG
		MOV     AX,[DISPSTART]
		CMP     AX,[DISPEND]
		JA      ERRCALCRNG
		CLC
		RET
  ERRCALCRNG:   STC
		RET

CALCBLKS:
	      ; calculate start and end block
		MOV     DX,[DISPSTART+2]
		MOV     AX,[DISPSTART]
		MOV     CL,7
  CALCBLKS1:    SHR     DX
		RCR     AX
		LOOP    CALCBLKS1
		MOV     [STARTBLK+2],DX
		MOV     [STARTBLK],AX
		MOV     DX,[DISPEND+2]
		MOV     AX,[DISPEND]
		MOV     CL,7
  CALCBLKS2:    SHR     DX
		RCR     AX
		LOOP    CALCBLKS2
		MOV     [ENDBLK+2],DX
		MOV     [ENDBLK],AX
		RET 

DISPRNG:
		MOV     AX,[DISPSTART+2]
		CALL    PRINTWHEX
		MOV     AX,[DISPSTART]
		CALL    PRINTWHEX
		MOV     AH,CHROUTF
		MOV     DL,','
		INT     DOS
		MOV     AX,[DISPEND+2]
		CALL    PRINTWHEX
		MOV     AX,[DISPEND]
		CALL    PRINTWHEX
		MOV     AH,CHROUTF
		MOV     DL,','
		INT     DOS
		MOV     AX,[STARTBLK+2]
		CALL    PRINTWHEX
		MOV     AX,[STARTBLK]
		CALL    PRINTWHEX
		MOV     AH,CHROUTF
		MOV     DL,','
		INT     DOS
		MOV     AX,[ENDBLK+2]
		CALL    PRINTWHEX
		MOV     AX,[ENDBLK]
		CALL    PRINTWHEX
		MOV     AH,CHROUTF
		MOV     DL,','
		INT     DOS
		MOV     AX,[FCB+12H]
		CALL    PRINTWHEX
		MOV     AX,[FCB+10H]
		CALL    PRINTWHEX
		CALL    NEWLINE
		RET

;---------------------------------------------------------------------
; UTILITY ROUTINES

CMPDA:
		CMP     DX,[BX+2]
		JA      RET
		CMP     AX,[BX]
		RET

CMPDB:
		CMP     DX,[BX+2]
		JB      RET
		CMP     AX,[BX]
		RET

PARSEDNUM: 
		CMP     B,[SI],'#'
		JNE     PARSEDNUML1
		INC     SI
		CALL    PARSEDDEC
		RET
  PARSEDNUML1:  CALL    PARSEDHEX
		RET

PARSEDDEC:
		PUSH    BX
		PUSH    CX
		PUSH    DI 
		XOR     AX,AX
		XOR     BX,BX
		XOR     DI,DI
		MOV     CX,10
		LODB
		SUB     AL,'0'
		CMP     AL,10
		JAE     ERRPARSEDDEC
  PARSEDDEC1:   XCHG    AX,BX
		LODB
		SUB     AL,'0'
		CMP     AL,10
		XCHG    AX,BX
		JAE     RETPARSEDDEC
		XCHG    AX,DI
		MUL     AX,CX
		JC      RETPARSEDDEC
		XCHG    AX,DI
		MUL     AX,CX
		ADD     DI,DX
		ADD     AX,BX
		ADC     DI,0
		JC      RETPARSEDDEC
		JMP     PARSEDDEC1
  ERRPARSEDDEC: STC
  RETPARSEDDEC: XCHG    DI,DX
		DEC     SI
		POP     DI 
		POP     CX
		POP     BX
		RET

PARSEDHEX:
		PUSH    BX
		XOR     AX,AX
		XOR     BX,BX
		XOR     DX,DX 
		LODB
		SUB     AL,'0'
		CMP     AL,10
		JB      PRSDHEXL
  PRSDHEX1:     SUB     AL,'A'-'0'
		AND     AL,0DFH         ; convert lower case to upper case
		CMP     AL,7
		JAE     ERRPARSEDHEX
		ADD     AL,10 
  PRSDHEXL:     XCHG    AX,BX
		LODB
		SUB     AL,'0'
		CMP     AL,10
		JB      PRSDHEX2
		SUB     AL,'A'-'0'
		AND     AL,0DFH 
		CMP     AL,7
		JAE     RETPARSEDHEX
		ADD     AL,10
  PRSDHEX2:     XCHG    AX,BX
		SHL     AX
		RCL     DX 
		JC      RETPARSEDHEX
		SHL     AX
		RCL     DX 
		JC      RETPARSEDHEX
		SHL     AX
		RCL     DX 
		JC      RETPARSEDHEX
		SHL     AX
		RCL     DX 
		JC      RETPARSEDHEX
		ADD     AX,BX
		JC      RETPARSEDHEX
		JMP     PRSDHEXL 
  ERRPARSEDHEX: STC
  RETPARSEDHEX: XCHG    AX,BX
		DEC     SI
		POP     BX
		RET

PRINTBHEX:
		PUSH    DX
		MOV     AH,CHROUTF
		MOV     DH,AL
		SHR     AL
		SHR     AL
		SHR     AL
		SHR     AL
		AND     AL,0FH
		ADD     AL,'0'
		CMP     AL,'9'
		JBE     PRINTBHEX1
		ADD     AL,'A'-'9'-1
  PRINTBHEX1:   MOV     DL,AL
		INT     DOS
		MOV     DL,DH
		AND     DL,0FH
		ADD     DL,'0'
		CMP     DL,'9'
		JBE     PRINTBHEX2
		ADD     DL,'A'-'9'-1
  PRINTBHEX2:   INT     DOS 
		POP     DX
		RET

PRINTWHEX:
		PUSH    BX
		PUSH    DX
		PUSH    CX
		MOV     BH,CHROUTF 
		MOV     CX,4
  PRINTWHEX2:   ROL     AX
		ROL     AX
		ROL     AX
		ROL     AX
		MOV     DL,AL
		AND     DL,0FH
		ADD     DL,'0'
		CMP     DL,'9'
		JBE     PRINTWHEX1
		ADD     DL,'A'-'9'-1 
  PRINTWHEX1:   XCHG    AX,BX
		INT     DOS
		XCHG    AX,BX
		LOOP    PRINTWHEX2
		POP     CX
		POP     DX
		POP     BX
		RET

SKIPSPC:
		CMP     B,[SI],' '
		JNE     RET
		INC     SI
		JMP     SKIPSPC
		RET

PRINTSPC:
		MOV     AH,CHROUTF
		MOV     DL,' '
		INT     DOS
		RET

NEWLINE:
		MOV     AH,CHROUTF
		MOV     DL,CR
		INT     DOS
		MOV     DL,LF
		INT     DOS
		RET

WAITKEY:
		PUSH    AX
		PUSH    DX
		PUSH    CX
		MOV     AH,STROUTF
		MOV     DX,WAITMSG
		INT     DOS
		MOV     AH,CHRINF
		INT     DOS
		TEST    AL,AL
		JNZ     WAITKEY1
		INT     DOS
  WAITKEY1:     CALL    NEWLINE
		POP     CX
		POP     DX
		POP     AX
		RET

;---------------------------------------------------------------------
; DATA

DISPSTART:      DW      0,0
DISPEND:        DW      0FFFFH,0FFFFH
DISPSTARTEOF:   DB      0
DISPENDEOF:     DB      0
FILEOPEN:       DB      0

USAGEMSG: 
		DB      'DUMP - display file in hexadecimal and ascii'
		DB      CR,LF,CR,LF
		DB      '       Invocation: DUMP.COM file'
		DB      ' [[-][#]start][,[-][#]end]'
		DB      CR,LF,CR,LF
		DB      '       Negative numbers are relative to the'
		DB      ' end of file.',CR,LF
		DB      '       Numbers prefixed by # are in decimal.',CR,LF
		DB      '       Numbers without prefix are in hexadecimal.'
		DB      CR,LF,'$' 

OPENERRMSG:     DB      "Error: can't open file$"
READERRMSG:     DB      "Error: can't read from file$"
RNGERRMSG:      DB      "Error: range out of bounds$"
WAITMSG:        DB      "Strike a key to continue...$"

;---------------------------------------------------------------------
; UNINITIALIZED DATA

STACK:          DS      256
STACKEND:

;CURRBLK:       DS      4
STARTBLK:       DS      4
ENDBLK:         DS      4
CURRPARA        DS      4

FILEBUF:        DS      8192
