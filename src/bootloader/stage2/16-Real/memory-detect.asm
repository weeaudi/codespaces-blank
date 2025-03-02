[bits 16]

global detect_memory
global memory_map
global memory_size

%define ENDL 0x0A, 0x0D

section .text

;-------------------------------------------------------------------
; Main Function: detect_memory
; 
; Description:
;   Enumerates the system memory map using BIOS interrupt 15h, function
;   E820h. It writes each memory descriptor (24 bytes) into the buffer 
;   at memory_map and increments the count in memory_size.
;
;   If the BIOS call does not return the expected signature or if the 
;   carry flag is set, then it stops. In case of failure, an error 
;   message is printed and the system is halted.
;
; Inline comments explain each step.
;-------------------------------------------------------------------
detect_memory:
    ; Save registers that will be modified.
    push di
    push si
    push ebx
    push eax
    push ecx
    push edx

    ; Set DI to point to the start of the memory map buffer.
    mov di, memory_map

    ; Initialize EBX to 0 for the first call.
    xor ebx, ebx

    ; Set EDX to the magic value 'SMAP' (0x534D4150) required for E820.
    mov edx, 0x534D4150

.loop:
    ; Clear the carry flag before calling BIOS.
    clc

    ; Prepare registers for the E820 call.
    mov eax, 0xE820      ; Function code for E820 memory map.
    mov ecx, 24          ; Request 24 bytes (size of one descriptor).

    ; Call BIOS interrupt 15h to get one memory map entry.
    int 15h

    ; Check if EAX returned the correct signature ('SMAP').
    cmp eax, 0x534D4150
    jne .fail            ; If not, jump to failure.

    ; If the carry flag is set, then the call failed.
    jc .done

    ; If EBX is zero, no more entries are available.
    cmp ebx, 0
    je .done

    ; Advance DI by 24 bytes to store the next descriptor.
    add di, 24

    ; Increment the memory map entry count stored at memory_size.
    mov si, [memory_size]
    add si, 1
    mov [memory_size], si

    ; Check if the returned descriptor size equals 24.
    ; If so, this entry contains ACPI 3.0 extended info.
    cmp cl, 24
    je .acpi3

    ; Otherwise, continue retrieving the next entry.
    jmp .loop

.acpi3:
    ; Set the highest bit in the memory type field of the current entry
    ; to indicate ACPI 3.0 extended information.
    mov byte [es:di - 4], 1 << 7
    jmp .loop

.done:
    ; Restore registers and return.
    pop edx
    pop ecx
    pop eax
    pop ebx
    pop si
    pop di
    ret

.fail:
    ; In case of failure, print an error message and halt the system.
    mov si, memory_fail_msg
    call puts
    cli
    hlt

;-------------------------------------------------------------------
; Function: puts
; Description:
;   Prints a null-terminated string using BIOS teletype output.
; Input:
;   SI - pointer to the null-terminated string.
;-------------------------------------------------------------------
puts:
    [bits 16]
    ; Save registers that will be modified.
    push si
    push ax

.puts_loop:
    lodsb              ; Load next byte from DS:SI into AL.
    or al, al          ; Check if the byte is zero (end of string).
    jz .puts_done      ; If zero, end the loop.
    mov ah, 0x0E       ; BIOS teletype output function.
    mov bh, 0x00       ; Display page 0.
    int 0x10           ; Print the character in AL.
    jmp .puts_loop

.puts_done:
    pop ax
    pop si
    ret

section .rodata
    memory_fail_msg: db "ERROR: memory detection has failed!", ENDL, 0

section .bss
    memory_map: resb 512
    memory_size: resb 1
