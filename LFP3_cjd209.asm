#Author:	Cory Drangel
#Date:		April 11, 2023
#Class:		CMPEN 351
#Assignment:	Final Project

.data
StackBeg: .word 0:80
StackEnd:
ColorTable:
	.word 0x000000	#black
	.word 0xffff00  #green + red = yellow
	.word 0x0000ff	#blue
	.word 0x00ff00	#green
	.word 0xff0000	#red
	.word 0x00ffff 	#blue + green
	.word 0xff00ff	#blue + red
	.word 0xffffff	#white
OddX: .word 20, 60, 100, 140, 180, 220
EvenX: .word 40, 80, 120, 160, 200
Y: .word 30, 50, 70, 90, 110
HeroX: .word 123
Color: .word, 4, 2, 3, 6, 1
lastMove: .word 1
laserCount: .word 0
laser: .word 0:600
AlienTable: .word 0:28
queue: .word 0:300
queue_point: .word 0
queue_start: .word 0
score: .word 0
boxesHit: .word 0
msg1: .asciiz "Welcome to space invaders!\nTo play use the 'a' key to move the hero to the left,\nthe 'd' key to move the hero to the right and\nthe space key to fire!"
msg2: .asciiz "Game Over!\nYour score is:\n"
msg3: .asciiz "Congrats! You win!\nYour Score:\n"

# Status rciiz egister bits
EXC_ENABLE_MASK:        .word   0x00000001

# Cause register bits
EXC_CODE_MASK:          .word   0x0000003c  # Exception code bits

EXC_CODE_INTERRUPT:     .word   0   # External interrupt
EXC_CODE_ADDR_LOAD:     .word   4   # Address error on load
EXC_CODE_ADDR_STORE:    .word   5   # Address error on store
EXC_CODE_IBUS:          .word   6   # Bus error instruction fetch
EXC_CODE_DBUS:          .word   7   # Bus error on load or store
EXC_CODE_SYSCALL:       .word   8   # System call
EXC_CODE_BREAKPOINT:    .word   9   # Break point
EXC_CODE_RESERVED:      .word   10  # Reserved instruction code
EXC_CODE_OVERFLOW:      .word   12  # Arithmetic overflow

# Status and cause register bits
EXC_INT_ALL_MASK:       .word   0x0000ff00  # Interrupt level enable bits

EXC_INT0_MASK:          .word   0x00000100  # Software
EXC_INT1_MASK:          .word   0x00000200  # Software
EXC_INT2_MASK:          .word   0x00000400  # Display
EXC_INT3_MASK:          .word   0x00000800  # Keyboard
EXC_INT4_MASK:          .word   0x00001000
EXC_INT5_MASK:          .word   0x00002000  # Timer
EXC_INT6_MASK:          .word   0x00004000
EXC_INT7_MASK:          .word   0x00008000

.text
la $sp, StackEnd

	# Enable interrupts in status register
	mfc0    $t0, $12

	# Disable all interrupt levels
	lw      $t1, EXC_INT_ALL_MASK
	not     $t1, $t1
	and     $t0, $t0, $t1
	
	# Enable console interrupt levels
	lw      $t1, EXC_INT3_MASK
	or      $t0, $t0, $t1
	#lw      $t1, EXC_INT4_MASK
	#or      $t0, $t0, $t1

	# Enable exceptions globally
	lw      $t1, EXC_ENABLE_MASK
	or      $t0, $t0, $t1

	mtc0    $t0, $12
	
	# Enable keyboard interrupts
	li      $t0, 0xffff0000     # Receiver control register
	li      $t1, 0x00000002     # Interrupt enable bit
	sw      $t1, ($t0)

#loads initial message for user
la $a0, msg1
li $v0, 4
syscall

#draws hero on display
li $a0, 123
li $a1, 246
li $a2, 7
li $a3, 10
jal DrawBox


Main:
la $t0, laserCount
lw $t1, 0($t0)          #loads value of laser count into t1
beqz $t1, contMain      #jumps over CheckLaser function if laser count = 0

jal CheckLaser

contMain:
jal NewDisplay          #jump to function to draw display

jal MoveHero            #jump to function to move hero

la $a0, lastMove        #loads the last move into a0
jal MoveBox             #jump to function to move boxes/aliens

li $a0, 1000
jal Pause               #pause program

jal ClearBoxes          #clears boxes from screen

la $t3, boxesHit
lw $t4, 0($t3)          #loads number of boxes hit into t4
beq $t4, 28, win        #if all boxes have been hit, move to win

la $t0, Y
lw $t1, 4($t0)          #loads value of last y coordinate into t1
ble $t1, 236, Main      #continues program loop if y coordinate hasn't reached bottom yet

la $a0, msg2            #loads message to user that games is over
li $v0, 4
syscall

la $t2, score       
lw $a0, 0($t2)          #loads score into a0
li $v0, 1
syscall                 #displays score
j end

win:
la $a0, msg3            
li $v0, 4               #displays win message to user
syscall

la $t2, score
lw $a0, 0($t2)
li $v0, 1               #displays users score
syscall

end:
li $v0, 10
syscall                 #exits program

#Procedure: calcAddress
#Input: a0 = x coordinate (0-255)
#Input: a1 = y coordinate (0-255)
#returns v0 = memory address
calcAddress:
#$v0 = base + $a0 * 4 + $a1 * 32 * 4
li $v0, 0x10040000
mul $a0, $a0, 4
add $v0, $v0, $a0
mul $a1, $a1, 256
mul $a1, $a1, 4
add $v0, $v0, $a1
jr $ra

#Procedure: GetColor
#Input: a2 = color number (0-7)
#returns $v1 = actual number to write to display
GetColor:
la $t0, ColorTable	#load base
sll $a2, $a2, 2		#index x4 is offset
add $a2, $a2, $t0	#address is base + offset
lw $v1, 0($a2)		#get actual color from memory
jr $ra

#Procedure: DrawDot
#Input: a0 = x coordinate (0-255)
#Input: a1 = y coordinate (0-255)
#Input: a2 = color number (0-7)
#Draws a single dot on the bitmap display
DrawDot:
addiu $sp, $sp, -8	#make room for stack, 2 words
sw $ra, 4($sp)		#store ra
sw $a2, 0($sp)		#store a2
jal calcAddress		#v0 has address for color
lw $a2, 0($sp)		#restore a2
sw $v0, 0($sp)		#save v0
jal GetColor		#v1 has color
lw $v0, 0($sp)		#restore v0
sw $v1, 0($v0)		#make dot
lw $ra, 4($sp)		#load original ra
addiu $sp, $sp, 8	#adjust sp
jr $ra

#Procedure: HorzLine
#Input: a0 = x coordinate (0-255)
#Input: a1 = y coordinate (0-255)
#Input: a2 = color number (0-7)
#Input: a3 = length of line (1-256)
#Draws a horizontal line 
HorzLine:
addiu $sp, $sp, -20	#make room for stack, 4 words
sw $ra, 16($sp)		#store ra
sw $a1, 12($sp)		#store a1
sw $a2, 8($sp)		#store a2
HorzLoop:
sw $a0, 4($sp)		#store a0
sw $a3, 0($sp)		#store a3
jal DrawDot
lw $a3, 0($sp)		#restore a3
lw $a0, 4($sp)		#restore a0
lw $a2, 8($sp)		#restore a2
lw $a1, 12($sp)		#restore a1
addiu $a0, $a0, 1	#increment x coordinate (a0)
addiu $a3, $a3, -1	#decrement line left (a3)
bne $a3, $0, HorzLoop
lw $ra, 16($sp)		#restore $ra
addiu $sp, $sp, 20	#adjust sp
jr $ra

#Procedure: VertLine
#Input: a0 = x coordinate (0-255)
#Input: a1 = y coordinate (0-255)
#Input: a2 = color number (0-7)
#Input: a3 = length of line (1-256)
#draws a vertical line
VertLine:
addiu $sp, $sp, -20	#make room for stack, 5 words
sw $ra, 16($sp)		#store ra
sw $a0, 12($sp)		#store a0
sw $a2, 8($sp)		#store a2
VertLoop:
sw $a1, 4($sp)		#store a1
sw $a3, 0($sp)		#store a3
jal DrawDot
lw $a3, 0($sp)		#restore a3
lw $a1, 4($sp)		#restore a1
lw $a2, 8($sp)		#restore a2
lw $a0, 12($sp)		#restore a0
addiu $a1, $a1, 1	#increment x coordinate (a1)
addiu $a3, $a3, -1	#decrement line left (a3)
bne $a3, $0, VertLoop
lw $ra, 16($sp)		#restore $ra
addiu $sp, $sp, 20	#adjust sp
jr $ra

#Procedure: DrawBox
#Input: a0 = x coordinate (0-255)
#Input: a1 = y coordinate (0-255)
#Input: a2 = color number (0-7)
#Input; a3 = size of the box (1-256)
#draws a box on the bitmap based on inputs
DrawBox:
addiu $sp, $sp, -24	#make room for stack, 6 words
sw $ra, 20($sp)		#store ra
sw $s0, 16($sp)		#store s0
move $s0, $a3		#copy a3->s0
BoxLoop:
sw $a0, 12($sp)		#store a0
sw $a1, 8($sp)		#store a1
sw $a2, 4($sp)		#store a2
sw $a3, 0($sp)		#store a3
jal HorzLine
lw $a3, 0($sp)		#restore a3
lw $a2, 4($sp)		#restore a2
lw $a1, 8($sp)		#restore a1
lw $a0, 12($sp)		#restore a0
addiu $a1, $a1, 1	#increment y coordinate
addiu $s0, $s0, -1	#decrement counter
bne $s0, $0, BoxLoop
lw $s0, 16($sp)		#restore s0
lw $ra, 20($sp)		#restore ra
addiu $sp, $sp, 24	#adjust sp
jr $ra

#Procedure: ClearDisplay
#draw a large "black" blx over the entire display
ClearDisplay:
addiu $sp, $sp, -4	#make room for stack, 1 word
sw $ra, 0($sp)		#store ra
li $a0, 0		#x coordinate = 0
li $a1, 0		#y coordinate = 0
li $a2, 0		#black color
li $a3, 256		#full screen size
jal DrawBox
lw $ra, 0($sp)		#restore ra
addiu $sp, $sp, 4	#adjust sp
jr $ra

#Procedure: NewDisplay
#Draws the display of the aliens and the lasers onto the screen
NewDisplay:
addiu $sp, $sp, -36	#make room on stack for 7 words
sw $ra 32($sp)		#store ra
#jal ClearDisplay	#jump to clear the display

li $t0, 1		#row number
la $t1, Y		#t1 = address of the y coordinate
la $t2, Color		#t2 = address of the color number
la $t6, AlienTable  #loads AlientTable into t6
outLoop:
rem $t3, $t0, 2		#t3 = flag 1 if t0 is odd and 0 if odd
beq $t3, 0, even
beq $t3, 1, odd

odd:
la $t4, OddX		#t4 = address of x coordinate
li $t5, 6		#t5 = number of boxes to load into row
j inLoop		#jumps to inner loop
even:
la $t4, EvenX
li $t5, 5
j inLoop

inLoop:
sw $t6, 28($sp)
sw $t0, 24($sp)		#store t0 on stack
sw $t1, 20($sp)		#store t1 on stack
sw $t2, 16($sp)		#store t2 on stack
sw $t3, 12($sp)		#store t3 on stack
sw $t4, 8($sp)		#store t4 on stack
sw $t5, 4($sp)		#store t5 on stack

lw $t7, 0($t6)      #loads value of AlienTable into t7
bnez $t7, jumpDraw  #jumps over drawing alien if value in table is not 0

lw $a0, 0($t4)		
lw $a1, 0($t1)
lw $a2, 0($t2)
li $a3, 10
jal DrawBox		#draws box for "alien"

jumpDraw:
lw $t5, 4($sp)		#loads t5 off stack
lw $t4, 8($sp)		#loads t4 off stack
lw $t3, 12($sp)		#loads t3 off stack
lw $t2, 16($sp)		#loads t2 off stack
lw $t1, 20($sp)		#loads t1 off stack
lw $t0, 24($sp)		#loads t0 off stack
sw $t6, 28($sp)

addiu $t6, $t6, 4
addiu $t4, $t4, 4	#moves pointer for x coordinate by 4
addiu $t5, $t5, -1	#decreases number of boxes needed to be drawn
bnez $t5, inLoop

addiu $t1, $t1, 4	#moves pointer for y coordinate by 4
addiu $t2, $t2, 4	#moves pointer for color number by 4
addiu $t0, $t0, 1	#adds one to the number of rows
ble $t0, 5, outLoop

la $t0, laserCount      
lw $t1, 0($t0)          #loads laser count into t1
li $t4, 0               #t4 is counter
beqz $t1, displayCont   #if laser count = 0 then jump of drawing lasers

la $t2, laser
drawLaser:
sw $t4, 8($sp)
sw $t1, 4($sp)
sw $t2, 0($sp)
lw $a0, 0($t2)          #loads x value of laser into a0
lw $a1, 4($t2)          #loads y value of laser into a1
addiu $t3, $a1, -5      #stores adjusted y into t3
sw $t3, 4($t2)          #stores new y into laser
lw $a2, 8($t2)          #loads laser color into a2
beqz $a2, jumpdrawLaser #if laser color is black jump over drawing laser
lw $a3, 12($t2)         #loads length of laser into a3
jal VertLine            #draws laser
jumpdrawLaser:
lw $t2, 0($sp)
lw $t1, 4($sp)
lw $t4, 8($sp)
addiu $t2, $t2, 16      #move laser pointer to next laser
addiu $t4, $t4, 1       #add one to counter
bne $t4, $t1, drawLaser #if counter does not equal laser count, keep drawing lasers

displayCont:
lw $ra, 32($sp)		#loads ra off stack
addiu $sp, $sp, 36	#re-adjusts stack
jr $ra

#Procedure: Pause
#Input $a0 - number of milliseconds to wait
#Pauses the program for a given number of milliseconds
Pause:
move $t0, $a0			#save timeout to t0
li $v0, 30			#get initial time
syscall
move $t1, $a0			#save to t1

pauseLoop:
syscall				#get current time
subu $t2, $a0, $t1		#elapsed = current - initial
bltu $t2, $t0, pauseLoop	#if elapsed < timeout; goes back to loop again

jr $ra

#Procedure: MoveBox
#Input: a0 - last move (1 = right, 2= left, 3 = down)
#moves boxes/aliens into a new location
MoveBox:
addiu $sp, $sp, -4          #adjust stack
sw $ra, 0($sp)              #store ra

lw $t0, 0($a0)              #loads last move into t0
la $t1, OddX                #loads address of OddX into t1
beq $t0, 1, rightCheck      #if t0 = 1; go to rightCheck
beq $t0, 2, leftCheck       #else if t0 = 2; go to leftCheck
beq $t0, 3, downCheck       #else if t0 = 3; go to downCheck 

rightCheck:
lw $t2, 0($t1)              #loads x value into t2
bge $t2, 44, moveDown       #checks if x value is greater than 44, if it is move the aliens down
j moveRight                 #else move them to the right

leftCheck:
lw $t2, 0($t1)              #loads x value into t2
ble $t2, 2, moveDown        #checks if x value is less than or equal to 2, if it is go to move aliens down
j moveLeft                  #else move the aliens to the left

downCheck:
lw $t2, 0($t1)              #loads x value into t2
ble $t2, 2, moveRight       #checks if they are all the way against the left, if they are move to the right
j moveLeft                  #else move them to the left

moveRight:
li $t0, 3		#t0 = value to move x coordinate by
la $t1, OddX
li $t2, 0		#counter
rightLoopOdd:
lw $t3, 0($t1)              #loads current x into t3
add $t3, $t3, $t0           #adds to the x value
sw $t3, 0($t1)              #stores the new x value
addiu $t1, $t1, 4           #moves pointer to the next x value
addiu $t2, $t2, 1           #adds to counter
blt $t2, 6, rightLoopOdd    #continue if haven't done all x values yet

la $t1, EvenX
li $t2, 0                   #counter
rightLoopEven:
lw $t3, 0($t1)              #loads current x into t3
add $t3, $t3, $t0           #adds to the x value
sw $t3, 0($t1)              #stores new x value
addiu $t1, $t1, 4           #moves pointer to the next x value
addiu $t2, $t2, 1           #adds to counter
blt $t2, 5, rightLoopEven   #continue if haven't done all x values yet

li $t4, 1
sw $t4, lastMove            #stores last move as being to the right
j moveOn

moveLeft:
li $t0, -3		#t0 = value to move x coordinate by
la $t1, OddX
li $t2, 0		#counter
leftLoopOdd:
lw $t3, 0($t1)              #loads current x value into t3
add $t3, $t3, $t0           #adds to x value
sw $t3, 0($t1)              #stores new x value
addiu $t1, $t1, 4           #moves pointer to the next x value
addiu $t2, $t2, 1           #adds to counter
blt $t2, 6, leftLoopOdd     #continues loop if all x values haven't been modified

la $t1, EvenX
li $t2, 0                   #counter
leftLoopEven:
lw $t3, 0($t1)              #loads current x value into t3
add $t3, $t3, $t0           #adds to the x value
sw $t3, 0($t1)              #stores new x value
addiu $t1, $t1, 4           #moves pointer to the next x value
addiu $t2, $t2, 1           #adds to the counter
blt $t2, 5, leftLoopEven    #continue loop if all x values haven't been modified

li $t4, 2
sw $t4, lastMove            #stores last move as being to the left
j moveOn

moveDown:

la $t1, Y                   #loads address of Y
li $t2, 0                   #counter
downLoop:
lw $t3, 0($t1)              #loads value of current Y
addiu $t3, $t3, 5           #adds to the y value
sw $t3, 0($t1)              #stores the new y value
addiu $t1, $t1, 4           #moves pointer to the next y value
addiu $t2, $t2, 1           #adds to counter
blt $t2, 5, downLoop        #continues loop if all y values haven't been modified

li $t4, 3
sw $t4, lastMove            #stores last move as being down

j moveOn

moveOn:

lw $ra, 0($sp)              #loads ra from stack
addiu $sp, $sp, 4           #readjusts stack

jr $ra

#Procedure: ClearBoxes
#Clears boxes from screen using large box and serveral lines
ClearBoxes:
addiu $sp, $sp, -8	#make room for stack, 1 word
sw $ra, 4($sp)		#store ra
li $a0, 0		#x coordinate = 0
li $a1, 0		#y coordinate = 0
li $a2, 0		#black color
li $a3, 246		
jal DrawBox     #draws box

li $t0, 246         #position of where box ends
clearLoop:
sw $t0, 0($sp)      #stores t0 to stack
move $a0, $t0
li $a1, 0
li $a2, 0
li $a3, 246
jal VertLine        #draws vertical line
lw $t0, 0($sp)      #loads t0 from stack
addiu $t0, $t0, 1   #adds one to position of t0
ble $t0, 256, clearLoop     #continues loop until reaches edge

lw $ra, 4($sp)		#restore ra
addiu $sp, $sp, 8	#adjust sp
jr $ra

#Procedure: MoveHero
#moves hero or shoots laser based on value in queue
MoveHero:
addiu $sp, $sp, -16             #adjusts stack
sw $ra, 12($sp)                 #stores ra

la $t0, queue                   #loads the address of the queue into t0
la $t1, queue_start         
lw $t2, 0($t1)                  #loads the value of where the queue starts into t2
sw $t2, 8($sp)
add $t0, $t0, $t2               #adds the address of the queue to the queue start
lw $v0, 0($t0)                  #loads the value from the queue into v0
beqz $v0, heroConti             #if there is no value in queue jump to continue program

beq $v0, 32, fireLaser          #if ASCII value of queue value is 32, ie space bar, jump to fire laser

sw $v0, 4($sp)                  #store v0 to stack
la $t0, HeroX                   #loads address of the hero's x into t0
sw $t0, 0($sp)
lw $a0, 0($t0)                  #loads value of hero x into a0
li $a1, 246
li $a2, 0                       #makes color of hero black to delete old hero
li $a3, 10
jal DrawBox                     #draws black box

lw $t0, 0($sp)
lw $v0, 4($sp)
lw $a0, 0($t0)
beq $v0, 97, heroLeft          #if value from queue is 97, ie a key, move hero to the left
beq $v0, 100, heroRight        #else if value from queue is 100, ie d key, move hero to the right

heroLeft:
addiu $a0, $a0, -30            #adjust hero x position
j heroCont

heroRight:
addiu $a0, $a0, 30             #adjust hero x position
j heroCont

fireLaser:
la $t0, laserCount
lw $t1, 0($t0)                 #load value of laser count into t1
addiu $t1, $t1, 1              #add one to laser count
sw $t1, 0($t0)                 #store new laser count

addiu $t1, $t1, -1
mul $t1, $t1, 16

la $t2, laser
add $t2, $t2, $t1              #starting address for new laser
la $t3, HeroX           
lw $t4, 0($t3)                 #value of hero x in t4
addiu $t4, $t4, 5              #adding 5 to hero x for middle position of hero where laser should come from
sw $t4, 0($t2)                 #store laser x
li $t3, 236
sw $t3, 4($t2)                 #store laser y
li $t3, 7
sw $t3, 8($t2)                 #store laser color
li $t3, 10
sw $t3, 12($t2)                #store laser length

li $a0, 60
li $a1, 1000
li $a2, 31
li $a3, 127
li $v0, 31
syscall                        #make noise when laser is fired

lw $t2, 8($sp)
addiu $t2, $t2, 4
sw $t2, queue_start            #adjust queue start position to next value
j heroConti

heroCont:
sw $a0, HeroX
li $a1, 246
li $a2, 7
li $a3, 10
jal DrawBox                    #draws new hero
lw $t2, 8($sp)

addiu $t2, $t2, 4           
sw $t2, queue_start            #adjust queue start position to next value

heroConti:
lw $ra, 12($sp)                #load ra from stack
addiu $sp, $sp, 16             #readjust stack

jr $ra

#Procedure: Check Laser
#checks to see if laser has made collision with alien
CheckLaser:
addiu $sp, $sp, -8          #adjust stack
sw $ra, 4($sp)              #store ra to stack

la $t1, laserCount
lw $v0, 0($t1)              #loads value of laser count into v0
li $v1, 0                   #v1 = counter

la $t0, laser

laserCheck:
lw $t1, 4($t0)              #loads y coordinate of laser into t1
la $t2, Y
li $t3, 0                   #counter
checkY:
lw $t4, 0($t2)              #value of next y coordinate of alien
addiu $t4, $t4, 10          #adjusts y value for edge of alien
addiu $t2, $t2, 4           #move to next alien y value
addiu $t3, $t3, 1           #add one to counter
bgt $t1, $t4, checkYcont    #check if y value of laser is within first bound; jumps if not
addiu $t4, $t4, -10         #adjusts for other bound
blt $t1, $t4, checkYcont    #jump if not within second bound
j checkX                    #jump to check x if between both y bounds

checkYcont:
blt $t3, 5, checkY          #continues checking other y values if all haven't been checked
ble $t1, 10, reachedTop     #jump to reach top if laser at top
j contLaser

reachedTop:
li $t1, 0                   #marks the laser as black if at the top so it isn't drawn
sw $t1, 8($t0)
j contLaser

checkX:
rem $t5, $t3, 2             #determine row to check
beqz $t5, checkEvenX
j checkOddX

checkEvenX:
lw $t1, 0($t0)
la $t6, EvenX
li $t7, 0
inCheckEven:
lw $t2, 0($t6)
addiu $t6, $t6, 4           #move to next x position
addiu $t7, $t7, 1           #add to counter
blt $t1, $t2, checkEvencont
addiu $t2, $t2, 10
bgt $t1, $t2, checkEvencont
j match
checkEvencont: 
blt $t7, 5, inCheckEven
j contLaser

checkOddX:
lw $t1, 0($t0)
la $t6, OddX
li $t7, 0
inCheckOdd:
lw $t2, 0($t6)
addiu $t6, $t6, 4
addiu $t7, $t7, 1
blt $t1, $t2, checkOddcont
addiu $t2, $t2, 10
bgt $t1, $t2, checkOddcont
j match
checkOddcont:
blt $t7, 6, inCheckOdd
j contLaser

match:
la $t1, boxesHit
lw $t2, 0($t1)
addiu $t2, $t2, 1
sw $t2, 0($t1)

li $t1, 0
sw $t1, 8($t0)

addiu $t5, $t3, -1
mul $t5, $t5, 6
add $t5, $t5, $t7
addiu $t5, $t5, -1
ble $t3, 2, contMatch
addiu $t5, $t5, -1
ble $t3, 4, contMatch
addiu $t5, $t5, -1

contMatch:
mul $t5, $t5, 4
la $t1, AlienTable
add $t5, $t5, $t1
li $t2, 1
sw $t2, 0($t5)

sw $v0, 0($sp)

li $a0, 60
li $a1, 1000
li $a2, 119
li $a3, 127
li $v0, 31
syscall

lw $v0, 0($sp)

li $t1, 6
sub $t1, $t1, $t3
mul $t1, $t1, 10
bgt $t3, 4, contScore
addiu $t1, $t1, 20
bne $t1, 1, contScore
addiu $t1, $t1, 10

contScore:
la $t2, score
lw $t4, 0($t2)
add $t4, $t4, $t1
sw $t4, score

contLaser:
addiu $t0, $t0, 16
addiu $v1, $v1, 1
bne $v0, $v1, laserCheck

lw $ra 4($sp)
addiu $sp, $sp, 8

jr $ra
	########################################################################
	#   Description:
	#       Example SPIM exception handler
	#       Derived from the default exception handler in the SPIM S20
	#       distribution.
	#
	#   History:
	#       Dec 2009    J Bacon
	
	########################################################################
	# Exception handling code.  This must go first!
	
			.kdata
	__start_msg_:   .asciiz "  Exception "
	__end_msg_:     .asciiz " occurred and ignored\n"
	
	# Messages for each of the 5-bit exception codes
	__exc0_msg:     .asciiz "  [Interrupt] "
	__exc1_msg:     .asciiz "  [TLB]"
	__exc2_msg:     .asciiz "  [TLB]"
	__exc3_msg:     .asciiz "  [TLB]"
	__exc4_msg:     .asciiz "  [Address error in inst/data fetch] "
	__exc5_msg:     .asciiz "  [Address error in store] "
	__exc6_msg:     .asciiz "  [Bad instruction address] "
	__exc7_msg:     .asciiz "  [Bad data address] "
	__exc8_msg:     .asciiz "  [Error in syscall] "
	__exc9_msg:     .asciiz "  [Breakpoint] "
	__exc10_msg:    .asciiz "  [Reserved instruction] "
	__exc11_msg:    .asciiz ""
	__exc12_msg:    .asciiz "  [Arithmetic overflow] "
	__exc13_msg:    .asciiz "  [Trap] "
	__exc14_msg:    .asciiz ""
	__exc15_msg:    .asciiz "  [Floating point] "
	__exc16_msg:    .asciiz ""
	__exc17_msg:    .asciiz ""
	__exc18_msg:    .asciiz "  [Coproc 2]"
	__exc19_msg:    .asciiz ""
	__exc20_msg:    .asciiz ""
	__exc21_msg:    .asciiz ""
	__exc22_msg:    .asciiz "  [MDMX]"
	__exc23_msg:    .asciiz "  [Watch]"
	__exc24_msg:    .asciiz "  [Machine check]"
	__exc25_msg:    .asciiz ""
	__exc26_msg:    .asciiz ""
	__exc27_msg:    .asciiz ""
	__exc28_msg:    .asciiz ""
	__exc29_msg:    .asciiz ""
	__exc30_msg:    .asciiz "  [Cache]"
	__exc31_msg:    .asciiz ""
	
	__level_msg:    .asciiz "Interrupt mask: "
	
	
	#########################################################################
	# Lookup table of exception messages
	__exc_msg_table:
		.word   __exc0_msg, __exc1_msg, __exc2_msg, __exc3_msg, __exc4_msg
		.word   __exc5_msg, __exc6_msg, __exc7_msg, __exc8_msg, __exc9_msg
		.word   __exc10_msg, __exc11_msg, __exc12_msg, __exc13_msg, __exc14_msg
		.word   __exc15_msg, __exc16_msg, __exc17_msg, __exc18_msg, __exc19_msg
		.word   __exc20_msg, __exc21_msg, __exc22_msg, __exc23_msg, __exc24_msg
		.word   __exc25_msg, __exc26_msg, __exc27_msg, __exc28_msg, __exc29_msg
		.word   __exc30_msg, __exc31_msg
	
	# Variables for save/restore of registers used in the handler
	save_v0:    .word   0
	save_a0:    .word   0
	save_at:    .word   0
	save_t0:    .word   0
	save_t1:    .word   0
	save_t2:    .word   0
	save_t3:    .word   0
	save_t4:    .word   0
	
	
	#########################################################################
	# This is the exception handler code that the processor runs when
	# an exception occurs. It only prints some information about the
	# exception, but can serve as a model of how to write a handler.
	#
	# Because this code is part of the kernel, it can use $k0 and $k1 without
	# saving and restoring their values.  By convention, they are treated
	# as temporary registers for kernel use.
	#
	# On the MIPS-1 (R2000), the exception handler must be at 0x80000080
	# This address is loaded into the program counter whenever an exception
	# occurs.  For the MIPS32, the address is 0x80000180.
	# Select the appropriate one for the mode in which SPIM is compiled.
	
		.ktext  0x80000180
	
		# Save ALL registers modified in this handler, except $k0 and $k1
		# This includes $t* since the user code does not explicitly
		# call this handler.  $sp cannot be trusted, so saving them to
		# the stack is not an option.  This routine is not reentrant (can't
		# be called again while it is running), so we can save registers
		# to static variables.
		sw      $v0, save_v0
		sw      $a0, save_a0
		sw	$t0, save_t0
		sw	$t1, save_t1
		sw	$t2, save_t2
		sw	$t3, save_t3
		sw	$t4, save_t4
	
		# $at is the temporary register reserved for the assembler.
		# It may be modified by pseudo-instructions in this handler.
		# Since an interrupt could have occurred during a pseudo
		# instruction in user code, $at must be restored to ensure
		# that that pseudo instruction completes correctly.
		.set    noat
		sw      $at, save_at
		.set    at
	
		# Determine cause of the exception
		mfc0    $k0, $13        # Get cause register from coprocessor 0
		srl     $a0, $k0, 2     # Extract exception code field (bits 2-6)
		andi    $a0, $a0, 0x1f
		
		# Check for program counter issues (exception 6)
		bne     $a0, 6, ok_pc
		nop
	
		mfc0    $a0, $14        # EPC holds PC at moment exception occurred
		andi    $a0, $a0, 0x3   # Is EPC word-aligned (multiple of 4)?
		beqz    $a0, ok_pc
		nop
	
		# Bail out if PC is unaligned
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4
		la      $a0, __exc3_msg
		syscall
		li      $v0, 10
		syscall
	
	ok_pc:
		mfc0    $k0, $13
		srl     $a0, $k0, 2     # Extract exception code from $k0 again
		andi    $a0, $a0, 0x1f
		bnez    $a0, non_interrupt  # Code 0 means exception was an interrupt
		nop
	
		# External interrupt handler
		# Don't skip instruction at EPC since it has not executed.
		# Interrupts occur BEFORE the instruction at PC executes.
		# Other exceptions occur during the execution of the instruction,
		# hence for those increment the return address to avoid
		# re-executing the instruction that caused the exception.
	
	     # check if we are in here because of a character on the keyboard simulator
		 # go to nochar if some other interrupt happened
		 
		lui $t0, 0xffff
		lw $t1, 0($t0)
		and $t2, $t1, 1
		
		beq $t2, $0, nochar
		 
		 # get the character from memory
		 # store it to a queue somewhere to be dealt with later by normal code
		 
		 
		lui $t0, 0xffff
		la $t1, queue
		lw $t2, 4($t0)
		la $t3, queue_point
		lw $t4, 0($t3)
		add $t1, $t1, $t4
		sw $t2, 0($t1)
		#sw $t2, queue_point($t1)
		
		la $t0, queue_point
		lw $t1, 0($t0)
		addiu $t1, $t1, 4
		sw $t1, queue_point

		j	return
	
nochar:
		# not a character
		# Print interrupt level
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __level_msg
		syscall
		
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Cause register
		srl     $a0, $k0, 11    # Right-justify interrupt level bits
		syscall
		
		li      $v0, 11         # print_char
		li      $a0, 10         # Line feed
		syscall
		
		j       return
	
	non_interrupt:
		# Print information about exception.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __start_msg_
		syscall
	
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Extract exception code again
		srl     $a0, $k0, 2
		andi    $a0, $a0, 0x1f
		syscall
	
		# Print message corresponding to exception code
		# Exception code is already shifted 2 bits from the far right
		# of the cause register, so it conveniently extracts out as
		# a multiple of 4, which is perfect for an array of 4-byte
		# string addresses.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		mfc0    $k0, $13        # Extract exception code without shifting
		andi    $a0, $k0, 0x7c
		lw      $a0, __exc_msg_table($a0)
		nop
		syscall
	
		li      $v0, 4          # print_str
		la      $a0, __end_msg_
		syscall
	
		# Return from (non-interrupt) exception. Skip offending instruction
		# at EPC to avoid infinite loop.
		mfc0    $k0, $14
		addiu   $k0, $k0, 4
		mtc0    $k0, $14
	
	return:
		# Restore registers and reset processor state
		lw      $v0, save_v0    # Restore other registers
		lw      $a0, save_a0
		lw	$t0, save_t0
		lw	$t1, save_t1
		lw	$t2, save_t2
		lw	$t3, save_t3
		lw	$t4, save_t4
	
		.set    noat            # Prevent assembler from modifying $at
		lw      $at, save_at
		.set    at
	
		mtc0    $zero, $13      # Clear Cause register
	
		# Re-enable interrupts, which were automatically disabled
		# when the exception occurred, using read-modify-write cycle.
		mfc0    $k0, $12        # Read status register
		#andi    $k0, 0xfffd     # Clear exception level bit
		ori     $k0, 0x0001     # Set interrupt enable bit
		mtc0    $k0, $12        # Write back
	
		# Return from exception on MIPS32:
		eret
	
	
	#########################################################################
	# Standard startup code.  Invoke the routine "main" with arguments:
	# main(argc, argv, envp)
	
		.text
		.globl __start
	__start:
		lw      $a0, 0($sp)     # argc = *$sp
		addiu   $a1, $sp, 4     # argv = $sp + 4
		addiu   $a2, $sp, 8     # envp = $sp + 8
		sll     $v0, $a0, 2     # envp += size of argv array
		addu    $a2, $a2, $v0
		jal     Main
		nop
	
		li      $v0, 10         # exit
		syscall
	
		.globl __eoth
	__eoth:
	
