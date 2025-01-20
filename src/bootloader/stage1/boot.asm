;;
; This file is the entry point to the bootloader. It will load the second stage and jump to it.
; @include{lineno} boot.asm
; @author Aidcraft
; @version 0.0.2
; @date 2025-01-19
; 
; @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
; @par License:
; This project is released under the Artistic License 2.0
;;

bits 16

global start

section .fsjump

    jmp short start
    nop

section .text

;;
; @brief Entry point of the bootloader
; @details Initializes data segments, sets up the stack, prints a message, and enters an infinite loop to hang the system.
;;
start:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov si, message
    call print_string

hang:
    jmp hang

;;
; @brief Function to print a string
; @details Prints a null-terminated string using BIOS interrupt 0x10.
; @param[in] si Address of the null-terminated string to print
;;
print_string:
    push si
    push ax
    push bx

.next_char:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .next_char

.done:
    pop bx
    pop ax
    pop si
    ret

message db 'Hello, World!', 0

section bios_footer
