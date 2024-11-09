/* Linker script for debugging the bootloader */

ENTRY(start)

SECTIONS
{
    /* Define the memory layout for the bootloader */

    /* The first 512 bytes for the bootloader */
    . = 0x7C00; /* Start address for the bootloader */

    .text : {
        *(.text) /* Include all text sections (code) */
    }

    .data : {
        *(.data) /* Include all data sections (initialized data) */
    }

    .bss : {
        *(.bss)  /* Include uninitialized data */
    }

    /* Place the debug information in its own section */
    .debug : {
        *(.debug) /* Include debug information */
    }

    /* Padding to reach the size of 512 bytes for bootloader sector */
    . = ALIGN(512);
    .boot_end : { *(.boot_end) }

    /* Reserved for the bootloader signature */
    . = 0x7FE0; /* Offset for the bootloader signature area */
    .boot_signature : {
        *(.boot_signature) /* Boot signature (0xAA55) */
    }
}
