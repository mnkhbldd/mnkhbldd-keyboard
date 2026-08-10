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

#ifndef INPUT_CONTEXT_H
#define INPUT_CONTEXT_H

#include "PlatformTypes.h"
#include "NonCopyable.h"

// Lightweight stand-in for Windows INPUTCONTEXT / HIMC.
// Composition string storage lives here (see CompString).
struct CompositionStorage;

class InputContext : private NonCopyable
{
public:
    struct State
    {
        bool fOpen;
        DWORD cursorPos;
        DWORD deltaStart;

        BYTE  compReadAttr[64];
        DWORD compReadAttrLen;
        DWORD compReadClause[4];
        DWORD compReadClauseLen;
        WCHAR compReadStr[64];
        DWORD compReadStrLen;

        BYTE  compAttr[64];
        DWORD compAttrLen;
        DWORD compClause[4];
        DWORD compClauseLen;
        WCHAR compStr[64];
        DWORD compStrLen;

        DWORD resultReadClause[4];
        DWORD resultReadClauseLen;
        WCHAR resultReadStr[64];
        DWORD resultReadStrLen;

        DWORD resultClause[4];
        DWORD resultClauseLen;
        WCHAR resultStr[64];
        DWORD resultStrLen;
    };

    struct PrivateData
    {
        bool startedComposition;
        bool pendingCommit;
        bool pendingCancel;
        bool pendingUpdate;
    };

    InputContext();
    ~InputContext();

    bool lock();
    void unlock();

    // Maps WM_IME_* messages from Composer into PrivateData flags.
    bool generateMessage(UINT message, WPARAM wParam, LPARAM lParam);

    State* operator->() { return &state_; }
    State* get() { return &state_; }
    PrivateData* prv() { return &prv_; }

    void clearNotifications();

private:
    State state_;
    PrivateData prv_;
    bool locked_;
};

#endif // INPUT_CONTEXT_H
