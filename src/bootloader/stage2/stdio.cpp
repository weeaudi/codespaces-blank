/**
 * @file stdio.cpp
 * @author Aidcraft
 * @brief some io functions
 * @version 0.0.2
 * @date 2025-01-27
 * 
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 * 
 */

#include "stdio.h"

/// @brief Width of the screen
#define SCREEN_WIDTH 80
/// @brief Height of the screen
#define SCREEN_HEIGHT 25
/// @brief pointer to the screen
uint8_t* screen_buffer = (uint8_t*)0xB8000;
/// @brief x cursor
int screen_x = 0;
/// @brief y cursor
int screen_y = 0;

void clear_screen() {
    for (int i = 0; i < SCREEN_HEIGHT; i++) {
        for (int j = 0; j < SCREEN_WIDTH; j++) {
            putchr(j, i, ' ');
        }
    }
}

void putchr(int x, int y, char c) {
    screen_buffer[2 * (y * SCREEN_WIDTH + x)] = c;
}

void putc(char c) {
    if (c == '\n') {
        // Move to the next line
        screen_x = 0;
        screen_y++;
    } else if (c == '\r') {
        // Carriage return (move to the start of the current line)
        screen_x = 0;
    } else {
        // Write the character to the screen buffer
        if (screen_x < SCREEN_WIDTH && screen_y < SCREEN_HEIGHT) {
            putchr(screen_x, screen_y, c);
            screen_x++; // Move cursor to the right
        }
    }

    // Handle line wrapping
    if (screen_x >= SCREEN_WIDTH) {
        screen_x = 0;
        screen_y++;
    }

    // Handle scrolling (if cursor moves beyond the screen height)
    if (screen_y >= SCREEN_HEIGHT) {
        // Scroll the screen up by 1 line
        for (int i = 1; i < SCREEN_HEIGHT; i++) {
            for (int j = 0; j < SCREEN_WIDTH; j++) {
                putchr(j, i - 1, screen_buffer[2 * (i * SCREEN_WIDTH + j)]);
            }
        }

        // Clear the last line
        for (int j = 0; j < SCREEN_WIDTH; j++) {
            putchr(j, SCREEN_HEIGHT - 1, ' ');
        }

        screen_y = SCREEN_HEIGHT - 1; // Keep cursor on the last line
    }
}

void puts(const char* str) {

    while(*str){
        putc(*str);
        str++;
    }
}

void printf(const char* fmt, ...) {

}

void print_buffer(const char* msg, const void* buffer, uint32_t length) {

}
