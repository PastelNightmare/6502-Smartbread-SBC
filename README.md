# Archiving, for now! I don't recommend using V1 of the board as of now.
As I play around with the finished PCB, I realized there are a few issues with it. 
- A13 is not connected to the RAM chip, so you have to make a jumper to it from elsewhere. 
- The below mentioned difference in clock generation from other processors to the WDC version.
- I'm using the WDC 65C22S, which does NOT have an open-drain interrupt output! It has a totem pole ouput! Right now, it's currently wired as if it were open drain, which is fine as long as you **don't use interrupts.** If you do though, you will short circuit the IRQ lines of the VIA.

# Upcoming hardware changes? 
- Reconnect A13, obviously.
- Make the system clock with WDC parts in mind
- Add schottky diodes on the VIA interrupts to connect them with the other open drain interrupts. Fine at 2mhz clock speed.
- Change address decoding to use Daryl Rictors DEC-1. https://sbc.rictor.org/decoder.html

# Upcoming software changes? 
- A customized version of EHBasic, which I've already made. Includes commands for sound, clearing screen, and returning to the monitor.
- Updating VGM player to load VGM out of RAM instead of ROM, and commented to explain better what it is doing. 
- Porting WozMon to this board for easier data entry. DeMon is fine, but it was more a project for me anyway. 
- A better terminal emulator program
- Eventually, using the new interrupts to allow streaming of VGM from the serial port. But that is a long time off. 

# IMPORTANT DESIGN NOTE
Due to a design difference with the WDC version of the 65C02 processor, this board will not work with WDC chips without a small modification. See "Using a WDC 65C02" below.

# SmartBread: A 6502 based single-board computer 
Its name came from a friend who called it this when they saw my initial prototypes on a breadboard. MintSpark Electronics was the working "maker name" for my projects, though it may not be for long. Other than another 6502 based single board computer, of which many exist, this was many firsts for me. Starting in 2017, I had a goal to build a 6502 system on a breadboard. As it grew, it became my first real endeavour into 6502 assembly, coding for an actual system, trying to make user friendly software, and PCB making. I now have working PCBs, a few programs, and much more work to do. 

Repo includes software, PCB gerber files and resources. ROM included has DeMon 4.0 and EhBASIC w/ its cold start monitor. Other files can be added and recompiled as desired 

Software assumes you are using the Kowalski 6502 simulator for assmebly. https://sbc.rictor.org/kowalski.html 

# Disclaimer: 
This was my first stab at assembly of any kind. While the code does exactly what I want it to do for this system, I understand that my code is not pretty by any stretch, and there is tons of room for improvement. I'm a novice, so please go easy on me. Some things like address decoding were figured out with the help of the 6502 forum and the 6502 Primer by Garth Wilson. Found at: http://wilsonminesco.com/

# Specs
- 65C02 processor running at 2mhz
- 2x 65C22 VIA (versatile interface adapter) chips
- 1x 65C51 ACIA (UART) chip
- SN76489 soundchip
- 32KB EEPROM (AT28C256)
- 16KB RAM (Alliance AS6C62256. 32kb chip, address decoding makes it 16kb)
- ATTINY26 for keyboard input
- Quad NAND gate 74 chip for address decoding
- Jumpers to fully configure serial port settings
- GPIO port, spare 8 bit parallel. 5v and GND also available. 
- PS2 keyboard input
- RCA output for sound. 
- Displays to charcter LCD or serial using any terminal device (board has a slot for the BatSocks tellymate tiny for this purpose http://www.batsocks.co.uk/products/Other/TellyMate%20Tiny.htm)

# Parts list
- R1-R6: 3.3k through hole resistor
- R7, R8: 10k through hole resistor
- R9: 370 ohm resistor. 
- C1: 1uf electrolytic capacitor. 
- All other capacitors: 100nf filter. Ceramic disc.
- 6502CLCK: ECS-100AX-018 oscillator, 2MHz
- SNCLCK: ECS-100AX-018 oscillator, 4MHz
- SERCLCK: ECS-100AX-018 oscillator, 1.8432MHz
- 65C02 processor
- VIA1, VIA2: 65C22 VIA chips (keyboard doesn't work right with non-CMOS versions)
- ACIA: 65C51 ACIA chip
- ROM: AT28C256
- RAM: Alliance AS6C62256
- ADDR: CD74HCT132E
- SN: Texas Instruments: SN76489
- ATTINY26: Atmel ATTINY26
- POWER: 5v through header, or surface mount USB Mini B jack. 

# Included Software
## DeMon 4.0
DeMon (DEvice MONitor) 4.0 is a basic memory monitor for the system. You can read the memory map, write to the memory map, run code, send commands directly to the sound chip, and much more. 
### Commands
All commands are processed by pressing enter. Accepts input from onboard PS2 keyboard or ACIA (with FTDI breakout)


| Command | Example | Description |         
| --------------- | --------------- | --------------- |
| Read  | 4000  | Displays data at address 0x4000  |
| List |L 2000.20FF| Will display all data between addresses 0x2000 and 0x20FF |
| Write  | W 2000 FF | Writes 0xFF at address 0x2000  |
| Write next | 00 | Data byte preceded with a space will write data to next location. MUST USE WRITE COMMAND FIRST |
| Run | R 2000 | Runs code starting at address 2000 | 
| Clear | CL | Clears all displays |
| Sound | S FF | Sends 0xFF to sound chip and makes the chip process it | 

## VGM player
A simple VGM player to play VGM files for the SN76489 sound chip. Expects raw VGM hex at 8900 (0900 if you're burning to ROM). Could easily be changed to load hex out of RAM instead with one line of code. 

## Enhanced 6502 BASIC 2.22 (EhBASIC) port
Made by Lee Davison, information: http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/enhanced-6502-basic/. Ported to SmartBread by me. **COMPILING NOTE:** in order to compile EhBASIC, point the include line at the beginning of the Minimal Monitor to where you've downloaded EHBASIC.ASM. Minimal monitor starts at A000 and should be used to cold start BASIC! 

# Port Description
- GPIO - 8 bit parallel GPIO port. Can attach LCD to this port to work natively with DeMon, but it isn't required and can be used for whatever else the end user desires. The current board DOES NOT have the LCD enable line on this port, but it will be added to a future revision. 
- TM - Tellymate Tiny can be connected here for composite display. The part is discontinued, but eagle files and firmware exist on the Batsocks website. 
- Serial - Gives control lines for the ACIA ports, along with GNDs next to each one. Allows these status lines to be jumpered to ground, which **should** be done for most operations. (DTR, RTS, CTS, DCD) Also provides 5v and GND for user. Can connect to a TTL to RS232 converter for any type of serial display. 
- CLKMODE - Shorting these two pins with solder or a jumper allows the serial clock to also run the processor clock. This saves one part, but makes the CPU run slightly slower. 

# Using a WDC 65C02
In order to use a WDC version of the processor in the current revision, there is a slight modification to the board that must be made. Pin 39 (PHI2O) on the chip must be lifted out of the socket or removed. Then on the underside of the board, you must bridge a connection between Pin 39 and Pin 37 of the CPU socket. 

Traditionally, you provide the clock frequency to the CPU via PHI0/PHI2 input, then drive the rest of peripherals from PHI2O output from the CPU. The board was made with this in mind. WDC chips, however, do not test or guarantee the usability of the PHI2O output. They recommend that everything onboard receives its clock from the main oscillator driving the CPU. By bridging these two points on the board and lifting pin 39 from the chip, you are routing the clock in this manner. Future board revisions will have this as a jumper to ensure compatiblity. 

# To-do list / Wishlist 
- Update display to a new, non-discontinued solution. For now, Tellymate Tiny could be used, or provided serial pins can be attached to any device with a TTL to RS232 converter (Max232 and the like): Breakout USB boards, Converted RS232 port to a real glass terminal, etc. 
- Improve code by removing useless structures / subroutines
- Adding a binary load command to DeMon load binary data directly into memory from serial port. 
- Either standalone or built-in assembly evnironment for DeMon. 
- Text editor prorgram
- SPI protocol for various peripherals. 
- Cassette interface. 
- Rewrite my old code. The VGM player is old and hard to read. This was before I knew much about anything coding wise. 
- Write a terminal emulator program. I did make SimTerm originally, but it is hot garbage. 
