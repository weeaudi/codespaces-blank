#pragma once
#include "stdint.h"

/// @brief clears the screen
void clear_screen();

/**
 * @brief puts c on the screen at x, y
 * 
 * @param[in] x x pos for c
 * @param[in] y y pos for c
 * @param[in] c the charecter to put to the screen
 */
void putchr(int x, int y, char c);

/**
 * @brief puts c at the screen at the next point
 * 
 * @param[in] c the charecter to put to the screen 
 */
void putc(char c);

/**
 * @brief puts a null terminated string to the screen
 * 
 * @param[in] str null terminated string to print 
 */
void puts(const char* str);

/**
 * @brief 
 * 
 * @todo Implement function
 * 
 * @param[in] fmt 
 * @param[in] ... 
 */
void printf(const char* fmt, ...);

/**
 * @brief 
 * 
 * @todo Implement function
 * 
 * @param[in] msg 
 * @param[in] buffer 
 * @param[in] length 
 */
void print_buffer(const char* msg, const void* buffer, uint32_t length);