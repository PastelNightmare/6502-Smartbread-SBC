; Device Monitor 2025 Dev Build
; Starting to refactor and fix jank
; Add conditional blocks to save space. If you're only using a serial port, you can disable LCD and Tellymate Tiny specifc code


LCDCONNECTED = 0 					; Set to 1 to tell assembler you're using LCD 
TMCONNECTED = 0 					; Set to 1 to tell assembler you're using tellymate tiny 

;Setting registers

VIAORA = $6001 						; VIA 1 output register A
VIADDRA = $6003 					; VIA 1 Port A data direction register 
VIAORB = $6000 						; VIA 1 output register B
VIADDRB = $6002 					; VIA 1 Port B data direction register

VI2ORA = $5001 						; Same order but starts with VIA 2 now.
VI2DDRA = $5003 				
VI2ORB = $5000  				
VI2DDRB = $5002 
VI2PCR = $500C 						; VIA 2 peripheral control register

ACIA_DATA = $4400					; ACIA registers. Named accordingly.
ACIA_STATUS = $4401
ACIA_COMMAND = $4402
ACIA_CONTROL = $4403

DROPCOUNT = $0050
 
 *=$0020 ; Zero page variables 
 
OUTPUT:  .DS $4 					; Buffer for converted Hex to Ascii. 
RESULT:  .DS $8						; Address of requested read location lives here. 
RESULT2: .DS $8 					; For list commands, the end of the address range we're searching for. 
WRITEV:  .DS $2 					; Data value converted FROM Ascii to Hex. Used for write commands.  
          
  *=$0800 						; Command-line input buffer
 
BUFFER: .RS $50

; ROM starts here. 
 
 *=$8000 

 
; Sets up and initializes all ICs / Peripherals. 

INITST: 
	
	LDX #$FF					
        TXS 						; Stack initialized
							; UART Initialized
UINIT:   
	 LDA #@00001011					; No parity, no echo, no interrupt
         STA ACIA_COMMAND
         LDA #@00011111					; 19200 8N1 connection
         STA ACIA_CONTROL
            


INITDDR: 
         LDA #$FF
         STA VIADDRA 					; VIA 1 Data Direction Register (DDR) A, all output. Character LCD data line / GPIO. Can rewrite as needed via DeMon	
         STA VI2DDRB 					; Via 1 DDR B all output. Sound chip data lines. 
         LDA #$00
         STA VI2DDRA 					; Via 2 DDRA all input. ASCII data from keyboard chip. 
         LDA #@11110111
         STA VIADDRB  					; Control signals, all output for LCD, sound chip. One input for keyboard handshaking. 
   
   .IF LCDCONNECTED       
	FLASHC: 						; LCD Initialization
        
 	        LDA #@00000110					; LCD Command Register, leaving enable line high. 
        	STA VIAORB 
         	LDA #$0F 
         	STA VIAORA 					; Turns on character LCD with blinking cursor
         	LDA #@00000100
         	STA VIAORB 
         	JSR DELAY					; Strobes enable line to tell LCD to process data, and delays to allow LCD to process command. 
	
	TWOLINE: 

         	LDA #@00000110 
         	STA VIAORB
         	LDA #@00111100
         	STA VIAORA 					; LCD using 8 data bits, 5x10 font, 2 lines. 
         	LDA #@00000100 
         	STA VIAORB
         	JSR DELAY					; Enable line strobe
         
	CLEAR: 
        	LDA #@00000110 
         	STA VIAORB
         	LDA #$01 					; Clear LCD
         	STA VIAORA
         	LDA #@00000100 
         	STA VIAORB
         	JSR DELAY					; Enable line strobe
         	LDA #@00000111
         	STA VIAORB					; Set VIA output register B to what it will need for the rest of monitor when not being used
 	.endif

						; Tellymate tiny (composite display terminal connected to ACIA) needs two dummy bits to initiate autobaud per manufacturer's spec. 
							; ASCII U (01010101) is recommended. Also sends commands to turn on autowrap, and clear the screen before printing splash message.
							; Per WDC instructions, new ACIA chips have a bug which breaks the TXE flag. You cannot check that to ensure data register is empty. 
							; Manufacturer recommends a delay after each bit data sent to it to ensure data register is ready for more data. So every serial 
    .if TMCONNECTED 					; related operation will have a delay as a result. First here, and then in the ECHO subroutine.   
               
	TELLYMATEINIT:
        	LDA #@01010101 
        	STA ACIA_DATA 
        	JSR DELAY					
        	STA ACIA_DATA 
        	JSR DELAY 					; Stores U on the ACIA data register twice
        	LDA #$1B 
        	STA ACIA_DATA
        	JSR DELAY
        	LDA #$76 					; Tellymate tiny commands are initiaed with ESC in ASCII and then another ASCII character to do a command. 76, autowrap on. 
        	STA ACIA_DATA
        	JSR DELAY
        	LDA #$1B
        	STA ACIA_DATA
        	JSR DELAY 
        	LDA #$45 					; 45. Clear screen
        	STA ACIA_DATA
        	JSR DELAY
  .endif  
       
                                   
MSGST: ; Mostly initalized. Let's make a splash message! 
     
        LDY #$00 					; Y register used as index for TEXT
GET:    LDA TEXT,Y 					; Loads character of text, indexed by Y. 
        BEQ SILENCE 					; End if we've reached $00, the end of our message
	JSR ECHO 					; Subroutine to place ACC on ACIA and LCD
        JSR DELAY  
        JSR DELAY 					; Delays needed for LCD, since I'm not reading from it to check busy flag. Lazy. 
        INY
        JMP GET 					; Moves the index to the next location, and loops to continue. 
        
        
TEXT: .BYTE "DeMon 4.1", $0A , $0D , $0A , $0D , "READY" , $0A, $0D, $0A, $0D, ">", $00
         

; Silences all channels of sound chip, sets tone data, and turns beep on and off. 

SILENCE: 	 					; VI2ORB is connected to sound chip data lines. PULSE strobes the enable line on SN to make it process data as command.
		 					; SN76489 documentation will cover how chip works. Not commenting much on what is going on here other than an overview. 
		 					; We send commands to silence each of the four channels, latch in tone data while silent to set the start beep to the 
		 					; pitch we want on channel 1, then briefly turn channel one on and back off. 
		 					
        LDA #@10111111 		
        STA VI2ORB
        JSR PULSE 
        LDA #@10011111 
        STA VI2ORB
        JSR PULSE
        LDA #@11011111 
        STA VI2ORB
        JSR PULSE
        LDA #$FF 
        STA VI2ORB 				
        JSR PULSE 

BEEP:		        
	LDA #@10001110
        STA VI2ORB
        JSR PULSE
      	LDA #@00001000 
      	STA VI2ORB
      	JSR PULSE
        LDA #@10010001 
        STA VI2ORB
      	JSR PULSE
      	JSR DELAYL 
      	LDA #@10011111 
      	STA VI2ORB
      	JSR PULSE
      	JMP PREP


              
; Warm start of monitor after all initialization and splash has been done. This is where the actual heart of the monitor code is
; General workflow is as follows: Take in data from keyboard or serial and place into a buffer. When enter is pressed, we check the first two characters to determine the desired command.
; We then parse data according to what command we're processing (figuring out an address to read or write from, a data byte to read or write, SN commands, etc)


PREP: ; 						; Y register is our index into the buffer

        LDY #$00 
											

SCAN: 							; Loop to scan keyboard or serial port for a keypress

        LDA VIAORB
        AND #@00001000 					; Check keyboard handshake. Is it low?
        BEQ GETKEY 					; Yes. Time to get the ASCII data from the keyboard. BEQ FOR CHECK IF LOW, BNE FOR CHECK IF HIGH.     
        LDA ACIA_STATUS 				; It isn't, so now check the serial port for a key.                                              
        AND #@00001000 
        BNE GETKEYSERIAL 				; We have a serial key.
        JMP SCAN 					; We have no keys pressed. Keep scanning until we do.

GETKEY: 						; Keyboard key is pressed. Grabs it. 

        LDA VI2ORA 					; ASCII data from keyboard. 
KEYCHK: CMP #$0D 					; Is it a CR (enter)?
        BEQ PROCESS 					; It is! Time to parse. We don't need to put the CR in buffer. 
        CMP #$08 					; Was the key backspace?
        BEQ BS 						; Yes! Print the BS and back the buffer up one spot
        STA BUFFER,Y 					; ASCII data stored in buffer, indexed by Y register. 
        JSR ECHO 
        INY 						; Move to the next buffer location and go back to looking for a keypress
        JMP SCAN 
BS:     JMP BKSP     

GETKEYSERIAL: 						; ASCII data is coming in from serial. Get it and process it with the same keychk routine 
	 
	LDA ACIA_DATA 
  	JMP KEYCHK
  

; This weird BEQ to JMP strcture was because the actual bits of 
; code that handled command processing were too far away to BEQ directly to.
; This is a, probably crappy, way of circumventing that. 

PROCESS: ; How do we process what's in the buffer?

        JSR CLEARSUB
        LDY #$00 					; Go back to the beginning of the buffer and start reading it to see what we typed. 
        LDA BUFFER,Y 					
        CMP #$57 					; Is it W?
        BEQ W 						; Yes.
        CMP #$52 					; R?
        BEQ R 						; Yes.
        CMP #$20 					; Space?
        BEQ SP						; Yes.
        CMP #$53 					; S?
        BEQ S 						; Yes.
        CMP #$43					; C?
        BEQ C						; Yes.					
        CMP #$4C   					; L?
        BEQ L 						; Yes.
        CMP #$08 					; Backspace?
        BEQ BS						; Yes.
        JMP READPREP					; It's none of these, so we assume you've typed in an address thats memory contents you want to read. 

W:      JMP WRITECOM        				; Now we jump to code that handles commands based on the first character. W for write, R for run, S for sound, Space for write next,
R:      JMP RUNCOM 					; C checks for either CL for clear, or C in an address, and L for reading a range of addresses.
SP:     JMP NEXTWRITE
S:      JMP SOUNDCOM         
C:      JMP CLCM         
L:      JMP LISTCMD       



							; When parsing commands, INY will be used to check the next spot in the input buffer, or move past characters we're
							; ignoring for parsing. 

READPREP: 						; Command for reading memory contents of typed address
           						; DIGIT is a subroutine which turns a typed ASCII character into a bit of hex and places it in RESULT buffer. IE, E to 0xE. Accumulator
          						; already has the first character of the address typed in it. So start. INY to move to next buffer location
          
        JSR DIGIT 					; Convert first byte in buffer to ASCII		 
        INY						; Next spot in buffer
        LDA BUFFER,Y					; LDA with spot in buffer we're on now
        JSR DIGIT 					; convert and repeat
        INY
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y 
        JSR DIGIT 					
          
          
READ: 							; Address to read from has now been converted to hex for the CPU to understand it. Let's get the data at that address now.
   
        JSR DROPLINE
        LDA (RESULT) 					; Indirect addressing. This means, essentially, load the value of the address that is referenced in RESULT. If result says 2000, we load the data at 2000.
        JSR PRBYTE 					; PRBYTE gets data in hex and converts back to ASCII, leaving the result in OUTPUT.         
        LDA OUTPUT  
        JSR ECHO					; ECHO places accumulator on displays. 
        LDA OUTPUT+1					
        JSR ECHO 
        JSR DROPLINE
        JSR PROMPT					; PROMPT prints the prompt character: >				
        JMP PREP 					; We're done. Back to the beginning of the loop.    
           


LISTCMD: 						; Reads memory at a range of addresses. Syntax L XXXX.XXXX
        LDA #$1B
        STA ACIA_DATA
        JSR DELAY
        LDA #$45 
        STA ACIA_DATA
        JSR DELAY
        LDA #@00000110 
        STA VIAORB
        LDA #$01
        STA VIAORA
        LDA #@00000100 
        STA VIAORB
        JSR DELAY
        JSR DELAY    					; Clear serial display with ESC sequence. Clear LCD and manually strobe enable. Not sure why we did it this way?
          
 							; Displays cleared. Time to do the command. 
 
        LDY #$00
        LDA BUFFER,Y
        INY 
        INY 						; Two INYs to move past the L and space. These don't need parsing. 
        LDA BUFFER,Y 
        JSR DIGIT 
        INY
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y 
        JSR DIGIT 
        INY						; Start address converting from ASCII to hex. Same as read command. 
        INY 						; Don't parse the . in command. 
        
        LDA BUFFER,Y
        JSR DIGIT3
        INY
          
        LDA BUFFER,Y
        JSR DIGIT3
        INY
          
        LDA BUFFER,Y
        JSR DIGIT3
        INY
          
        LDA BUFFER,Y
        JSR DIGIT3 
	STZ DROPCOUNT					; Same thing. Convert end address from ASCII to hex.  Digit3 is the same subroutine but puts the end address in RESULT2. 
          						; Also starts a variable called DROPCOUNT. Basically we want to drop a line in the list every 8 bytes. We'll use DROPCOUNT
          						; to keep track of how many bytes we've printed to the screen. Probably not the best way of doing this but I think I couldn't
          						; make the Y or X register do this for some reason? Also every 8 cycles we need to print the address that we're reading from
          						; for some frame of reference. 
          
LISTPRINT: 
             

        PHA 
        LDA RESULT+1 					; Address we're reading from, MSB. 
        JSR PRBYTE 
        LDA OUTPUT 
        JSR ECHO 					
        LDA OUTPUT+1 
        JSR ECHO
        LDA RESULT					; Address we're reading from, LSB. 
        JSR PRBYTE 
        LDA OUTPUT 
        JSR ECHO 
        LDA OUTPUT+1
        JSR ECHO 
        LDA #$3A 
        JSR ECHO
        LDA #$20 
        JSR ECHO
        PLA 						; This loop converts the address we're reading from at the start of the cycle into ASCII and displays it, along with colon and space. 
       							; Save the ACC just to be safe. I think I needed this?
       
       
        LDA DROPCOUNT
CMP1:   CMP #$08 					; Have we listed 8 bytes yes?
        BEQ YES 					; Yes. Jump to YES before continiuing. 
L2:     LDA (RESULT)
        JSR PRBYTE          
        LDA OUTPUT 
        STA VIAORA
        JSR ECHO
        LDA OUTPUT+1
        JSR ECHO
        LDA #$20 
        JSR ECHO					; Converts data into ASCII, diplays it with a space. 				
        CLC
        LDA RESULT
        ADC #1
        STA RESULT
        LDA RESULT 
        CMP RESULT2					; Increment RESULT, check RESULT2. Sees if starting address and ending address are the same, meaning command is done. 
        BEQ LISTEND 					; Command done
        CLC
        LDA DROPCOUNT
        ADC #1
        STA DROPCOUNT
        JMP CMP1				
         
            
YES:    JSR LDROP
        STZ DROPCOUNT
        JMP LISTPRINT 					; We've done the cycle 8 times. LDROP drops a line on display. Reset DROPCOUNT to zero. 
 
LDROP: 
        JSR DROPLINE
        RTS

LISTEND:  
          
        LDA (RESULT)
        JSR PRBYTE        
        LDA OUTPUT  
        JSR ECHO
        LDA OUTPUT+1
        JSR ECHO 
        JSR DROPLINE
        JSR DROPLINE
        JSR PROMPT
        JMP PREP 					; We've reached the end address. Manually display its byte since we're out of the loop and go back to the start of monitor.
          
          


WRITECOM: 						; Command to write data byte to address
          						; Syntax W AAAA DD
          						; Where AAAA is the address to write to, and DD is the data to write. 
           
        INY 
        INY 						; Ignore W and Space. No need to parse. 
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y
        JSR DIGIT  
        INY
        LDA BUFFER,Y 
        JSR DIGIT					 ; Address of where we are writing converted. Let's do the same with the data btye we're writing now. 
          
WRITEPREP: 
           
        INY 
        INY  
        JSR INIT2 
        LDA BUFFER,Y
        JSR DIGIT2 
        INY
        LDA BUFFER,Y 
        JSR DIGIT2
           						; INIT2 clears out WRITEV. WRITEV is the data byte we wish to write converted to hex. DIGIT2 does this conversion. 
           
WRITE: 
          
        LDA WRITEV 
        STA (RESULT) 
OK:     JSR DROPLINE
        LDA #$4F ; O
        JSR ECHO
        LDA #$4B ; K
        JSR ECHO
        JSR DROPLINE ;
        JSR PROMPT
        JMP PREP 					; Uses indirect addressing like the read command. Store WRITEV at the address referenced by RESULT. 








NEXTWRITE: 						; Writes a data byte to the subsequent address (after the initial write command is used)
	   						; Syntax: > DD
	   						; Space, and data byte to write. 
	   						; You MUST use the write command first. Also uses 16bit counting to be able to write to the entire memory map
	   						; Allows for input of code through all of RAM. 
	   						; WRITE COMMAND MUST BE DONE FIRST. PARSING OF ADDRESSES ARENT DONE HERE SINCE IT WOULD HAVE ALREADY BEEN DONE
	   						; IN THE WRITE COMMAND

        CLC
        LDA RESULT
        ADC #1 						; Adds 1 to result buffer. Ex, 00 20 -> 01 20 (Remember little-endian, this translates to 2000 -> 2001)
        STA RESULT

NWPREP: 
         
        INY ; MOVES PAST SPACE
        LDA BUFFER,Y
        JSR DIGIT2 ; 
        INY
        LDA BUFFER,Y
        JSR DIGIT2 ; 					; Same as WRITEPREP. Deciphers the buffer into the byte we want to write. 
         
NW: 

        LDA WRITEV
        STA (RESULT) 					; Stores Data at address referenced by the now incremented RESULT buffer. 
        LDA RESULT ; 
        CMP #$FF 
        BEQ HNINC 
        JMP OK						; Check result before moving on. If it's FF, we want to go to the next page of memory by 
      							; incrementing RESULT+1. ADC 1 to FF will reset RESULT back to 0. Any status flags set by this operation (if there are any) won't matter.
      							; FF 20 -> 00 21 (20FF - 2100). Enables continuous writing to all of memory map.
      							; Also print OK to confirm operation. 
HNINC: 
        CLC
        LDA RESULT+1 
        ADC #1 
        STA RESULT+1 
        JMP OK						; RESULT+1 incremented. Now we're writing to a new page.
      


RUNCOM: 						; Command for running code at a given address
							; Syntax R AAAA
							; Where AAAA is adress to run from 
	
        INY 						; Ignore the R in buffer
        INY 						; Ignore the SPACE
        LDA BUFFER,Y
        JSR DIGIT 
        INY
        LDA BUFFER,Y 
        JSR DIGIT 
        INY
        LDA BUFFER,Y 
        JSR DIGIT 
        INY
        LDA BUFFER,Y 
        JSR DIGIT 

RUN: 

        JMP (RESULT)  					; Converted Adress in RESULT. Indirect adress. IE, jump to the address referenced by the RESULT buffer. 
      
SOUNDCOM: 						; Writes a value to the soundchip and flashes its write enable line
	  						; Syntax: S DD
	  						; DD = data byte to be written to sound chip

        INY 						; moving past stuff we don't need to process
        INY 
        LDA BUFFER,Y 
        JSR DIGIT2 
        INY
        LDA BUFFER,Y 
        JSR DIGIT2  
        LDA WRITEV 					; Data bytes are treated just like the write command here.
        STA VI2ORB 
        JSR PULSE 					; Store the byte on VIA 2 output B, soundchip data lines. PULSE is a subroutine to flash the enable line of SN, but ONLY that line. 
        JSR DROPLINE
        JSR PROMPT
        JMP PREP 					; Drop a line, print prompt character. Back to beginning.  
           
CLCM: 							; Clear command. Just clears the displays with the byte to do so on LCD, and the same esc sequence on serial we've been using
      							; First though we have to make sure that the C in buffer is not a C in an address to be read. 
      
        INY 						; Move buffer up one to check next letter
        LDA BUFFER,Y
        CMP #$4C 					; First letter is C. Is the next letter L?
        BEQ CLEARCOM 					; Yes, run the clear command. 
        LDY #$00 					; No, set buffer back to 0
        LDA BUFFER,Y
        JMP READPREP 					; C has now been ignored. Jmp to read command and treat C as the start of an address.  
      
CLEARCOM: ; Monitor command for clearing screen
          
        LDA #$1B
        STA ACIA_DATA
        JSR DELAY 
        LDA #$45 					; Sends ESC+E to Tellymate, which is the command needed to clear. 
        STA ACIA_DATA
        JSR DELAY
        LDA #@00000110 					; LCD command register, SN and LCD WE high
        STA VIAORB
        LDA #$01 					; Clear LCD command
        STA VIAORA
        LDA #@00000100 					; LCD WE pulsed low. Done manually here since I want to hold the LCD register select low. Normally I don't but this is a command.
        STA VIAORB
        JSR DELAY
        JSR DELAY
        JSR DROPLINE
        JSR PROMPT
        JMP PREP 
          
BKSP: 							; processing backspaces

        DEY 						; Move the buffer counter back one
        LDA #$08
        JSR ECHO 					; displays a backspace on screen
        JMP SCAN 					; jump back to searching for a key press   




; Below are all subroutines needed. First section are subroutines I wrote. 

       
CLEARSUB: ; Subroutine for clearing out LCD display and Tellymate

       	LDA #@00000110 					; Sets SN WE line high, sets LCD WE high, places LCD in Command Regsiter
        STA VIAORB
        LDA #$01 					; Command to clear
        STA VIAORA
        LDA #@00000100 					; SN WE high, LCD WE low, command register of LCD
        STA VIAORB
        JSR DELAY
        JSR DELAY
        LDA #@00000111 					; Asserts all lines high again (SN WE, LCD WE, LCD Data Register)
        STA VIAORB
        JSR DELAY
        RTS
                                        
         
ECHO: ; Places accumulator on both the via LCD display, and serial displays

        STA VIAORA  
        STA ACIA_DATA  
        JSR DELAY 					; Delays needed here for both LCD and 6551 from WFDC
	
	.IF LCDCONNECTED 
	
  		LDA #@00000111
        	STA VIAORB
        	LDA #@00000101
        	STA VIAORB
        	JSR DELAY
        	LDA #@0000111 				; Pulses LCD write enable. Could rewrite to subroutine, but I hadn't figured that out yet. 
        	STA VIAORB
	
	.ENDIF 
	
        RTS

PROMPT: ; Subroutine to print prompt character. 
							

        LDA #$3E
        JSR ECHO
        RTS

DELAY:  LDX #0 	; Short delay. General purpose. Needed for coping with 6551 bug, and LCD processing time.
DELAY0: DEX
        BNE DELAY0
        RTS


DELAYL: LDX #200 ; Long delay should we need one. General purpose. 
DELAY2: LDY #0
DELAY1: DEY
        BNE DELAY1
        DEX
        BNE DELAY2
        RTS       
        
        
INIT2:  STZ WRITEV    ; Used to blank out the WriteV buffer. I don't remember why, but somewhere along the line, this was necessary. 
        STZ WRITEV+1
        RTS
        
     
DROPLINE: ; Drops displays down one line. 

        .if LCDCONNECTED
        	
        	LDA #@00000110 					; Puts LCD in command mode. 
        	STA VIAORB
        	LDA #$A8 					; Start screen address at 40. One line down from top. 
        	STA VIAORA
        	LDA #@00000100 					; Strobe enable line, keeping register select low. 
        	STA VIAORB
        	JSR DELAY
        	JSR DELAY
        	LDA #@00000111 					; LCD data mode
        	STA VIAORB
        .endif 
        
        LDA #$0A
        STA ACIA_DATA
        JSR DELAY
        LDA #$0D
        STA ACIA_DATA
        JSR DELAY
        LDA #$0A
        STA ACIA_DATA
        JSR DELAY
        LDA #$0D
        STA ACIA_DATA
        JSR DELAY					; Drop two lines on serial since we have the space to do so. 
        RTS
             
    
 
PULSE: ; Pulses write enable on sound chip. 

        LDA #@00000111
        STA VIAORB
        LDA #@00000011
        STA VIAORB
        JSR DELAY
        JSR DELAY
        LDA #@00000111
        STA VIAORB
        RTS

; Below are all subroutines provided by Garth Wilson and 6502 forum. Original comments are left intact. 

; CONVERTS ASCII TO HEX. THANKS GARTH :) 
; Here used for address to either read from or write to. IE, 2000, W *2000* 00 
; Stores converted address in RESULT buffer     


DIGIT:  SEC                  				; Start with ASCII digit in A.  Must be in the range of 0-9 and A-F.
        SBC  #$30           				; Put number in the range of 0-9 and $11-16
        CMP  #$0A           				; Is it too high to be in the 0-9 range?
        BCC  A
        SBC  #7              				; If so, bring $11-16 down to $0A-$0F.  (C was still set.)

A:      ASL  RESULT          			 	; Now scoot anything that was in the variable over by four bits
        ROL  RESULT+1        				; (shifting 0's in on the right), to make room for the new digit
                             				; as least significant.  This does not affect the accumulator.
        ASL  RESULT
        ROL  RESULT+1

        ASL  RESULT
        ROL  RESULT+1

        ASL  RESULT
        ROL  RESULT+1

        ORA  RESULT          				; Now put the new digit in on the right.
        STA  RESULT
       
        RTS

; Same ASCII -> Hex conversion as above, but here used to convert value being written to address
; IE, W 2000 *00*
; Converted value to be written is stored in WRITEV Buffer

DIGIT2: SEC                  
        SBC  #$30            
        CMP  #$0A            
        BCC  A2
        SBC  #7              

A2:     ASL  WRITEV          
        ROL  WRITEV+1        
                             
        ASL  WRITEV
        ROL  WRITEV+1

        ASL  WRITEV
        ROL  WRITEV+1

        ASL  WRITEV
        ROL  WRITEV+1

        ORA  WRITEV          
        STA  WRITEV

        RTS

; Same ASCII to hex conversions used above
; This is used for the list command. Converts the last address to be read from
; Ex. L 2000.**20FF**
; Converted end adress is stored in RESULT2 Buffer


DIGIT3: SEC                 
        SBC  #$30            
        CMP  #$0A            
        BCC  A3
        SBC  #7              

A3:     ASL  RESULT2         
        ROL  RESULT2+1       
                            
        ASL  RESULT2
        ROL  RESULT2+1

        ASL  RESULT2
        ROL  RESULT2+1

        ASL  RESULT2
        ROL  RESULT2+1

        ORA  RESULT2        
        STA  RESULT2

        RTS

              
       

;Another fabulous subroutine contribution from Garth and the 6502 forums. 
;Used to convert a hex byte back to Ascii data to display on screen. Used for reading address. 
;Converted Ascii data is in OUTPUT and OUTPUT+1 buffer



;PRBYTE subroutine:
; Converts a single Byte to 2 HEX ASCII characters and sends to console
; on entry, A reg contains the Byte to convert/send
; Register contents are preserved on entry/exit

PRBYTE         PHA   					;Save A register
               PHY   					;Save Y register
PRBYT2         JSR BIN2ASC   				;Convert A reg to 2 ASCII Hex characters
               STA OUTPUT   				;Print high nibble from A reg TO OUTPUT
               TYA           				;Transfer low nibble to A reg
               STA OUTPUT+1   				;Print low nibble from A reg TO OUTPUT
               PLY   					;Restore Y Register
               PLA   					;Restore A Register
               RTS   					;And return to caller


;BIN2ASC subroutine: Convert byte in A register to two ASCII HEX digits
;Return: A register = high digit, Y register = low digit

BIN2ASC        PHA   					;Save A Reg on stack
               AND #$0F   				;Mask off high nibble
               JSR ASCII   				;Convert nibble to ASCII HEX digit
               TAY   					;Move to Y Reg
               PLA   					;Get character back from stack
               LSR    					;Shift high nibble to lower 4 bits
               LSR  
               LSR   
               LSR   
;
ASCII          CMP #$0A   				;Check for 10 or less
               BCC ASOK   				;Branch if less than 10
               CLC   					;Clear carry for addition
               ADC #$07   				;Add $07 for A-F
ASOK           ADC #$30   				;Add $30 for ASCII
               RTS   					;Return to caller
                                   
