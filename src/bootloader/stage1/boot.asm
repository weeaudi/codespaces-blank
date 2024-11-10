; boot.asm - A simple bootloader that prints "Hello, World!"

org 0x7C00
bits 16

start:

    ; setup data segments
    mov ax, 0                   ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we are loaded in memory

    ; Print "Hello, World!"
    mov si, message  ; Load the address of the message
    call print_string ; Call the function to print the string

    ; Hang the system (infinite loop)
hang:
    jmp hang

; Function to print a string
print_string:

    push si         ; save registers we modify
    push ax
    push bx

.next_char:
    lodsb            ; Load byte at DS:SI into AL and increment SI
    or al, al           ; verify if next character is null?
    jz .done
    mov ah, 0x0E    ; BIOS teletype function (write character)
    mov bh, 0
    int 0x10        ; Call BIOS interrupt to print character
    jmp .next_char  ; Repeat for the next character
.done:

    pop bx          ; set the registers back
    pop ax
    pop si

    ret              ; Return from the function

message db 'Hello, World! this is a testy test x 5', 0  ; Null-terminated string

times 510-($-$$) db 0
dw 0AA55h