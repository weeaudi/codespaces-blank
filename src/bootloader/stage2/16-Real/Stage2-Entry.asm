;;
; This is the entry to the second stage bootloader. it will switch to 64 bit mode
; @include{lineno} Stage2-Entry.asm
; @author Aidcraft
; @version 0.0.2
; @date 2025-01-19
; 
; @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
; @par License:
; This project is released under the Artistic License 2.0
;;

[bits 16]

%define ENDL 0x0A, 0x0D

global entry

extern detect_memory
extern to_32_prot
extern __bss_start
extern __end

section .text

    ;;
    ; @brief Entry to stage 2
    ; @details This file is the last point we call the bios.
    ; @param[in] dl Drive number
    ; @param[in] es:di Boot partition address in Seg:Off
    ;;
    entry:

        cli
        mov ax, ds 
        mov ss, ax
        mov sp, 0xFFF0
        mov bp, sp
        sti

        mov [drive_number], dl

        mov [boot_partition_segment], es
        mov [boot_partition_offset], di

        ; clear bss
        mov edi, __bss_start
        mov ecx, __end
        sub ecx, edi
        mov al, 0
        cld
        rep stosb

        call clr_scrn
        
        ; set 80*50 text mode
        mov ax, 0x1112
        int 0x10

        ; disable cursor
        mov ah, 0x1
        mov ch, 0x3F
        int 10h

        mov si, bit16_msg
        call puts

        call detect_memory

        call to_32_prot

    .halt:
        cli
        hlt
        jmp .halt



    ;;
    ; @brief prints a string using BIOS
    ; @param[in] si address of string
    ;;
    puts:
        [bits 16]
        ; save registers we mofify
        push si
        push ax

    .loop:
        lodsb                  ; load next byte from ds:si into al
        or al, al              ; check if al is zero
        jz .done               ; if zero, we're done
        mov ah, 0x0E           ; teletype output
        mov bh, 0x00           ; page number
        int 0x10               ; call video interrupt
        jmp .loop

    .done:

        pop ax
        pop si

        ret

    ;;
    ; @brief clears the screen
    ;;
    clr_scrn:
        push ax
        push bx
        push cx
        push dx

        mov ah, 0x02
        mov bh, 0
        mov dx, 0

        int 0x10

        mov ah, 0x0E
        mov al, " "

        mov cx, 0

    .loop:

        cmp cx, 2000
        je .done
        inc cx

        int 0x10

        jmp .loop

    .done:

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

    drive_number: db 0
    boot_partition_segment: dw 0
    boot_partition_offset: dw 0

section .rodata

    bit16_msg: db "Stage2 16 bit mode entered!", ENDL,0