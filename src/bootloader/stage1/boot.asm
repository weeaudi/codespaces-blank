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

%include "/home/aiden/Desktop/aidos3/src/bootloader/stage1/config.inc"

global start

section .fsjump

    jmp short start
    nop

section .fsheaders

    bdb_oem:                            db 'MSWIN4.1'               ; 8 bytes
    bdb_bytes_per_sector:               dw 512                      ; 2 bytes
    bdb_sectors_per_cluster:            db 1                        ; 1 byte
    bdb_reserved_sectors:               dw 19                       ; 2 bytes
    bdb_fat_count:                      db 2                        ; 1 byte
    bdb_dir_entries_count:              dw 0E0h                     ; 2 bytes
    bdb_total_sectors:                  dw 2880                     ; 2 bytes 2880 * 512 = 1.44MB
    bdb_media_descriptor:               db 0F0h                     ; 1 byte F0h = 3.5" floppy
    bdb_sectors_per_fat:                dw 9                        ; 2 bytes 9 sectors per FAT
    bdb_sectors_per_track:              dw 18                       ; 2 bytes
    bdb_heads:                          dw 2                        ; 2 bytes
    bdb_hidden_sectors:                 dd 0                        ; 4 bytes
    bdb_large_sector_count:             dd 0                        ; 4 bytes

    ebr_drive_number:                   db 0                        ; 1 byte 0x00 floppy, 0x80 hard drive, useless
    ebr_reserved:                       db 0                        ; 1 byte
    ebr_signature:                      db 29h                      ; 1 byte 29h = extended boot sector
    ebr_volume_id:                      db 'AIDC'                   ; 4 bytes serial number, value doesn't matter
    ebr_volume_label:                   db 'AIDCRAFT OS'            ; 11 bytes volume label, padded with spaces
    ebr_system_id:                      db 'FAT12   '               ; 8 bytes file system type, padded with spaces

section .text

    ;;
    ; @brief Entry point of the bootloader
    ; @details Initializes data segments, sets up the stack, relocates self, moves partition entry, jumps to stage 2.
    ;;
    start:

        ; move partition entry to 0x2000:0x0000
        mov ax, STAGE1_SEGMENT
        mov es, ax
        mov di, partition_entry
        mov cx, 16
        rep movsb

        ; relocate self

        mov ax, 0
        mov ds, ax
        mov si, 0x7C00
        ; mov ax, STAGE1_SEGMENT
        ; mov es, ax
        mov di, STAGE1_OFFSET
        mov cx, 512
        rep movsb

        jmp STAGE1_SEGMENT:.relocated

    .relocated:

        mov ax, STAGE1_SEGMENT
        mov ds, ax
        mov ss, ax
        mov sp, STAGE1_OFFSET

        mov [ebr_drive_number], dl

        mov si, message
        call print_string
        call check_disk_extended

        mov si, boot_table

        mov eax, [boot_data_lba]
        mov cl, 1
        mov bx, boot_table
        call disk_read

        mov eax, [si + 0]
        mov [entry_point], eax ; used eax to move both segment and offset at the same time
        add si, 4

    .readloop:

        ; parse boot table (null table contains 0)

        cmp dword [si + boot_table_entry.lba], 0
        je .end_readloop

        mov eax, [si + boot_table_entry.lba]
        mov bx, [si + boot_table_entry.load_seg]
        mov es, bx
        mov bx, [si + boot_table_entry.load_off]
        mov cl, [si + boot_table_entry.count]
        call disk_read

        add si, boot_table_entry_size
        jmp .readloop

        .end_readloop:

        ; jump to our stage 2
        mov dl, [ebr_drive_number]          ; set dl to drive number
        mov di, partition_entry

        mov ax, [entry_point.segment]
        mov ds, ax
        
        push ax
        push word [entry_point.offset]
        retf


    hang:
        jmp hang

    ;;
    ; @brief Function to print a string
    ; @details Prints a null-terminated string using BIOS interrupt 0x10.
    ; @param[in] ds:si Address of the null-terminated string to print
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

    ;;
    ; @brief Converts an LBA address to a CHS address
    ; @param[in] ax LBA address
    ; @return cx [bits 0-5] sector number
    ; @return cx [bits 6-15] cylinder
    ; @return dh head
    ;;
    lba_to_chs:
        push ax
        push dx

        xor dx, dx                          ; dx = 0
        div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                            ; dx = LBA % SectorsPerTrack

        inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
        mov cx, dx                          ; cx = sector

        xor dx, dx                          ; dx = 0
        div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                            ; dx = (LBA / SectorsPerTrack) % Heads = head
        mov dh, dl                          ; dh = head
        mov ch, al                          ; ch = cylinder (lower 8 bits)
        shl ah, 6
        or cl, ah                           ; put upper 2 bits of cylinder in CL

        pop ax
        mov dl, al                          ; restore DL
        pop ax
        ret

    ;;
    ; @breif check disk extended presence
    ; @param[in] dl drive number
    ;;
    check_disk_extended:
        push ax
        push bx
        push cx
        push dx

        stc
        mov ah, 41h
        mov bx, 55AAh
        int 13h

        jc .no_disk_extended
        cmp bx, 0xAA55
        jne .no_disk_extended

        ; extensions are present

        mov byte [disk_extended_present], 1

        jmp .after_disk_check

    .no_disk_extended:

        mov byte [disk_extended_present], 0

    .after_disk_check:

        pop dx
        pop cx
        pop bx
        pop ax
        ret

    ;;
    ; @brief Read from disk
    ; @details will read from the provided disk and load a number of sections into memory
    ;
    ; @param[in] eax LBA address
    ; @param[in] cl number of sectors to read (up to 128)
    ; @param[in] dl drive number
    ; @param[out] es:bx memory address where to store read data
    ;
    ;;
    disk_read:

        push eax                            ; save registers we will modify
        push bx
        push cx
        push dx
        push si
        push di

        cmp byte [disk_extended_present], 1
        jne .no_disk_extensions

        ; with extensions
        mov [extension_dap.address], eax
        mov [extension_dap.segment], es
        mov [extension_dap.offset], bx
        mov [extension_dap.count], cl

        mov ah, 0x42
        mov si, extension_dap
        mov di, 3                           ; retry count

        .retry:
            pusha                           ; save all registers, we don't know what bios modifies
            stc                             ; set carry flag, some BIOS'es don't set it
            int 13h                         ; carry flag cleared = success
            jnc .done                       ; jump if carry not set

            ; read failed
            popa
            call disk_reset

            dec di
            test di, di
            jnz .retry

        .fail:
            ; all attempts are exhausted
            jmp floppy_error

        .done:
            popa
            jmp .function_end

    .no_disk_extensions:
        mov esi, eax                            ; save lba to esi
        mov di, cx                              ; save number of sectors to di

        .outer_loop:
            mov eax, esi
            call lba_to_chs                     ; compute CHS
            mov al, 1                           ; read 1 sector

            push di
            mov di, 3                           ; retry count
            mov ah, 02h

            .inner_retry:
                pusha                           ; save all registers, we don't know what bios modifies
                stc                             ; set carry flag, some BIOS'es don't set it
                int 13h                         ; carry flag cleared = success
                jnc .inner_done                 ; jump if carry not set

                ; read failed
                popa
                call .inner_retry

                dec di
                test di, di
                jnz .retry

            .inner_fail:
                ; all attempts are exhausted
                jmp floppy_error

            .inner_done:

            popa
            pop di

            cmp di, 0                   ; exit condition - have we read all the sectors?
            je .function_end

            inc esi                     ; increment lba we want to read
            dec di                      ; decrement number of sectors
            
            mov ax, es
            add ax, 512 / 16            ; increment destination address (use segment to avoid segment boundary trouble)
            mov es, ax
            jmp .outer_loop


    .function_end:
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop eax                            ; restore registers modified
        ret

    ;;
    ; @brief Resets the disk
    ; @param dl drive number
    ;;
    disk_reset:
        pusha
        mov ah, 00h
        stc
        int 13h
        jc floppy_error
        popa
        ret

    ;;
    ; @brief Error handling
    ;;
    floppy_error:
        mov si, floppy_error_message
        call print_string
        cli
        hlt
        jmp floppy_error

section .data
    extension_dap:
        .size:      db 10h
        .reserved:  db 0
        .count:     dw 0
        .offset:    dw 0
        .segment:   dw 0
        .address:   dq 0

    struc boot_table_entry
        .lba       resd 1
        .load_off  resw 1
        .load_seg  resw 1
        .count     resw 1
    endstruc

    global boot_data_lba
    boot_data_lba: dd 0

    floppy_error_message: db 'Floppy Error!', 0
    message: db 'Hello, World!', 0

section bios_footer

section .bss

    buffer: resb 512
    boot_table: resb 512
    partition_entry: resb 16
    disk_extended_present: resb 1
    entry_point:
        .offset: resw 1
        .segment: resw 1
