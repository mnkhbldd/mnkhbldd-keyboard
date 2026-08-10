/*
 * Copyright 2009 Odbayar Nyamtseren <odbayar.n@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef COMPOSER_H
#define COMPOSER_H

#include <string>
#include <unordered_set>
#include <vector>
#include "PlatformTypes.h"
#include "NonCopyable.h"
#include "InputContext.h"
#include "CompString.h"

class Composer : private NonCopyable
{
public:
    Composer();
    ~Composer();

    void finishComp(InputContext& imc, CompString& cs);
    void cancelComp(InputContext& imc, CompString& cs);

    BOOL processKey(InputContext& imc, UINT virtKey,
                    WCHAR charCode, CONST BYTE* keyState);

    void toAsciiEx(InputContext& imc, UINT virtKey,
                   WCHAR charCode, CONST BYTE* keyState);

protected:
    void addRule(const char* from, const char* to, DWORD flags);
    void computeRuleLengths();
    void exportConversionRules(const char* filename);
    bool isInputChar(WCHAR ch);

    void compToRead(CompString& cs);
    void readToComp(CompString& cs);

    static const DWORD x_ac = 0x0001u;
    static const DWORD x_m  = 0x0002u;
    static const DWORD x_f  = 0x0004u;
    static const DWORD x_mm = 0x0008u;
    static const DWORD x_mf = 0x0010u;

    struct ConversionRule
    {
        std::basic_string<WCHAR> from;
        std::basic_string<WCHAR> to;
        DWORD flags;
    };

    struct Hash
    {
        size_t operator()(const ConversionRule& rule) const
        {
            size_t ret = 0;
            for (std::basic_string<WCHAR>::const_iterator iter = rule.from.begin();
                 iter != rule.from.end(); ++iter)
            {
                ret = (ret << 4) + *iter;
                if (size_t tmp = (ret & 0xf0000000)) {
                    ret = ret ^ (tmp >> 24);
                    ret = ret ^ tmp;
                }
            }
            return ret;
        }
    };

    struct Pred
    {
        bool operator()(const ConversionRule& a, const ConversionRule& b) const
        {
            return a.from == b.from;
        }
    };

    typedef std::unordered_multiset<ConversionRule, Hash, Pred> ConversionRuleSet;

    ConversionRuleSet rules_;
    std::vector<DWORD> ruleLengths_;
};

extern Composer* composer;

#endif // COMPOSER_H
