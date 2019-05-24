

;========================================================
;       initial start
;========================================================


@ ERRORLEVEL -306   ; turn off crossing page boundary message

;****************************************************************
DEFINE	OSC 20		; 20 MHZ
;****************************************************************
DEFINE  DEBUG_REG   PORTB	'
DEFINE  DEBUG_BIT   3            
DEFINE  DEBUG_BAUD  57600	' Baudrate = 9600 bps <8N1>
DEFINE  DEBUG_MODE  0       ' Non-invert mode <drive through MAX232> 


;****************************************************************
DEFINE	LCD
;****************************************************************

DEFINE LCD_DREG PORTB     ' LCD data port 
DEFINE LCD_DBIT 4         ' LCD data starting bit 0 or 4 
DEFINE LCD_RSREG PORTC    ' LCD register select port 
DEFINE LCD_RSBIT 1        ' LCD register select bit 
DEFINE LCD_EREG PORTC     ' LCD enable port 
DEFINE LCD_EBIT 0         ' LCD enable bit 
DEFINE LCD_BITS 4         ' LCD bus size 4 or 8 
DEFINE LCD_LINES 2        ' Number lines on LCD 
DEFINE LCD_COMMANDUS 2000 ' Command delay time in us 
DEFINE LCD_DATAUS 50      ' Data delay time in us








;***********************************************************
;*	define pin
;***********************************************************
P_SI  		var	portb.5
P_SCLK  	var	portb.4
P_SO  		var	portb.3
P_GD0		var portb.2
P_CS  		var	portb.1  
TX_EN		var portb.0
;; RX_EN		var	portc.1


; ---- interrupt ---------------
define  INTHAND Int_prog
rx_loc	var	porta.2
txen_loc var porta.1
tx_loc	var	porta.0
led1	var	porta.3
rst		var	portc.4			; RST (ESP8266)

;****** DEFINED DEBUG PARAMETERS ********************************

TMR1IF	var	PIR1.0
TXIF	var	PIR1.4
TMR1ON	var	T1CON.0

TXEN	var	TXSTA.5
BRGH	var	TXSTA.2
SYNC	var	TXSTA.4

SPEN	var	RCSTA.7			; Serial Port Enable
CREN	var RCSTA.4			; enable USART1 receiver

BRG16	var	BAUDCTL.3		;
RCIE	var	PIE1.5			; enable receive interrupt
TXIE	var	PIE1.4			; disable USART1 transmit interrupt
RCIF	var	PIR1.5			; receive flag

;-----------------------------------------------------------------------
GIE		var	INTCON.7		; GIE=1			disable all unmasked interrupts
PEIE	var	INTCON.6		; PEIE=1		disable all unmasked peripheral interrupts
INTE	var	INTCON.4		; INTE=0
RBIE	var	INTCON.3		; RBIE=1		enable port b interrupt
RBIF	var	INTCON.0		; RBIF



;----- ram buffer --------
commBuf		var byte[32] $a0
intBuffer	var byte[16] $c0	

grp			var	intBuffer[1]
cmd			var	intBuffer[2]
scr_val		var	intBuffer[3]
val			var	intBuffer[4]

txB 		var byte[60] $120
rxB			var	byte[60] $190



;--------------------------------------------------------------------------------------------------
;          		ra0  ra1  ra2  ra3    ra4  ra5   ra6   ra7  ra8  ra9  raa  rab  rac  rad  rae   raf
;      sync		wid	 wid  dir  CCmd   Org  spare node  sid1 sid2 did1 did2 cmd1 cmd2 lg1  lg2   crc  end
;--------------------------------------------------------------------------------------------------
temp	var	byte $70
temp1	var	byte $71
temp2	var	byte $72
temp3	var	byte $73
temp4	var	byte $74
temp5	var	byte $75
temp6	var	byte $76
temp7	var	byte $77

;---- General Variable ------
x 		var byte
y		var	byte
w		var	byte
p		var	byte

i		var	byte
j		var	byte
k		var	byte
l		var	byte
m		var	byte
kcnt	var	byte
secCnt	var WORD

ix		var	word



d		var	byte
d1		var	byte
d2		var	byte
d3		var	byte


;-----------------------------------------
DatRcv_Fg	var	byte
DataRdy		var	DatRcv_fg.7

charCnt var	byte $78
dlyCnt	var	byte $79
Dat		var	byte $7a

wsave  	var byte $7d system
ssave  	var byte $7e system
psave  	var byte $7f system
Rpt		var	byte



;================================================
INI_0:
	gosub init_IO
	gosub init_PWM
	gosub init_EUSART
	OPTION_REG = %1001111		; /RAPU INTEDG T0CS T0SE PSA PS2 PS1 PS0		; for wdt,  int rising
								;  1     0      0    0   1   1   1   1			;page 123
	high rst					; RST (ESP8266)
	gosub OnTm1					;start timer
	secCnt = 100

	high PIE1.5				;ENABLE RCIE
	INTCON=%11000000		;ENABLE GIE,PEIE			;     1 1 0 0 0 0 0 0                       
	
	secCnt=100
	CCPR1L= 128
	CCPR1H=0
	goto start
	
	
	
;===============================================================
;===============================================================
		asm
Int_prog:
w		equ	0
same	equ 1

; Insert interrupt code here
; Save and restore FSR and any other registers used
		bcf		STATUS,IRP		; bank 0
		bsf		PORTC,3			; START 
;	----- set start loc and max 80 char ------------
t0_ref:	movlw   0xc0
		movwf   FSR				; set FSR=0xa0

		clrwdt
		clrf	_charCnt		; clr no. char	_temp2 =_charCnt
		clrf	_DatRcv_Fg
;	------  set timer -----------------------------
t1_ref:	clrwdt					;			<-------------------------------		
		movlw   .10				; max delay count							|
		movwf   _dlyCnt			; dlyCnt									|
;	------ check data ready ----------------------							|
tm_lp:	btfsc   PIR1,5			; RCIF		<-----------------------		|
		goto    t2_ref			; yes data							|		|
;	---------- check timeout ----------------------------			|		|
		movlw	.250			;									|		|
		movwf	_temp7			;									|		|
		decfsz	_temp7,same		; <---|								|		|
		goto	$-1				; ----|								|		|
								;									|		|
		decfsz  _dlyCnt,same	; no data skip if zero  			|		|
		goto    tm_lp			; if not done then loop	------------		|
		goto    st_LocEx		; timeout exit								|
;	---------- get char ----------------------------------					|
t2_ref:	movfw   RCREG			; get data to (W)							|
		movwf	_Dat			; save at temp6								|
;	-----------------------------------------------------					|
;		write char to buffer 												|
;	-----------------------------------------------------					|
		movfw	_Dat			;											|
		movwf   INDF			; store at index pointer					|
		incf    _charCnt,same	; char counts 								|
		incf    FSR,same		; inc pointer (txBuffer+1)					|
		goto    t1_ref			; loop if not done reset timeout------------

st_LocEx:        
;	---------check numchar count ------------------------
		movf	_charCnt,same		
		bz		Int_ex
		bsf		_DatRcv_Fg,7		; set DAV on
		bcf		PORTC,3				; END 
Int_ex:
; Restore saved registers
		movf    psave, W
		movwf   PCLATH				;restore PCLATH
		swapf   ssave, W
		movwf   STATUS				;restore STATUS
		swapf   wsave, F			
		swapf   wsave, W
		retfie

		endasm


start:
	;	low txen_loc :high tx_loc 	; RS485

	;	high rst					; rst (ESP8266)
	;	low tx_en					; cc1100
		
		
		Lcdout $fe, 1 ' Clear LCD screen
		Lcdout "Hello" ' Display Hello

		Lcdout $fe, $c0 ' Clear LCD screen
		Lcdout "PWM == ", #CCPR1L  
	
		debug "Not found Loop!!",13,10 
	
		if (porta.0 == 0) then
			CCPR1L= 255
			hserout [255]
	
		endif

		if (porta.1 == 0) then
			CCPR1L= 1
			hserout [1]
		
		endif

		if (porta.2 == 0) then
			CCPR1L= 128
			hserout [128]
		
		endif

		
		

		gosub cktmOut 
		if (Rpt>0) then					;  timeout
			debug "LOOP 1 ",13,10
			gosub OnTm1 
			if secCnt>0 then secCnt=secCnt-1
				
			if (secCnt==0) then
				secCnt=100 
				
				 toggle porta.3				; toggle every 1 sec
			endif
		endif



		If DataRdy == 1 Then				; RCIF  If receive flag then...
			low DataRdy
			
		
			low CREN :high CREN		;reset error
			if charCnt>0 then
				for j = 0 to charCnt-1
					d=intBuffer[j]

					CCPR1L= d
					;debug hex2 d," "
					hserout [d]
				next j
				;debug 13,10
			;	hserout [13,10]
			endif



		endif

		goto start

;***********************************************
;subroutine
;***********************************************:
cktmOut:
	Rpt=0 :if (TMR1IF) then Rpt=1
	debug 13,10,"found TMR1IF", TMR1IF, 13,10   	
	return
	
;******************************************************************
;*	Init PWM Function
;******************************************************************
init_PWM:

						;			7    6      5       4       3       2      1       0
						;CCP1CON	P1M1 P1M0   DC1B1   DC1B0   CCP1M3  CCP1M2 CCP1M1  CCP1M0
	CCP1CON=%00001100	;            0     0    d       d       1       1      0       0			;SET MODE PWM
	CCPR1L=$00			;high 8 bits

;						;T2CON      -   TOUTPS3 TOUTPS2 TOUTPS1 TOUTPS0 TMR2ON T2CKPS1 T2CKPS0
;						;            0     0    0       0       0       1      1       1
	T2CON=$07
	PR2=$ff

	return

;******************************************************************
;*	Init I/O Function
;******************************************************************
init_IO:
;	OSCCON=	%01110001			; — IRCF2 IRCF1 IRCF0 OSTS(1) HTS LTS SCS
;								; 0  1     1     1    0		  0   0     1
;	-------PORT A------------
	ANSEL  = %00000000			; for port a (digital I/O)
	TRISA  = %00100111   		; port a

;	-------PORT B------------
	TRISB  = %00000000   		; port b
	ANSELH = %00000000			; Need to be initialize for port b

;------------------ interrupt disable -----------------------------------
	TRISC  = %10000000   		; port b
	TRISC.7 =1					;receive pin
  	TRISC.6 =0	 				;transmit pin
	debug 13,10,"init IO",13,10

	return
;******************************************************************
;*	Init USART Function
;******************************************************************
init_EUSART:

	RCSTA = $90   ' Enable serial port & continuous receive
	TXSTA = $24   ' Enable transmit, BRGH = 1
	SPBRG = 8     ' 9600 Baud @ 20MHz, -0.03%
	SPBRGH = 2
	BAUDCTL.3 = 1 ' Enable 16 bit baudrate generator


	debug 13,10,"EUSART Initialized",13,10
	return


OnTm1:				; 20 mhz
       

	T1CON=%00100101			;
	TMR1H=$f6 :TMR1L=$40	; 1ms *** [preload=63040]	use Timer Helper select fosc=20 mhz, reload instr=8,interrupt = 1ms,prescale 1:2
;	----- timer1,clr flag set timer1 on -----------
	low TMR1IF				; clr flag
	high TMR1ON				; timer1 on
	return




;====================================================
;@        __config _CONFIG1, 2B9AH	

@        __config _CONFIG1, 239AH	
@        __config _CONFIG2, 3EFFH

;////////////////////////////////////////////////////////////////////////////
;=====================================================
	END                     ' End of program
;=====================================================
