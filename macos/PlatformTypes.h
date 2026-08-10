/*
 * Platform type aliases so the Composer / CompString / InputContext
 * modules can keep the same structure as the Windows IMM build.
 */

#ifndef PLATFORM_TYPES_H
#define PLATFORM_TYPES_H

#include <cstdint>
#include <cstddef>

typedef char16_t WCHAR;
typedef uint8_t  BYTE;
typedef uint32_t DWORD;
typedef uint32_t UINT;
typedef uintptr_t WPARAM;
typedef intptr_t  LPARAM;

// Objective-C already defines BOOL as bool; keep Win32-style elsewhere.
#ifndef __OBJC__
typedef int BOOL;
#ifndef TRUE
#define TRUE  1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#endif

#ifndef CONST
#define CONST const
#endif

// Composition attribute (same meaning as IMM ATTR_INPUT)
#ifndef ATTR_INPUT
#define ATTR_INPUT 0x00
#endif

// Virtual-key codes used by Composer (subset of Win32 VK_*)
#ifndef VK_BACK
#define VK_BACK    0x08
#define VK_SHIFT   0x10
#define VK_CAPITAL 0x14
#define VK_END     0x23
#define VK_HOME    0x24
#define VK_LEFT    0x25
#define VK_RIGHT   0x27
#define VK_DELETE  0x2E
#endif

// IME notification messages (macOS InputContext maps these to actions)
#ifndef WM_IME_STARTCOMPOSITION
#define WM_IME_STARTCOMPOSITION 0x010D
#define WM_IME_ENDCOMPOSITION   0x010E
#define WM_IME_COMPOSITION      0x010F
#endif

#ifndef GCS_COMPREADSTR
#define GCS_COMPREADSTR   0x0001
#define GCS_COMPREADATTR  0x0002
#define GCS_COMPREADCLAUSE 0x0004
#define GCS_COMPSTR       0x0008
#define GCS_COMPATTR      0x0010
#define GCS_COMPCLAUSE    0x0020
#define GCS_CURSORPOS     0x0080
#define GCS_DELTASTART    0x0100
#define GCS_RESULTREADSTR 0x0200
#define GCS_RESULTREADCLAUSE 0x0400
#define GCS_RESULTSTR     0x0800
#define GCS_RESULTCLAUSE  0x1000
#endif

#endif // PLATFORM_TYPES_H
