/*
 * Quick smoke test for Composer conversion rules (no IMK required).
 * Usage: ./test_convert buuz
 */

#include <iostream>
#include <string>
#include "Composer.h"
#include "InputContext.h"
#include "CompString.h"

static std::string toUtf8(const WCHAR* data, DWORD len)
{
    std::string out;
    for (DWORD i = 0; i < len; ++i) {
        uint32_t cp = data[i];
        if (cp < 0x80) {
            out.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    return out;
}

int main(int argc, char** argv)
{
    composer = new Composer();
    InputContext imc;
    CompString cs(imc);
    cs.create();
    cs.lock();

    BYTE keyState[256] = {};
    const char* input = (argc > 1) ? argv[1] : "buuz id'ye";

    for (const char* p = input; *p; ++p) {
        unsigned char c = static_cast<unsigned char>(*p);
        if (c == ' ') {
            composer->finishComp(imc, cs);
            if (imc.prv()->pendingCommit) {
                std::cout << toUtf8(cs.resultStr.ptr(), cs.resultStr.size()) << ' ';
                cs.clearResult();
                imc.clearNotifications();
            }
            continue;
        }
        WCHAR ch = static_cast<WCHAR>(c);
        if (composer->processKey(imc, 0, ch, keyState))
            composer->toAsciiEx(imc, 0, ch, keyState);
    }

    if (cs.compStr.size() != 0) {
        composer->finishComp(imc, cs);
        std::cout << toUtf8(cs.resultStr.ptr(), cs.resultStr.size());
    }
    std::cout << std::endl;

    delete composer;
    return 0;
}
