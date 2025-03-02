bits 16

%include "config.inc"

global start

;-------------------------------------------------------------------------
; Section: FS Jump
; Description: Provides a short jump to the main bootloader entry point.
;-------------------------------------------------------------------------
section .fsjump
    jmp short start
    nop

;-------------------------------------------------------------------------
; Section: FS Headers
; Description: Contains the BIOS Parameter Block (BPB) and Extended Boot Record (EBR)
;              fields for a FAT12 formatted 1.44MB floppy disk.
;-------------------------------------------------------------------------
section .fsheaders
    bdb_oem:                db 'MSWIN4.1'    ; OEM Identifier (8 bytes)
    bdb_bytes_per_sector:   dw 512           ; Bytes per sector (2 bytes)
    bdb_sectors_per_cluster: db 1            ; Sectors per cluster (1 byte)
    bdb_reserved_sectors:   dw 19           ; Reserved sectors (2 bytes)
    bdb_fat_count:          db 2            ; Number of FATs (1 byte)
    bdb_dir_entries_count:  dw 0E0h         ; Directory entries count (2 bytes)
    bdb_total_sectors:      dw 2880         ; Total sectors (2 bytes) (1.44MB floppy)
    bdb_media_descriptor:   db 0F0h         ; Media descriptor (1 byte, F0h = 3.5" floppy)
    bdb_sectors_per_fat:    dw 9            ; Sectors per FAT (2 bytes)
    bdb_sectors_per_track:  dw 18           ; Sectors per track (2 bytes)
    bdb_heads:              dw 2            ; Number of heads (2 bytes)
    bdb_hidden_sectors:     dd 0            ; Hidden sectors (4 bytes)
    bdb_large_sector_count: dd 0            ; Large sector count (4 bytes)

    ebr_drive_number:       db 0            ; Drive number (0x00 = floppy, 0x80 = hard drive)
    ebr_reserved:           db 0            ; Reserved (1 byte)
    ebr_signature:          db 29h          ; Extended boot signature (1 byte)
    ebr_volume_id:          db 'AIDC'       ; Volume ID (4 bytes, serial number not significant)
    ebr_volume_label:       db 'AIDCRAFT OS' ; Volume label (11 bytes, padded with spaces)
    ebr_system_id:          db 'FAT12   '    ; File system type (8 bytes, padded with spaces)

;-------------------------------------------------------------------------
; Section: Main Bootloader Code
; Description: This is the primary bootloader entry point. It performs:
;   1. Copying the partition entry to a fixed memory location.
;   2. Relocating the bootloader from its original location (0x7C00) to a new one.
;   3. Setting up the data and stack segments.
;   4. Printing a welcome message and checking for disk extended functions.
;   5. Reading the boot table and loading additional sectors.
;   6. Jumping to stage 2 of the boot process.
;-------------------------------------------------------------------------
section .text

start:
    ; --- Step 1: Copy partition entry (16 bytes) to STAGE1_SEGMENT:0x0000 ---
    mov ax, STAGE1_SEGMENT
    mov es, ax
    mov di, partition_entry
    mov cx, 16
    rep movsb

    ; --- Step 2: Relocate bootloader code ---
    mov ax, 0
    mov ds, ax
    mov si, 0x7C00           ; Source: original bootloader location
    mov di, STAGE1_OFFSET    ; Destination: new memory location
    mov cx, 512              ; Copy one sector (512 bytes)
    rep movsb

    ; Jump to the relocated code
    jmp STAGE1_SEGMENT:.relocated

.relocated:
    ; --- Step 3: Set up segments and stack ---
    mov ax, STAGE1_SEGMENT
    mov ds, ax
    mov ss, ax
    mov sp, STAGE1_OFFSET

    ; --- Step 4: Store drive number and print welcome message ---
    mov [ebr_drive_number], dl

    mov si, message
    call print_string
    call check_disk_extended

    ; --- Step 5: Read boot table from disk ---
    mov si, boot_table
    mov eax, [boot_data_lba]
    mov cl, 1
    mov bx, boot_table
    call disk_read

    ; Read the first 4 bytes of the boot table and save as entry point.
    mov eax, [si + 0]
    mov [entry_point], eax    ; both segment and offset are stored in EAX
    add si, 4

.readloop:
    ; --- Parse boot table entries ---
    cmp dword [si + boot_table_entry.lba], 0
    je .end_readloop

    ; Read sector(s) defined by the current boot table entry.
    mov eax, [si + boot_table_entry.lba]      ; LBA address
    mov bx, [si + boot_table_entry.load_seg]    ; load segment
    mov es, bx
    mov bx, [si + boot_table_entry.load_off]    ; load offset
    mov cl, [si + boot_table_entry.count]       ; number of sectors to read
    call disk_read

    add si, boot_table_entry_size    ; move to next boot table entry
    jmp .readloop

.end_readloop:
    ; --- Step 6: Jump to stage 2 ---
    mov dl, [ebr_drive_number]       ; restore drive number
    mov di, partition_entry

    mov ax, [entry_point.segment]
    mov ds, ax
    push ax
    push word [entry_point.offset]
    retf

    ; In case something goes wrong, hang here.
hang:
    jmp hang

;-------------------------------------------------------------------------
; Function: print_string
; Description: Prints a null-terminated string using BIOS interrupt 0x10.
; Input: DS:SI points to the null-terminated string.
;-------------------------------------------------------------------------
print_string:
    push si
    push ax
    push bx
.next_char:
    lodsb                ; Load next character into AL
    or al, al
    jz .done           ; If zero, end of string reached
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0
    int 0x10           ; BIOS video interrupt to print character
    jmp .next_char
.done:
    pop bx
    pop ax
    pop si
    ret

;-------------------------------------------------------------------------
; Function: lba_to_chs
; Description: Converts a Logical Block Address (LBA) into a Cylinder-Head-Sector (CHS)
;              address.
; Input:  AX contains the LBA.
; Output: CX holds the sector number (low 6 bits) and the high bits of cylinder,
;         CH holds the lower 8 bits of the cylinder,
;         DH contains the head number.
;-------------------------------------------------------------------------
lba_to_chs:
    push ax
    push dx

    xor dx, dx                         ; Clear DX for division
    div word [bdb_sectors_per_track]   ; AX = LBA / sectors_per_track, DX = remainder
    inc dx                             ; Sector number = remainder + 1
    mov cx, dx                         ; Store sector in CX

    xor dx, dx                         ; Clear DX for next division
    div word [bdb_heads]               ; AX = cylinder, DX = head
    mov dh, dl                         ; Head in DH
    mov ch, al                         ; Lower 8 bits of cylinder in CH
    shl ah, 6
    or cl, ah                          ; Merge upper 2 bits of cylinder into CL

    pop dx
    pop ax
    ret

;-------------------------------------------------------------------------
; Function: check_disk_extended
; Description: Checks for the presence of disk extended functions.
; Input: DL contains the drive number.
; Output: Sets [disk_extended_present] to 1 if available, 0 otherwise.
;-------------------------------------------------------------------------
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

    ; Extended disk functions are present.
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

;-------------------------------------------------------------------------
; Function: disk_read
; Description: Reads sectors from the disk into memory.
;              Uses extended disk functions if available; otherwise, it falls back
;              to the standard BIOS disk read.
; Inputs:
;   EAX - LBA address of the sector(s) to read.
;   CL  - Number of sectors to read (up to 128).
;   DL  - Drive number.
;   ES:BX - Destination memory address for the data.
;-------------------------------------------------------------------------
disk_read:
    push eax
    push bx
    push cx
    push dx
    push si
    push di

    cmp byte [disk_extended_present], 1
    jne .no_disk_extensions

    ; --- Extended Disk Read ---
    mov [extension_dap.address], eax
    mov [extension_dap.segment], es
    mov [extension_dap.offset], bx
    mov [extension_dap.count], cl

    mov ah, 0x42
    mov si, extension_dap
    mov di, 3         ; Set retry count

.ext_retry:
    pusha           ; Save all registers (BIOS call may modify them)
    stc             ; Set carry flag (some BIOSes require this)
    int 13h         ; Extended disk read
    jnc .ext_done   ; Jump if successful (carry flag clear)
    popa
    call disk_reset
    dec di
    cmp di, 0
    jne .ext_retry
    jmp floppy_error

.ext_done:
    popa
    jmp .function_end

.no_disk_extensions:
    ; --- Standard Disk Read (Fallback) ---
    mov esi, eax         ; Save LBA address in ESI
    mov di, cx           ; Outer loop count: number of sectors to read
.outer_loop:
    mov eax, esi
    call lba_to_chs      ; Convert current LBA to CHS address
    mov al, 1            ; Always read one sector at a time

    push di             ; Save outer loop sector count
    mov di, 3           ; Inner loop: set retry count for this sector
    mov ah, 02h         ; BIOS standard disk read function
.inner_loop:
    pusha             ; Save registers (BIOS may modify them)
    stc               ; Set carry flag
    int 13h           ; Attempt to read one sector
    jnc .inner_success; If read is successful, jump out of inner loop
    popa
    dec di            ; Decrement retry count
    cmp di, 0
    jne .inner_loop   ; Retry if count not exhausted
    jmp floppy_error ; If all retries fail, jump to error handler

.inner_success:
    popa              ; Restore registers after successful read
    pop di            ; Retrieve outer loop sector count into DI
    cmp di, 0
    je .function_end  ; All sectors read; exit function

    inc esi           ; Move to the next LBA
    dec di            ; Decrement outer loop sector count
    ; Increment destination address by one sector (512 bytes / 16 = 32 words)
    mov ax, es
    add ax, 32
    mov es, ax
    jmp .outer_loop

.function_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop eax
    ret

;-------------------------------------------------------------------------
; Function: disk_reset
; Description: Resets the disk drive using BIOS interrupt 13h.
; Input: DL contains the drive number.
;-------------------------------------------------------------------------
disk_reset:
    pusha
    mov ah, 00h
    stc
    int 13h
    jc floppy_error
    popa
    ret

;-------------------------------------------------------------------------
; Function: floppy_error
; Description: Handles disk errors by printing an error message and halting.
;-------------------------------------------------------------------------
floppy_error:
    mov si, floppy_error_message
    call print_string
    cli
    hlt
    jmp floppy_error

;-------------------------------------------------------------------------
; Section: Data
; Description: Contains various data structures, boot table definitions,
;              and messages used by the bootloader.
;-------------------------------------------------------------------------
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

;-------------------------------------------------------------------------
; Section: BIOS Footer
;-------------------------------------------------------------------------
section bios_footer

;-------------------------------------------------------------------------
; Section: BSS
; Description: Uninitialized data (buffers and variables used at runtime).
;-------------------------------------------------------------------------
section .bss
    buffer: resb 512
    boot_table: resb 512
    partition_entry: resb 16
    disk_extended_present: resb 1
    entry_point:
        .offset: resw 1
        .segment: resw 1
