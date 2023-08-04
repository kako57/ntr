# Bitmap Display Configuration
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:  512
# - Display height in pixels: 512
# - Base address for display: 0x10040000 ($heap)
.eqv BASE_ADDRESS 0x10040000
.eqv RED   0x00ed1c24
.eqv GREEN 0x00b5e61d
.eqv BLUE  0x003f48cc
.eqv BLACK  0x00000000
.eqv PLATFORM 0x00b97a57
.eqv WIDTH  64
.eqv HEIGHT 64

.data

player_pos: .word 16, 16
jumping: .word 0
game_running: .word 1

.globl main
.text

main:
        # idk if this is necessary
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        jal draw_map
        jal draw_player

loop:
        jal keypress_event_handler

        la $t2, game_running
        lw $t1, 0($t2)
        beq $t1, 0, after_vertical_movement

        la $t0, jumping
        lw $t0, 0($t0)
        bne, $t0, 0, gufr

gdfr:
        jal gravity
        j after_vertical_movement
gufr:
        jal go_up_for_real
        j after_vertical_movement

after_vertical_movement:
        # sleep for 150 ms
        li $v0, 32
        li $a0, 150
        syscall
        
        j loop

exit:
        li $v0, 10
        syscall


calculate_address:
        mul $t0, $a0, WIDTH # a0 is row (y)
        add $t0, $t0, $a1   # a1 is col (x)
        mul $t0, $t0, 4
        la $t1, BASE_ADDRESS
        add $t0, $t0, $t1
        move $v0, $t0
        jr $ra

get_color:
        mul $t0, $a0, WIDTH # a0 is row (y)
        add $t0, $t0, $a1   # a1 is col (x)
        mul $t0, $t0, 4
        la $t1, BASE_ADDRESS
        add $t0, $t0, $t1
        lw $v0, 0($t0)
        jr $ra

set_color:
        mul $t0, $a0, WIDTH # a0 is row (y)
        add $t0, $t0, $a1   # a1 is col (x)
        mul $t0, $t0, 4
        la $t1, BASE_ADDRESS
        add $t0, $t0, $t1
        sw $a2, 0($t0)
        jr $ra

keypress_event_handler:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        li $t9, 0xffff0000
        lw $t8, 0($t9)
        beq $t8, 1, keypress_happened
        j keypress_event_handler_end

keypress_happened:
        lw $t2, 4($t9)

        # debug: print the key pressed
        li $v0, 1
        move $a0, $t2
        syscall

        lw $t2, 4($t9)
        
        beq $t2, 0x70, goto_reset

        # check if game is running
        la $t3, game_running
        lw $t4, 0($t3)
        beq $t4, 0, keypress_event_handler_end

        beq $t2, 0x61, left_key_pressed
        beq $t2, 0x64, right_key_pressed
        beq $t2, 0x77, up_key_pressed
        beq $t2, 0x73, down_key_pressed
        j keypress_event_handler_end

goto_reset:
        jal reset
        li $v0, 0
        j keypress_event_handler_end

left_key_pressed:
        jal check_collision_left

        bne $v0, 0, keypress_event_handler_end

        jal undraw_player

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        sub $t1, $t1, 1 # -1 pixel for the object on the left
        sw $t1, 0($t2)

        jal draw_player

        li $v0, 0

        j keypress_event_handler_end

right_key_pressed:
        jal check_collision_right

        bne $v0, 0, keypress_event_handler_end

        jal undraw_player

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        addi $t1, $t1, 1 # +1 pixel for the object on the right
        sw $t1, 0($t2)

        jal draw_player
        
        li $v0, 0

        j keypress_event_handler_end

up_key_pressed:
        la $t2, jumping
        li $t1, 8
        sw $t1, 0($t2) # 8 frames of jumping
        
        li $v0, 0

        j keypress_event_handler_end

down_key_pressed:
        # jal check_collision_up
        # jal move_right
        # j keypress_event_handler_end
        
        li $v0, 0

keypress_event_handler_end:
        # check if we collided to a lose or a win condition
        beq $v0, RED, ngee
        beq $v0, GREEN, sheesh

        j after_checks

ngee:
        la $t2, game_running
        sw $zero, 0($t2)
        
        jal draw_ntr
        j after_checks

sheesh:
        la $t2, game_running
        sw $zero, 0($t2)

        jal draw_nice
        j after_checks

after_checks:

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        # reset the keypress
        # sw $zero, 0($t9)

        jr $ra


check_collision_left:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        sub $t1, $t1, 1 # -1 pixel for the object on the left (potentially)

        addi $sp, $sp, -12
        sw $t0, 0($sp)
        sw $t1, 4($sp)

        li $t2, 4 # check the 4 pixels below the player
        sw $t2, 8($sp)

        blt $t1, 0, check_collision_left_oob

check_collision_left_loop:
        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        beq $t2, 0, check_collision_left_end

        move $a0, $t0 # row
        move $a1, $t1 # col
        jal get_color

        bne $v0, BLACK, check_collision_left_end

        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        addi $t0, $t0, 1 # check the next pixel
        sw $t0, 0($sp)

        sub $t2, $t2, 1 # decrement counter
        sw $t2, 8($sp)

        j check_collision_left_loop

check_collision_left_end:
        # $v0 is the color of the pixel below the player
        # if it is not black, then there is a collision

        addi $sp, $sp, 12

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

check_collision_left_oob:
        li $v0, PLATFORM
        j check_collision_left_end


check_collision_right:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        addi $t1, $t1, 4 # -1 pixel for the object on the right (potentially)

        addi $sp, $sp, -12
        sw $t0, 0($sp)
        sw $t1, 4($sp)

        li $t2, 4 # check the 4 pixels on right of the player
        sw $t2, 8($sp)

        bge $t1, WIDTH, check_collision_right_oob

check_collision_right_loop:
        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        beq $t2, 0, check_collision_right_end

        move $a0, $t0 # row
        move $a1, $t1 # col
        jal get_color

        bne $v0, BLACK, check_collision_right_end

        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        addi $t0, $t0, 1 # check the next pixel
        sw $t0, 0($sp)

        sub $t2, $t2, 1 # decrement counter
        sw $t2, 8($sp)

        j check_collision_right_loop

check_collision_right_end:
        # $v0 is the color of the pixel below the player
        # if it is not black, then there is a collision

        addi $sp, $sp, 12

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

check_collision_right_oob:
        li $v0, PLATFORM
        j check_collision_right_end


check_collision_up:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        addi $t0, $t0, -1 # -1 pixel for the object above (potentially)

        addi $sp, $sp, -12
        sw $t0, 0($sp)
        sw $t1, 4($sp)

        li $t2, 4 # check the 4 pixels below the player
        sw $t2, 8($sp)

check_collision_up_loop:
        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        beq $t2, 0, check_collision_up_end

        move $a0, $t0 # row
        move $a1, $t1 # col
        jal get_color

        bne $v0, BLACK, check_collision_up_end

        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        addi $t1, $t1, 1 # check the next pixel
        sw $t1, 4($sp)

        sub $t2, $t2, 1 # decrement counter
        sw $t2, 8($sp)

        j check_collision_up_loop

check_collision_up_end:
        # $v0 is the color of the pixel below the player
        # if it is not black, then there is a collision

        addi $sp, $sp, 12

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

check_collision_down:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        addi $t0, $t0, 4 # player is 4 pixels tall

        addi $sp, $sp, -12
        sw $t0, 0($sp)
        sw $t1, 4($sp)

        li $t2, 4 # check the 4 pixels below the player
        sw $t2, 8($sp)

check_collision_down_loop:
        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        beq $t2, 0, check_collision_down_end

        move $a0, $t0 # row
        move $a1, $t1 # col
        jal get_color

        bne $v0, BLACK, check_collision_down_end

        lw $t0, 0($sp) # player.y
        lw $t1, 4($sp) # player.x
        lw $t2, 8($sp) # counter

        addi $t1, $t1, 1 # check the next pixel
        sw $t1, 4($sp)

        sub $t2, $t2, 1 # decrement counter
        sw $t2, 8($sp)

        j check_collision_down_loop

check_collision_down_end:
        # $v0 is the color of the pixel below the player
        # if it is not black, then there is a collision

        addi $sp, $sp, 12

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra
        
go_up_for_real:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        jal check_collision_up
        bne $v0, BLACK, go_up_for_real_end

        jal undraw_player

        # bring up player y position
        la $t4, player_pos
        lw $t5, 4($t4)
        sub $t5, $t5, 1
        sw $t5, 4($t4)

        jal draw_player

go_up_for_real_end:
        beq $v0, RED, ngee
        beq $v0, GREEN, sheesh

        la $t2, jumping
        lw $t1, 0($t2)
        sub $t1, $t1, 1
        sw $t1, 0($t2)

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

gravity:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        jal check_collision_down
        bne $v0, BLACK, gravity_end
        
        jal undraw_player

        # lower player y position
        la $t4, player_pos
        lw $t5, 4($t4)
        addi $t5, $t5, 1
        sw $t5, 4($t4)

        jal draw_player

        li $v0, 0

gravity_end: # jump-oriented programming at its finest
        beq $v0, RED, ngee
        beq $v0, GREEN, sheesh

        j after_checks # jump to a pop ret gadget

undraw_player: # lmao
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        move $a0, $t0
        move $a1, $t1
        jal calculate_address

        move $t0, $v0
        li $t1, BLACK

        # draw the sprite
        sw $t1, 4($t0)
        sw $t1, 8($t0)
        sw $t1, 256($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 268($t0)
        sw $t1, 512($t0)
        sw $t1, 516($t0)
        sw $t1, 520($t0)
        sw $t1, 524($t0)
        sw $t1, 768($t0)
        sw $t1, 780($t0)

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

draw_player:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        la $t2, player_pos
        lw $t1, 0($t2) # player.x
        lw $t0, 4($t2) # player.y

        move $a0, $t0
        move $a1, $t1
        jal calculate_address

        move $t0, $v0
        li $t1, BLUE

        # draw the sprite
        sw $t1, 4($t0)
        sw $t1, 8($t0)
        sw $t1, 256($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 268($t0)
        sw $t1, 512($t0)
        sw $t1, 516($t0)
        sw $t1, 520($t0)
        sw $t1, 524($t0)
        sw $t1, 768($t0)
        sw $t1, 780($t0)

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

reset:
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        jal clear_screen

        # reset player position
        la $t0, player_pos
        li $t1, 16
        sw $t1, 0($t0)
        sw $t1, 4($t0)

        # reset jumping
        la $t0, jumping
        sw $zero, 0($t0)

        # reset game_running
        la $t0, game_running
        li $t1, 1
        sw $t1, 0($t0)

        jal draw_map
        jal draw_player

        lw $ra, 0($sp)
        addi $sp, $sp, 4

        jr $ra

clear_screen: # undraw the map (generated by img2asm.py)
        addi $sp, $sp, -4
        sw $ra, 0($sp)

	la $t0, BASE_ADDRESS
	li $t1, BLACK
        li $t2, 0x0000 # offset

clear_screen_loop:
        beq $t2, 0x4000, clear_screen_end

        move $t3, $t0
        add $t3, $t3, $t2

        sw $t1, 0($t3)

        addi $t2, $t2, 0x4
        j clear_screen_loop

clear_screen_end:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

draw_map: # draw the map (generated by img2asm.py)
	la $t0, BASE_ADDRESS
	li $t1, 12155479
	li $t2, 15539236
	li $t3, 11920925
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1, 24($t0)
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 40($t0)
	sw $t1, 44($t0)
	sw $t1, 48($t0)
	sw $t1, 52($t0)
	sw $t1, 56($t0)
	sw $t1, 60($t0)
	sw $t1, 64($t0)
	sw $t1, 68($t0)
	sw $t1, 72($t0)
	sw $t1, 76($t0)
	sw $t1, 80($t0)
	sw $t1, 84($t0)
	sw $t1, 88($t0)
	sw $t1, 92($t0)
	sw $t1, 96($t0)
	sw $t1, 100($t0)
	sw $t1, 104($t0)
	sw $t1, 108($t0)
	sw $t1, 112($t0)
	sw $t1, 116($t0)
	sw $t1, 120($t0)
	sw $t1, 124($t0)
	sw $t1, 128($t0)
	sw $t1, 132($t0)
	sw $t1, 136($t0)
	sw $t1, 140($t0)
	sw $t1, 144($t0)
	sw $t1, 148($t0)
	sw $t1, 152($t0)
	sw $t1, 156($t0)
	sw $t1, 160($t0)
	sw $t1, 164($t0)
	sw $t1, 168($t0)
	sw $t1, 172($t0)
	sw $t1, 176($t0)
	sw $t1, 180($t0)
	sw $t1, 184($t0)
	sw $t1, 188($t0)
	sw $t1, 192($t0)
	sw $t1, 196($t0)
	sw $t1, 200($t0)
	sw $t1, 204($t0)
	sw $t1, 208($t0)
	sw $t1, 212($t0)
	sw $t1, 216($t0)
	sw $t1, 220($t0)
	sw $t1, 224($t0)
	sw $t1, 228($t0)
	sw $t1, 232($t0)
	sw $t1, 236($t0)
	sw $t1, 240($t0)
	sw $t1, 244($t0)
	sw $t1, 248($t0)
	sw $t1, 252($t0)
	sw $t1, 256($t0)
	sw $t1, 260($t0)
	sw $t1, 264($t0)
	sw $t1, 268($t0)
	sw $t1, 272($t0)
	sw $t1, 276($t0)
	sw $t1, 280($t0)
	sw $t1, 284($t0)
	sw $t1, 288($t0)
	sw $t1, 292($t0)
	sw $t1, 296($t0)
	sw $t1, 300($t0)
	sw $t1, 304($t0)
	sw $t1, 308($t0)
	sw $t1, 312($t0)
	sw $t1, 316($t0)
	sw $t1, 320($t0)
	sw $t1, 324($t0)
	sw $t1, 328($t0)
	sw $t1, 332($t0)
	sw $t1, 336($t0)
	sw $t1, 340($t0)
	sw $t1, 344($t0)
	sw $t1, 348($t0)
	sw $t1, 352($t0)
	sw $t1, 356($t0)
	sw $t1, 360($t0)
	sw $t1, 364($t0)
	sw $t1, 368($t0)
	sw $t1, 372($t0)
	sw $t1, 376($t0)
	sw $t1, 380($t0)
	sw $t1, 384($t0)
	sw $t1, 388($t0)
	sw $t1, 392($t0)
	sw $t1, 396($t0)
	sw $t1, 400($t0)
	sw $t1, 404($t0)
	sw $t1, 408($t0)
	sw $t1, 412($t0)
	sw $t1, 416($t0)
	sw $t1, 420($t0)
	sw $t1, 424($t0)
	sw $t1, 428($t0)
	sw $t1, 432($t0)
	sw $t1, 436($t0)
	sw $t1, 440($t0)
	sw $t1, 444($t0)
	sw $t1, 448($t0)
	sw $t1, 452($t0)
	sw $t1, 456($t0)
	sw $t1, 460($t0)
	sw $t1, 464($t0)
	sw $t1, 468($t0)
	sw $t1, 472($t0)
	sw $t1, 476($t0)
	sw $t1, 480($t0)
	sw $t1, 484($t0)
	sw $t1, 488($t0)
	sw $t1, 492($t0)
	sw $t1, 496($t0)
	sw $t1, 500($t0)
	sw $t1, 504($t0)
	sw $t1, 508($t0)
	sw $t1, 512($t0)
	sw $t1, 516($t0)
	sw $t1, 520($t0)
	sw $t1, 524($t0)
	sw $t1, 528($t0)
	sw $t1, 532($t0)
	sw $t1, 536($t0)
	sw $t1, 540($t0)
	sw $t1, 544($t0)
	sw $t1, 548($t0)
	sw $t1, 552($t0)
	sw $t1, 556($t0)
	sw $t1, 560($t0)
	sw $t1, 564($t0)
	sw $t1, 568($t0)
	sw $t1, 572($t0)
	sw $t1, 576($t0)
	sw $t1, 580($t0)
	sw $t1, 584($t0)
	sw $t1, 588($t0)
	sw $t1, 592($t0)
	sw $t1, 596($t0)
	sw $t1, 600($t0)
	sw $t1, 604($t0)
	sw $t1, 608($t0)
	sw $t1, 612($t0)
	sw $t1, 616($t0)
	sw $t1, 620($t0)
	sw $t1, 624($t0)
	sw $t1, 628($t0)
	sw $t1, 632($t0)
	sw $t1, 636($t0)
	sw $t1, 640($t0)
	sw $t1, 644($t0)
	sw $t1, 648($t0)
	sw $t1, 652($t0)
	sw $t1, 656($t0)
	sw $t1, 660($t0)
	sw $t1, 664($t0)
	sw $t1, 668($t0)
	sw $t1, 672($t0)
	sw $t1, 676($t0)
	sw $t1, 680($t0)
	sw $t1, 684($t0)
	sw $t1, 688($t0)
	sw $t1, 692($t0)
	sw $t1, 696($t0)
	sw $t1, 700($t0)
	sw $t1, 704($t0)
	sw $t1, 708($t0)
	sw $t1, 712($t0)
	sw $t1, 716($t0)
	sw $t1, 720($t0)
	sw $t1, 724($t0)
	sw $t1, 728($t0)
	sw $t1, 732($t0)
	sw $t1, 736($t0)
	sw $t1, 740($t0)
	sw $t1, 744($t0)
	sw $t1, 748($t0)
	sw $t1, 752($t0)
	sw $t1, 756($t0)
	sw $t1, 760($t0)
	sw $t1, 764($t0)
	sw $t1, 768($t0)
	sw $t1, 772($t0)
	sw $t1, 776($t0)
	sw $t1, 780($t0)
	sw $t1, 784($t0)
	sw $t1, 788($t0)
	sw $t1, 792($t0)
	sw $t1, 796($t0)
	sw $t1, 800($t0)
	sw $t1, 804($t0)
	sw $t1, 808($t0)
	sw $t1, 812($t0)
	sw $t1, 816($t0)
	sw $t1, 820($t0)
	sw $t1, 824($t0)
	sw $t1, 828($t0)
	sw $t1, 832($t0)
	sw $t1, 836($t0)
	sw $t1, 840($t0)
	sw $t1, 844($t0)
	sw $t1, 848($t0)
	sw $t1, 852($t0)
	sw $t1, 856($t0)
	sw $t1, 860($t0)
	sw $t1, 864($t0)
	sw $t1, 868($t0)
	sw $t1, 872($t0)
	sw $t1, 876($t0)
	sw $t1, 880($t0)
	sw $t1, 884($t0)
	sw $t1, 888($t0)
	sw $t1, 892($t0)
	sw $t1, 896($t0)
	sw $t1, 900($t0)
	sw $t1, 904($t0)
	sw $t1, 908($t0)
	sw $t1, 912($t0)
	sw $t1, 916($t0)
	sw $t1, 920($t0)
	sw $t1, 924($t0)
	sw $t1, 928($t0)
	sw $t1, 932($t0)
	sw $t1, 936($t0)
	sw $t1, 940($t0)
	sw $t1, 944($t0)
	sw $t1, 948($t0)
	sw $t1, 952($t0)
	sw $t1, 956($t0)
	sw $t1, 960($t0)
	sw $t1, 964($t0)
	sw $t1, 968($t0)
	sw $t1, 972($t0)
	sw $t1, 976($t0)
	sw $t1, 980($t0)
	sw $t1, 984($t0)
	sw $t1, 988($t0)
	sw $t1, 992($t0)
	sw $t1, 996($t0)
	sw $t1, 1000($t0)
	sw $t1, 1004($t0)
	sw $t1, 1008($t0)
	sw $t1, 1012($t0)
	sw $t1, 1016($t0)
	sw $t1, 1020($t0)
	sw $t1, 10304($t0)
	sw $t1, 10308($t0)
	sw $t1, 10312($t0)
	sw $t1, 10316($t0)
	sw $t1, 10320($t0)
	sw $t1, 10324($t0)
	sw $t1, 10328($t0)
	sw $t1, 10332($t0)
	sw $t1, 10560($t0)
	sw $t1, 10564($t0)
	sw $t1, 10568($t0)
	sw $t1, 10572($t0)
	sw $t1, 10576($t0)
	sw $t1, 10580($t0)
	sw $t1, 10584($t0)
	sw $t1, 10588($t0)
	sw $t1, 10816($t0)
	sw $t1, 10820($t0)
	sw $t1, 10824($t0)
	sw $t1, 10828($t0)
	sw $t1, 10832($t0)
	sw $t1, 10836($t0)
	sw $t1, 10840($t0)
	sw $t1, 10844($t0)
	sw $t1, 11072($t0)
	sw $t1, 11076($t0)
	sw $t1, 11080($t0)
	sw $t1, 11084($t0)
	sw $t1, 11088($t0)
	sw $t1, 11092($t0)
	sw $t1, 11096($t0)
	sw $t1, 11100($t0)
	sw $t1, 11392($t0)
	sw $t1, 11396($t0)
	sw $t1, 11400($t0)
	sw $t1, 11404($t0)
	sw $t1, 11408($t0)
	sw $t1, 11412($t0)
	sw $t1, 11416($t0)
	sw $t1, 11420($t0)
	sw $t1, 11648($t0)
	sw $t1, 11652($t0)
	sw $t1, 11656($t0)
	sw $t1, 11660($t0)
	sw $t1, 11664($t0)
	sw $t1, 11668($t0)
	sw $t1, 11672($t0)
	sw $t1, 11676($t0)
	sw $t1, 11904($t0)
	sw $t1, 11908($t0)
	sw $t1, 11912($t0)
	sw $t1, 11916($t0)
	sw $t1, 11920($t0)
	sw $t1, 11924($t0)
	sw $t1, 11928($t0)
	sw $t1, 11932($t0)
	sw $t1, 12160($t0)
	sw $t1, 12164($t0)
	sw $t1, 12168($t0)
	sw $t1, 12172($t0)
	sw $t1, 12176($t0)
	sw $t1, 12180($t0)
	sw $t1, 12184($t0)
	sw $t1, 12188($t0)
	sw $t1, 13408($t0)
	sw $t1, 13412($t0)
	sw $t1, 13416($t0)
	sw $t1, 13420($t0)
	sw $t1, 13424($t0)
	sw $t1, 13428($t0)
	sw $t1, 13432($t0)
	sw $t1, 13436($t0)
	sw $t1, 13664($t0)
	sw $t1, 13668($t0)
	sw $t1, 13672($t0)
	sw $t1, 13676($t0)
	sw $t1, 13680($t0)
	sw $t1, 13684($t0)
	sw $t1, 13688($t0)
	sw $t1, 13692($t0)
	sw $t1, 13920($t0)
	sw $t1, 13924($t0)
	sw $t1, 13928($t0)
	sw $t1, 13932($t0)
	sw $t1, 13936($t0)
	sw $t1, 13940($t0)
	sw $t1, 13944($t0)
	sw $t1, 13948($t0)
	sw $t1, 14176($t0)
	sw $t1, 14180($t0)
	sw $t1, 14184($t0)
	sw $t1, 14188($t0)
	sw $t1, 14192($t0)
	sw $t1, 14196($t0)
	sw $t1, 14200($t0)
	sw $t1, 14204($t0)
	sw $t1, 15360($t0)
	sw $t1, 15364($t0)
	sw $t1, 15368($t0)
	sw $t1, 15372($t0)
	sw $t1, 15376($t0)
	sw $t1, 15380($t0)
	sw $t1, 15384($t0)
	sw $t1, 15388($t0)
	sw $t1, 15392($t0)
	sw $t1, 15396($t0)
	sw $t1, 15400($t0)
	sw $t1, 15404($t0)
	sw $t1, 15408($t0)
	sw $t1, 15412($t0)
	sw $t1, 15416($t0)
	sw $t1, 15420($t0)
	sw $t1, 15424($t0)
	sw $t1, 15428($t0)
	sw $t1, 15432($t0)
	sw $t1, 15436($t0)
	sw $t1, 15440($t0)
	sw $t1, 15444($t0)
	sw $t1, 15448($t0)
	sw $t1, 15452($t0)
	sw $t1, 15456($t0)
	sw $t1, 15460($t0)
	sw $t1, 15464($t0)
	sw $t1, 15468($t0)
	sw $t1, 15472($t0)
	sw $t1, 15476($t0)
	sw $t1, 15480($t0)
	sw $t1, 15484($t0)
	sw $t1, 15488($t0)
	sw $t1, 15492($t0)
	sw $t1, 15496($t0)
	sw $t1, 15500($t0)
	sw $t1, 15504($t0)
	sw $t1, 15508($t0)
	sw $t1, 15512($t0)
	sw $t1, 15516($t0)
	sw $t1, 15520($t0)
	sw $t1, 15524($t0)
	sw $t1, 15528($t0)
	sw $t1, 15532($t0)
	sw $t1, 15536($t0)
	sw $t1, 15540($t0)
	sw $t1, 15544($t0)
	sw $t1, 15548($t0)
	sw $t1, 15552($t0)
	sw $t1, 15556($t0)
	sw $t1, 15560($t0)
	sw $t1, 15564($t0)
	sw $t1, 15568($t0)
	sw $t1, 15572($t0)
	sw $t1, 15576($t0)
	sw $t1, 15580($t0)
	sw $t1, 15584($t0)
	sw $t1, 15588($t0)
	sw $t1, 15592($t0)
	sw $t1, 15596($t0)
	sw $t1, 15600($t0)
	sw $t1, 15604($t0)
	sw $t1, 15608($t0)
	sw $t1, 15612($t0)
	sw $t1, 15616($t0)
	sw $t1, 15620($t0)
	sw $t1, 15624($t0)
	sw $t1, 15628($t0)
	sw $t1, 15632($t0)
	sw $t1, 15636($t0)
	sw $t1, 15640($t0)
	sw $t1, 15644($t0)
	sw $t1, 15648($t0)
	sw $t1, 15652($t0)
	sw $t1, 15656($t0)
	sw $t1, 15660($t0)
	sw $t1, 15664($t0)
	sw $t1, 15668($t0)
	sw $t1, 15672($t0)
	sw $t1, 15676($t0)
	sw $t1, 15680($t0)
	sw $t1, 15684($t0)
	sw $t1, 15688($t0)
	sw $t1, 15692($t0)
	sw $t1, 15696($t0)
	sw $t1, 15700($t0)
	sw $t1, 15704($t0)
	sw $t1, 15708($t0)
	sw $t1, 15712($t0)
	sw $t1, 15716($t0)
	sw $t1, 15720($t0)
	sw $t1, 15724($t0)
	sw $t1, 15728($t0)
	sw $t1, 15732($t0)
	sw $t1, 15736($t0)
	sw $t1, 15740($t0)
	sw $t1, 15744($t0)
	sw $t1, 15748($t0)
	sw $t1, 15752($t0)
	sw $t1, 15756($t0)
	sw $t1, 15760($t0)
	sw $t1, 15764($t0)
	sw $t1, 15768($t0)
	sw $t1, 15772($t0)
	sw $t1, 15776($t0)
	sw $t1, 15780($t0)
	sw $t1, 15784($t0)
	sw $t1, 15788($t0)
	sw $t1, 15792($t0)
	sw $t1, 15796($t0)
	sw $t1, 15800($t0)
	sw $t1, 15804($t0)
	sw $t1, 15808($t0)
	sw $t1, 15812($t0)
	sw $t1, 15816($t0)
	sw $t1, 15820($t0)
	sw $t1, 15824($t0)
	sw $t1, 15828($t0)
	sw $t1, 15832($t0)
	sw $t1, 15836($t0)
	sw $t1, 15840($t0)
	sw $t1, 15844($t0)
	sw $t1, 15848($t0)
	sw $t1, 15852($t0)
	sw $t1, 15856($t0)
	sw $t1, 15860($t0)
	sw $t1, 15864($t0)
	sw $t1, 15868($t0)
	sw $t1, 15872($t0)
	sw $t1, 15876($t0)
	sw $t1, 15880($t0)
	sw $t1, 15884($t0)
	sw $t1, 15888($t0)
	sw $t1, 15892($t0)
	sw $t1, 15896($t0)
	sw $t1, 15900($t0)
	sw $t1, 15904($t0)
	sw $t1, 15908($t0)
	sw $t1, 15912($t0)
	sw $t1, 15916($t0)
	sw $t1, 15920($t0)
	sw $t1, 15924($t0)
	sw $t1, 15928($t0)
	sw $t1, 15932($t0)
	sw $t1, 15936($t0)
	sw $t1, 15940($t0)
	sw $t1, 15944($t0)
	sw $t1, 15948($t0)
	sw $t1, 15952($t0)
	sw $t1, 15956($t0)
	sw $t1, 15960($t0)
	sw $t1, 15964($t0)
	sw $t1, 15968($t0)
	sw $t1, 15972($t0)
	sw $t1, 15976($t0)
	sw $t1, 15980($t0)
	sw $t1, 15984($t0)
	sw $t1, 15988($t0)
	sw $t1, 15992($t0)
	sw $t1, 15996($t0)
	sw $t1, 16000($t0)
	sw $t1, 16004($t0)
	sw $t1, 16008($t0)
	sw $t1, 16012($t0)
	sw $t1, 16016($t0)
	sw $t1, 16020($t0)
	sw $t1, 16024($t0)
	sw $t1, 16028($t0)
	sw $t1, 16032($t0)
	sw $t1, 16036($t0)
	sw $t1, 16040($t0)
	sw $t1, 16044($t0)
	sw $t1, 16048($t0)
	sw $t1, 16052($t0)
	sw $t1, 16056($t0)
	sw $t1, 16060($t0)
	sw $t1, 16064($t0)
	sw $t1, 16068($t0)
	sw $t1, 16072($t0)
	sw $t1, 16076($t0)
	sw $t1, 16080($t0)
	sw $t1, 16084($t0)
	sw $t1, 16088($t0)
	sw $t1, 16092($t0)
	sw $t1, 16096($t0)
	sw $t1, 16100($t0)
	sw $t1, 16104($t0)
	sw $t1, 16108($t0)
	sw $t1, 16112($t0)
	sw $t1, 16116($t0)
	sw $t1, 16120($t0)
	sw $t1, 16124($t0)
	sw $t1, 16128($t0)
	sw $t1, 16132($t0)
	sw $t1, 16136($t0)
	sw $t1, 16140($t0)
	sw $t1, 16144($t0)
	sw $t1, 16148($t0)
	sw $t1, 16152($t0)
	sw $t1, 16156($t0)
	sw $t1, 16160($t0)
	sw $t1, 16164($t0)
	sw $t1, 16168($t0)
	sw $t1, 16172($t0)
	sw $t1, 16176($t0)
	sw $t1, 16180($t0)
	sw $t1, 16184($t0)
	sw $t1, 16188($t0)
	sw $t1, 16192($t0)
	sw $t1, 16196($t0)
	sw $t1, 16200($t0)
	sw $t1, 16204($t0)
	sw $t1, 16208($t0)
	sw $t1, 16212($t0)
	sw $t1, 16216($t0)
	sw $t1, 16220($t0)
	sw $t1, 16224($t0)
	sw $t1, 16228($t0)
	sw $t1, 16232($t0)
	sw $t1, 16236($t0)
	sw $t1, 16240($t0)
	sw $t1, 16244($t0)
	sw $t1, 16248($t0)
	sw $t1, 16252($t0)
	sw $t1, 16256($t0)
	sw $t1, 16260($t0)
	sw $t1, 16264($t0)
	sw $t1, 16268($t0)
	sw $t1, 16272($t0)
	sw $t1, 16276($t0)
	sw $t1, 16280($t0)
	sw $t1, 16284($t0)
	sw $t1, 16288($t0)
	sw $t1, 16292($t0)
	sw $t1, 16296($t0)
	sw $t1, 16300($t0)
	sw $t1, 16304($t0)
	sw $t1, 16308($t0)
	sw $t1, 16312($t0)
	sw $t1, 16316($t0)
	sw $t1, 16320($t0)
	sw $t1, 16324($t0)
	sw $t1, 16328($t0)
	sw $t1, 16332($t0)
	sw $t1, 16336($t0)
	sw $t1, 16340($t0)
	sw $t1, 16344($t0)
	sw $t1, 16348($t0)
	sw $t1, 16352($t0)
	sw $t1, 16356($t0)
	sw $t1, 16360($t0)
	sw $t1, 16364($t0)
	sw $t1, 16368($t0)
	sw $t1, 16372($t0)
	sw $t1, 16376($t0)
	sw $t1, 16380($t0)
	sw $t2, 14468($t0)
	sw $t2, 14472($t0)
	sw $t2, 14724($t0)
	sw $t2, 14728($t0)
	sw $t2, 14980($t0)
	sw $t2, 14984($t0)
	sw $t2, 15232($t0)
	sw $t2, 15236($t0)
	sw $t2, 15240($t0)
	sw $t2, 15244($t0)
	sw $t3, 14480($t0)
	sw $t3, 14484($t0)
	sw $t3, 14488($t0)
	sw $t3, 14492($t0)
	sw $t3, 14740($t0)
	sw $t3, 14744($t0)
	sw $t3, 14996($t0)
	sw $t3, 15000($t0)
	sw $t3, 15252($t0)
	sw $t3, 15256($t0)
	jr $ra

draw_nice: # (also generated by img2asm.py)
	la $t0, BASE_ADDRESS
	li $t1, 6731519
	li $t2, 16777215
	li $t3, 16758374
	li $t4, 3838171
	li $t5, 16758416
	li $t6, 9493503
	li $t7, 16777142
	li $t8, 6684672
	li $t9, 14992
	sw $t1, 6496($t0)
	sw $t1, 6752($t0)
	sw $t1, 7264($t0)
	sw $t1, 7520($t0)
	sw $t1, 7760($t0)
	sw $t1, 7776($t0)
	sw $t1, 7840($t0)
	sw $t1, 8016($t0)
	sw $t1, 8032($t0)
	sw $t1, 8272($t0)
	sw $t1, 8288($t0)
	sw $t1, 8528($t0)
	sw $t1, 8544($t0)
	sw $t1, 8784($t0)
	sw $t1, 8800($t0)
	sw $t1, 9040($t0)
	sw $t1, 9056($t0)
	sw $t1, 9296($t0)
	sw $t1, 9312($t0)
	sw $t1, 9552($t0)
	sw $t1, 9568($t0)
	sw $t2, 6500($t0)
	sw $t2, 6504($t0)
	sw $t2, 6756($t0)
	sw $t2, 6760($t0)
	sw $t2, 7236($t0)
	sw $t2, 7240($t0)
	sw $t2, 7252($t0)
	sw $t2, 7268($t0)
	sw $t2, 7272($t0)
	sw $t2, 7292($t0)
	sw $t2, 7296($t0)
	sw $t2, 7324($t0)
	sw $t2, 7328($t0)
	sw $t2, 7492($t0)
	sw $t2, 7496($t0)
	sw $t2, 7500($t0)
	sw $t2, 7504($t0)
	sw $t2, 7508($t0)
	sw $t2, 7512($t0)
	sw $t2, 7524($t0)
	sw $t2, 7528($t0)
	sw $t2, 7544($t0)
	sw $t2, 7548($t0)
	sw $t2, 7552($t0)
	sw $t2, 7556($t0)
	sw $t2, 7576($t0)
	sw $t2, 7580($t0)
	sw $t2, 7584($t0)
	sw $t2, 7588($t0)
	sw $t2, 7748($t0)
	sw $t2, 7752($t0)
	sw $t2, 7764($t0)
	sw $t2, 7768($t0)
	sw $t2, 7780($t0)
	sw $t2, 7784($t0)
	sw $t2, 7796($t0)
	sw $t2, 7800($t0)
	sw $t2, 7812($t0)
	sw $t2, 7816($t0)
	sw $t2, 7828($t0)
	sw $t2, 7832($t0)
	sw $t2, 7844($t0)
	sw $t2, 7848($t0)
	sw $t2, 8004($t0)
	sw $t2, 8008($t0)
	sw $t2, 8020($t0)
	sw $t2, 8024($t0)
	sw $t2, 8036($t0)
	sw $t2, 8040($t0)
	sw $t2, 8052($t0)
	sw $t2, 8056($t0)
	sw $t2, 8068($t0)
	sw $t2, 8072($t0)
	sw $t2, 8084($t0)
	sw $t2, 8088($t0)
	sw $t2, 8092($t0)
	sw $t2, 8096($t0)
	sw $t2, 8100($t0)
	sw $t2, 8104($t0)
	sw $t2, 8260($t0)
	sw $t2, 8264($t0)
	sw $t2, 8276($t0)
	sw $t2, 8280($t0)
	sw $t2, 8292($t0)
	sw $t2, 8296($t0)
	sw $t2, 8308($t0)
	sw $t2, 8312($t0)
	sw $t2, 8340($t0)
	sw $t2, 8344($t0)
	sw $t2, 8348($t0)
	sw $t2, 8352($t0)
	sw $t2, 8356($t0)
	sw $t2, 8360($t0)
	sw $t2, 8516($t0)
	sw $t2, 8520($t0)
	sw $t2, 8532($t0)
	sw $t2, 8536($t0)
	sw $t2, 8548($t0)
	sw $t2, 8552($t0)
	sw $t2, 8564($t0)
	sw $t2, 8568($t0)
	sw $t2, 8584($t0)
	sw $t2, 8596($t0)
	sw $t2, 8600($t0)
	sw $t2, 8772($t0)
	sw $t2, 8776($t0)
	sw $t2, 8788($t0)
	sw $t2, 8792($t0)
	sw $t2, 8804($t0)
	sw $t2, 8808($t0)
	sw $t2, 8820($t0)
	sw $t2, 8824($t0)
	sw $t2, 8840($t0)
	sw $t2, 8852($t0)
	sw $t2, 8856($t0)
	sw $t2, 8868($t0)
	sw $t2, 8872($t0)
	sw $t2, 9028($t0)
	sw $t2, 9032($t0)
	sw $t2, 9044($t0)
	sw $t2, 9048($t0)
	sw $t2, 9060($t0)
	sw $t2, 9064($t0)
	sw $t2, 9076($t0)
	sw $t2, 9080($t0)
	sw $t2, 9096($t0)
	sw $t2, 9108($t0)
	sw $t2, 9112($t0)
	sw $t2, 9124($t0)
	sw $t2, 9128($t0)
	sw $t2, 9284($t0)
	sw $t2, 9288($t0)
	sw $t2, 9300($t0)
	sw $t2, 9304($t0)
	sw $t2, 9316($t0)
	sw $t2, 9320($t0)
	sw $t2, 9336($t0)
	sw $t2, 9340($t0)
	sw $t2, 9344($t0)
	sw $t2, 9348($t0)
	sw $t2, 9368($t0)
	sw $t2, 9372($t0)
	sw $t2, 9376($t0)
	sw $t2, 9380($t0)
	sw $t2, 9540($t0)
	sw $t2, 9544($t0)
	sw $t2, 9556($t0)
	sw $t2, 9560($t0)
	sw $t2, 9572($t0)
	sw $t2, 9576($t0)
	sw $t2, 9596($t0)
	sw $t2, 9600($t0)
	sw $t2, 9628($t0)
	sw $t2, 9632($t0)
	sw $t3, 6508($t0)
	sw $t3, 6764($t0)
	sw $t3, 7276($t0)
	sw $t3, 7532($t0)
	sw $t3, 7756($t0)
	sw $t3, 7788($t0)
	sw $t3, 7804($t0)
	sw $t3, 7836($t0)
	sw $t3, 8012($t0)
	sw $t3, 8044($t0)
	sw $t3, 8060($t0)
	sw $t3, 8076($t0)
	sw $t3, 8268($t0)
	sw $t3, 8300($t0)
	sw $t3, 8316($t0)
	sw $t3, 8524($t0)
	sw $t3, 8556($t0)
	sw $t3, 8572($t0)
	sw $t3, 8588($t0)
	sw $t3, 8604($t0)
	sw $t3, 8780($t0)
	sw $t3, 8812($t0)
	sw $t3, 8828($t0)
	sw $t3, 8844($t0)
	sw $t3, 8860($t0)
	sw $t3, 9036($t0)
	sw $t3, 9068($t0)
	sw $t3, 9084($t0)
	sw $t3, 9116($t0)
	sw $t3, 9292($t0)
	sw $t3, 9324($t0)
	sw $t3, 9548($t0)
	sw $t3, 9580($t0)
	sw $t4, 7232($t0)
	sw $t4, 7488($t0)
	sw $t4, 7744($t0)
	sw $t4, 7792($t0)
	sw $t4, 7824($t0)
	sw $t4, 8000($t0)
	sw $t4, 8048($t0)
	sw $t4, 8080($t0)
	sw $t4, 8256($t0)
	sw $t4, 8304($t0)
	sw $t4, 8336($t0)
	sw $t4, 8512($t0)
	sw $t4, 8560($t0)
	sw $t4, 8592($t0)
	sw $t4, 8768($t0)
	sw $t4, 8816($t0)
	sw $t4, 8848($t0)
	sw $t4, 8864($t0)
	sw $t4, 9024($t0)
	sw $t4, 9104($t0)
	sw $t4, 9120($t0)
	sw $t4, 9280($t0)
	sw $t4, 9536($t0)
	sw $t5, 7244($t0)
	sw $t6, 7248($t0)
	sw $t7, 7256($t0)
	sw $t7, 9352($t0)
	sw $t7, 9604($t0)
	sw $t8, 7260($t0)
	sw $t8, 9356($t0)
	sw $t8, 9608($t0)
	sw $t9, 7284($t0)
	sw $t9, 7316($t0)
	sw $t9, 7536($t0)
	sw $t9, 7568($t0)
	sw $t9, 8576($t0)
	sw $t9, 8832($t0)
	sw $t9, 9088($t0)
	sw $t9, 9328($t0)
	sw $t9, 9360($t0)
	sw $t9, 9588($t0)
	sw $t9, 9620($t0)
	li $t1, 14417919
	li $t2, 16777179
	li $t3, 9452032
	li $t4, 14389306
	li $t5, 26294
	sw $t1, 7288($t0)
	sw $t1, 7320($t0)
	sw $t1, 7540($t0)
	sw $t1, 7572($t0)
	sw $t1, 8580($t0)
	sw $t1, 8836($t0)
	sw $t1, 9092($t0)
	sw $t1, 9332($t0)
	sw $t1, 9364($t0)
	sw $t1, 9592($t0)
	sw $t1, 9624($t0)
	sw $t2, 7300($t0)
	sw $t2, 7332($t0)
	sw $t2, 7560($t0)
	sw $t2, 7592($t0)
	sw $t2, 9384($t0)
	sw $t2, 9636($t0)
	sw $t3, 7304($t0)
	sw $t3, 7336($t0)
	sw $t3, 7564($t0)
	sw $t3, 7596($t0)
	sw $t3, 9388($t0)
	sw $t3, 9640($t0)
	sw $t4, 7516($t0)
	sw $t4, 7772($t0)
	sw $t4, 7820($t0)
	sw $t4, 7852($t0)
	sw $t4, 8028($t0)
	sw $t4, 8108($t0)
	sw $t4, 8284($t0)
	sw $t4, 8364($t0)
	sw $t4, 8540($t0)
	sw $t4, 8796($t0)
	sw $t4, 8876($t0)
	sw $t4, 9052($t0)
	sw $t4, 9100($t0)
	sw $t4, 9132($t0)
	sw $t4, 9308($t0)
	sw $t4, 9564($t0)
	sw $t5, 7808($t0)
	sw $t5, 8064($t0)
	sw $t5, 9072($t0)
	jr $ra

draw_ntr: # (also generated by img2asm.py)
	la $t0, BASE_ADDRESS
	li $t1, 14992
	li $t2, 14417919
	li $t3, 16777215
	li $t4, 16777142
	li $t5, 6684672
	li $t6, 3838171
	li $t7, 16758416
	li $t8, 9493503
	li $t9, 6684774
	sw $t1, 6520($t0)
	sw $t1, 6776($t0)
	sw $t1, 7544($t0)
	sw $t1, 7800($t0)
	sw $t1, 8056($t0)
	sw $t1, 8312($t0)
	sw $t1, 8568($t0)
	sw $t1, 8824($t0)
	sw $t1, 9080($t0)
	sw $t2, 6524($t0)
	sw $t2, 6780($t0)
	sw $t2, 7324($t0)
	sw $t2, 7548($t0)
	sw $t2, 7804($t0)
	sw $t2, 8060($t0)
	sw $t2, 8316($t0)
	sw $t2, 8572($t0)
	sw $t2, 8828($t0)
	sw $t2, 9084($t0)
	sw $t3, 6528($t0)
	sw $t3, 6784($t0)
	sw $t3, 7004($t0)
	sw $t3, 7008($t0)
	sw $t3, 7020($t0)
	sw $t3, 7036($t0)
	sw $t3, 7040($t0)
	sw $t3, 7044($t0)
	sw $t3, 7056($t0)
	sw $t3, 7060($t0)
	sw $t3, 7260($t0)
	sw $t3, 7264($t0)
	sw $t3, 7268($t0)
	sw $t3, 7272($t0)
	sw $t3, 7276($t0)
	sw $t3, 7280($t0)
	sw $t3, 7292($t0)
	sw $t3, 7296($t0)
	sw $t3, 7300($t0)
	sw $t3, 7312($t0)
	sw $t3, 7316($t0)
	sw $t3, 7516($t0)
	sw $t3, 7520($t0)
	sw $t3, 7532($t0)
	sw $t3, 7536($t0)
	sw $t3, 7552($t0)
	sw $t3, 7568($t0)
	sw $t3, 7572($t0)
	sw $t3, 7576($t0)
	sw $t3, 7580($t0)
	sw $t3, 7772($t0)
	sw $t3, 7776($t0)
	sw $t3, 7788($t0)
	sw $t3, 7792($t0)
	sw $t3, 7808($t0)
	sw $t3, 7824($t0)
	sw $t3, 7828($t0)
	sw $t3, 8028($t0)
	sw $t3, 8032($t0)
	sw $t3, 8044($t0)
	sw $t3, 8048($t0)
	sw $t3, 8064($t0)
	sw $t3, 8080($t0)
	sw $t3, 8084($t0)
	sw $t3, 8284($t0)
	sw $t3, 8288($t0)
	sw $t3, 8300($t0)
	sw $t3, 8304($t0)
	sw $t3, 8320($t0)
	sw $t3, 8336($t0)
	sw $t3, 8340($t0)
	sw $t3, 8540($t0)
	sw $t3, 8544($t0)
	sw $t3, 8556($t0)
	sw $t3, 8560($t0)
	sw $t3, 8576($t0)
	sw $t3, 8592($t0)
	sw $t3, 8596($t0)
	sw $t3, 8796($t0)
	sw $t3, 8800($t0)
	sw $t3, 8812($t0)
	sw $t3, 8816($t0)
	sw $t3, 8832($t0)
	sw $t3, 8848($t0)
	sw $t3, 8852($t0)
	sw $t3, 9052($t0)
	sw $t3, 9056($t0)
	sw $t3, 9068($t0)
	sw $t3, 9072($t0)
	sw $t3, 9088($t0)
	sw $t3, 9092($t0)
	sw $t3, 9104($t0)
	sw $t3, 9108($t0)
	sw $t3, 9308($t0)
	sw $t3, 9312($t0)
	sw $t3, 9324($t0)
	sw $t3, 9328($t0)
	sw $t3, 9344($t0)
	sw $t3, 9348($t0)
	sw $t3, 9360($t0)
	sw $t3, 9364($t0)
	sw $t4, 6532($t0)
	sw $t4, 6788($t0)
	sw $t4, 7024($t0)
	sw $t4, 7064($t0)
	sw $t4, 7556($t0)
	sw $t4, 7812($t0)
	sw $t4, 8068($t0)
	sw $t4, 8324($t0)
	sw $t4, 8580($t0)
	sw $t4, 8836($t0)
	sw $t5, 6536($t0)
	sw $t5, 6792($t0)
	sw $t5, 7560($t0)
	sw $t5, 7816($t0)
	sw $t5, 8072($t0)
	sw $t5, 8328($t0)
	sw $t5, 8584($t0)
	sw $t5, 8840($t0)
	sw $t6, 7000($t0)
	sw $t6, 7256($t0)
	sw $t6, 7512($t0)
	sw $t6, 7768($t0)
	sw $t6, 8024($t0)
	sw $t6, 8280($t0)
	sw $t6, 8536($t0)
	sw $t6, 8792($t0)
	sw $t6, 9048($t0)
	sw $t6, 9304($t0)
	sw $t7, 7012($t0)
	sw $t8, 7016($t0)
	sw $t9, 7028($t0)
	li $t1, 11993087
	li $t2, 16767888
	li $t3, 3827382
	li $t4, 6710966
	li $t5, 3801088
	li $t6, 14389392
	li $t7, 16767963
	li $t8, 16758374
	li $t9, 6731519
	sw $t1, 7032($t0)
	sw $t1, 7288($t0)
	sw $t2, 7048($t0)
	sw $t2, 7072($t0)
	sw $t2, 7304($t0)
	sw $t2, 7328($t0)
	sw $t2, 7584($t0)
	sw $t2, 8088($t0)
	sw $t2, 8344($t0)
	sw $t2, 8600($t0)
	sw $t2, 8856($t0)
	sw $t2, 9096($t0)
	sw $t2, 9112($t0)
	sw $t2, 9352($t0)
	sw $t2, 9368($t0)
	sw $t3, 7052($t0)
	sw $t3, 7308($t0)
	sw $t3, 9100($t0)
	sw $t3, 9356($t0)
	sw $t4, 7068($t0)
	sw $t5, 7076($t0)
	sw $t5, 7332($t0)
	sw $t5, 7588($t0)
	sw $t5, 8092($t0)
	sw $t5, 8348($t0)
	sw $t5, 8604($t0)
	sw $t5, 8860($t0)
	sw $t5, 9116($t0)
	sw $t5, 9372($t0)
	sw $t6, 7284($t0)
	sw $t7, 7320($t0)
	sw $t8, 7524($t0)
	sw $t8, 7780($t0)
	sw $t8, 8036($t0)
	sw $t8, 8292($t0)
	sw $t8, 8548($t0)
	sw $t8, 8804($t0)
	sw $t8, 9060($t0)
	sw $t8, 9316($t0)
	sw $t9, 7528($t0)
	sw $t9, 7784($t0)
	sw $t9, 8040($t0)
	sw $t9, 8296($t0)
	sw $t9, 8552($t0)
	sw $t9, 8808($t0)
	sw $t9, 9064($t0)
	sw $t9, 9320($t0)
	sw $t9, 9340($t0)
	li $t1, 14389306
	li $t2, 26294
	li $t3, 16777179
	li $t4, 9452032
	sw $t1, 7540($t0)
	sw $t1, 7796($t0)
	sw $t1, 8052($t0)
	sw $t1, 8308($t0)
	sw $t1, 8564($t0)
	sw $t1, 8820($t0)
	sw $t1, 9076($t0)
	sw $t1, 9332($t0)
	sw $t2, 7564($t0)
	sw $t2, 7820($t0)
	sw $t2, 8076($t0)
	sw $t2, 8332($t0)
	sw $t2, 8588($t0)
	sw $t2, 8844($t0)
	sw $t3, 7832($t0)
	sw $t4, 7836($t0)
	jr $ra
