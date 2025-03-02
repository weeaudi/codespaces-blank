[bits 16]

global to_32_prot

extern to_64_prot

%define ENDL 0x0A, 0x0D

; Keyboard controller port definitions
KbdControllerDataPort              equ 0x60
KbdControllerCommandPort           equ 0x64
KbdControllerDisableKeyboard       equ 0xAD
KbdControllerEnableKeyboard        equ 0xAE
KbdControllerReadCtrlOutputPort    equ 0xD0
KbdControllerWriteCtrlOutputPort   equ 0xD1

section .text

;---------------------------------------------------------------
; Main Function: to_32_prot
;
; Description:
;   Prepares the system to switch from 16-bit real mode to
;   32-bit protected mode by performing the following steps:
;     1. Clears the screen.
;     2. Displays a message.
;     3. Disables interrupts.
;     4. Enables the A20 line.
;     5. Loads the Global Descriptor Table (GDT).
;     6. Sets the Protection Enable (PE) bit in CR0.
;     7. Jumps to the 32-bit code segment.
;---------------------------------------------------------------
to_32_prot:
    call clr_scrn

    ; Print message: "Switching to 32bit protected mode!"
    mov si, to_prot_message
    call puts

    cli             ; Disable interrupts
    call EnableA20  ; Enable the A20 line
    call LoadGDT    ; Load the Global Descriptor Table

    ; Set PE bit in CR0 (enable protected mode)
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Jump to the 32-bit code segment (selector 0x08)
    jmp dword 08h:.PMODE32

    cli
    hlt

.PMODE32:
    [bits 32]
    call to_64_prot
    cli
    hlt

;---------------------------------------------------------------
; Function: EnableA20
;
; Description:
;   Enables the A20 line so that memory above 1MB can be accessed.
;   It uses keyboard controller commands to disable/enable the
;   keyboard and set the A20 bit.
;---------------------------------------------------------------
EnableA20:
    [bits 16]
    ; Disable keyboard input
    call A20WaitInput
    mov al, KbdControllerDisableKeyboard
    out KbdControllerCommandPort, al

    ; Read controller output port
    call A20WaitInput
    mov al, KbdControllerReadCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitOutput
    in al, KbdControllerDataPort

    push eax

    ; Write to controller output port to enable A20
    call A20WaitInput
    mov al, KbdControllerWriteCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitInput

    pop eax
    or al, 2            ; Set A20 bit (bit 2)
    out KbdControllerDataPort, al

    ; Enable keyboard
    call A20WaitInput
    mov al, KbdControllerEnableKeyboard
    out KbdControllerCommandPort, al

    call A20WaitInput
    ret

;---------------------------------------------------------------
; Function: A20WaitInput
;
; Description:
;   Waits until the keyboard controller's input buffer is empty.
;   It polls the command port until bit 1 (input buffer) is clear.
;---------------------------------------------------------------
A20WaitInput:
    [bits 16]
    in al, KbdControllerCommandPort
    test al, 2
    jnz A20WaitInput
    ret

;---------------------------------------------------------------
; Function: A20WaitOutput
;
; Description:
;   Waits until the keyboard controller's output buffer is full,
;   so that data can be read.
;---------------------------------------------------------------
A20WaitOutput:
    [bits 16]
    in al, KbdControllerCommandPort
    test al, 1
    jz A20WaitOutput
    ret

;---------------------------------------------------------------
; Function: LoadGDT
;
; Description:
;   Loads the Global Descriptor Table (GDT) using the LGDT instruction.
;---------------------------------------------------------------
LoadGDT:
    [bits 16]
    lgdt [g_GDTDesc]
    ret

;---------------------------------------------------------------
; Function: puts
;
; Description:
;   Prints a null-terminated string to the screen using MMIO.
;   It uses the video memory at 0xB8000 as the output destination.
;
; Input:
;   SI - Pointer to the null-terminated string.
;---------------------------------------------------------------
puts:
    [bits 16]
    push si
    push ax
    push ebx

.puts_loop:
    lodsb              ; Load next byte from DS:SI into AL.
    or al, al          ; Check for null terminator.
    jz .puts_done
    mov ebx, [screen_pointer]
    mov [ebx], al      ; Write character to video memory.
    add ebx, 2         ; Advance pointer (each character cell is 2 bytes).
    mov [screen_pointer], ebx
    jmp .puts_loop

.puts_done:
    pop ebx
    pop ax
    pop si
    ret

;---------------------------------------------------------------
; Function: clr_scrn
;
; Description:
;   Clears the screen by resetting the cursor and printing blank
;   spaces across the entire display (2000 characters for 80x25 mode).
;---------------------------------------------------------------
clr_scrn:
    push ax
    push bx
    push cx
    push dx

    ; Reset the cursor to the top-left corner
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10

    ; Print spaces to clear the screen
    mov ah, 0x0E
    mov al, " "
    mov cx, 0

.clr_loop:
    cmp cx, 2000       ; 80 columns * 25 rows = 2000 characters
    je .clr_done
    inc cx
    int 0x10
    jmp .clr_loop

.clr_done:
    ; Reset the cursor again to the home position
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax
    ret

section .data
    screen_pointer: dd 0xB8000

section .rodata
    to_prot_message: db "Switching to 32bit protected mode!", 0

    g_GDT: 
        dq 0           ; null descriptor

        ; 32-bit code segment descriptor segment 8
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10011010b    ; access byte (present, ring 0, code segment, executable, direction 0, readable)
        db 11001111b    ; granularity (4KB pages, 32-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 32-bit data segment descriptor segment 16
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10010010b    ; access byte (present, ring 0, data segment, executable, direction 0, writable)
        db 11001111b    ; granularity (4KB pages, 32-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 16-bit code segment descriptor segment 24
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10011011b    ; access byte (present, ring 0, code segment, executable, direction 0, readable)
        db 00001111b    ; granularity (1B pages, 16-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 16-bit data segment descriptor segment 32
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10010011b    ; access byte (present, ring 0, data segment, executable, direction 0, writable)
        db 00001111b    ; granularity (1B pages, 16-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

    g_GDTDesc:
        dw g_GDTDesc - g_GDT - 1     ; limit (size of GDT)
        dd g_GDT                        ; base of GDT
