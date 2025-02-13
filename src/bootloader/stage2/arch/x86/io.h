#pragma once

extern "C" uint8_t inb(uint16_t port);
extern "C" void outb(uint16_t port, uint8_t data);

extern "C" uint16_t inw(uint16_t port);
extern "C" void outw(uint16_t port, uint16_t data);