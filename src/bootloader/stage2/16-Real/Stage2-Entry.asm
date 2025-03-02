[bits 16]

%define ENDL 0x0A, 0x0D

global entry
global drive_number
global boot_partition_segment
global boot_partition_offset

extern detect_memory
extern to_32_prot
extern __bss_start
extern __end

section .text

;----------------------------------------------------------------
; Main Entry Function (Stage 2 Entry Point)
; 
; This is the final point before switching away from BIOS mode.
; It:
;  - Disables interrupts and sets up the stack.
;  - Saves the drive number and boot partition address.
;  - Clears the BSS section.
;  - Clears the screen and disables the cursor.
;  - Prints a 16-bit mode entry message.
;  - Calls external routines to detect memory and switch to 32-bit 
;    protected mode.
;----------------------------------------------------------------
entry:
    ; Disable interrupts for safe initialization.
    cli

    ; Set up the stack: use DS as SS.
    mov ax, ds 
    mov ss, ax

    ; Initialize the stack pointer near the top of memory.
    mov sp, 0xFFF0
    mov bp, sp

    ; Save drive number from DL.
    mov [drive_number], dl

    ; Save boot partition address from ES:DI.
    mov [boot_partition_segment], es
    mov [boot_partition_offset], di

    ; Clear the BSS section (zero memory between __bss_start and __end).
    mov edi, __bss_start
    mov ecx, __end
    sub ecx, edi
    mov al, 0
    cld
    rep stosb

    ; Clear the screen.
    call clr_scrn

    ; Disable the cursor.
    mov ah, 0x1
    mov ch, 0x3F
    int 0x10

    ; Print the stage 2 message.
    mov si, bit16_msg
    call puts

    ; Call external functions.
    call detect_memory
    call to_32_prot

.halt:
    ; If control returns here, halt the CPU.
    cli
    hlt
    jmp .halt

;----------------------------------------------------------------
; Function: puts
; Description: Prints a null-terminated string using BIOS teletype output.
; Input: SI points to the null-terminated string.
;----------------------------------------------------------------
puts:
    [bits 16]
    ; Save registers that will be modified.
    push si
    push ax

.puts_loop:
    lodsb                  ; Load next byte from DS:SI into AL.
    or al, al              ; Check if character is null.
    jz .puts_done          ; If null, end of string.
    mov ah, 0x0E           ; BIOS teletype output function.
    mov bh, 0x00           ; Set page number to 0.
    int 0x10               ; Print the character.
    jmp .puts_loop

.puts_done:
    pop ax
    pop si
    ret

;----------------------------------------------------------------
; Function: clr_scrn
; Description: Clears the screen by writing spaces over the display.
;----------------------------------------------------------------
clr_scrn:
    ; Save registers that will be modified.
    push ax
    push bx
    push cx
    push dx

    ; Reset cursor to the top-left corner.
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10

    ; Prepare to fill the screen with blank spaces.
    mov ah, 0x0E
    mov al, " "          ; Character: space.
    mov cx, 0            ; Counter for number of characters printed.

.clear_loop:
    cmp cx, 2000         ; 2000 characters for 80x25 text mode.
    je .clr_done         ; If done, exit loop.
    inc cx
    int 0x10             ; Print the space.
    jmp .clear_loop

.clr_done:
    ; Reset the cursor to the top-left corner again.
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10

    ; Restore registers.
    pop dx
    pop cx
    pop bx
    pop ax
    ret

section .data
    drive_number:            db 0
    boot_partition_segment:  dw 0
    boot_partition_offset:   dw 0

section .rodata
    bit16_msg: db "Stage2 16 bit mode entered!", ENDL, 0
