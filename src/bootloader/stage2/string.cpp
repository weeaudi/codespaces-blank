#include "string.h"

bool strcmp(const char* str1, const char* str2)
{
    while (*str1 && *str2 && *str1 == *str2)
    {
        str1++;
        str2++;
    }

    return (uint8_t)*str1 - (uint8_t)*str2;
}

uint8_t strlen(const char* str)
{
    uint8_t len = 0;
    while (*str++)
        len++;
    return len;
}

char* strchr(const char* str, char c)
{
    while (*str)
    {
        if (*str == c)
            return (char*)str;
        str++;
    }
    return 0;
}

char toupper(char str)
{
    if (str >= 'a' && str <= 'z')
        return str + ('A' - 'a');
    return str;
}