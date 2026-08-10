/*
 * Copyright 2012 Odbayar Nyamtseren <odbayar.n@gmail.com>
 */

#include <stdio.h>
#include <stdarg.h>
#include "HelperFunctions.h"

void logToFile(const char* format, ...)
{
#ifdef DEBUG
    FILE* fp = fopen("/tmp/buuz.log", "a");
    if (!fp)
        return;
    va_list args;
    va_start(args, format);
    vfprintf(fp, format, args);
    va_end(args);
    fputc('\n', fp);
    fclose(fp);
#else
    (void)format;
#endif
}
