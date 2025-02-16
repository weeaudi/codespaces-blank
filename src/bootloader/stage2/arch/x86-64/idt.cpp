/**
 * @file idt.cpp
 * @author Aidcraft
 * @brief x86 file for interrupt descriptor table
 * @version 0.0.2
 * @date 2025-01-27
 * 
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 * 
 */

#include "idt.h"
#include "../../stdio.h"
#include "pic.h"

__attribute__((aligned(0x10))) 
/// @brief the interrupt descriptor table
static idt_entry_t idt[IDT_MAX_ENTRIES];

/// @brief the interrupt descriptor table header
static idtr_t idtr;

extern "C" void __attribute__((noreturn)) exception_handler() {
    __asm__ volatile ("cli; hlt"); // Completely hangs the computer
    while(1); // should never reach (for compiler warnings)
}

void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags) {
    idt_entry_t* descriptor = &idt[vector];

    descriptor->isr_low        = (uint64_t)isr & 0xFFFF;
    descriptor->kernel_cs      = GDT_OFFSET_KERNEL_CODE;
    descriptor->ist            = 0;
    descriptor->attributes     = flags;
    descriptor->isr_mid        = ((uint64_t)isr >> 16) & 0xFFFF;
    descriptor->isr_high       = ((uint64_t)isr >> 32) & 0xFFFFFFFF;
    descriptor->reserved       = 0;
}

static bool vectors[IDT_MAX_DESCRIPTORS];

/// @brief The table of error handlers
extern void* isr_stub_table[];

void idt_init() {
    remapPic(0x20, 0x28);
    pic_disable();
    idtr.base = (uint64_t)&idt[0];
    idtr.limit = (uint16_t)sizeof(idt_entry_t) * IDT_MAX_DESCRIPTORS - 1;

    for (uint8_t vector = 0; vector < 32; vector++) {
        idt_set_descriptor(vector, isr_stub_table[vector], 0x8E);
        vectors[vector] = true;
    }

    __asm__ volatile ("lidt %0" : : "m"(idtr)); // load the new IDT
    __asm__ volatile ("sti"); // set the interrupt flag
}