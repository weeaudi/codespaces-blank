#pragma once

extern "C" uint8_t inb(uint8_t port);
extern "C" void outb(uint8_t port, uint8_t data);

extern "C" uint16_t inw(uint8_t port);
extern "C" void outw(uint8_t port, uint16_t data);