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

#include <cstring>
#include "InputContext.h"

InputContext::InputContext()
  : locked_(false)
{
    std::memset(&state_, 0, sizeof(state_));
    std::memset(&prv_, 0, sizeof(prv_));
    state_.fOpen = true;
}

InputContext::~InputContext()
{
    unlock();
}

bool InputContext::lock()
{
    locked_ = true;
    return true;
}

void InputContext::unlock()
{
    locked_ = false;
}

void InputContext::clearNotifications()
{
    prv_.pendingCommit = false;
    prv_.pendingCancel = false;
    prv_.pendingUpdate = false;
}

bool InputContext::generateMessage(UINT message, WPARAM /*wParam*/, LPARAM lParam)
{
    switch (message) {
    case WM_IME_STARTCOMPOSITION:
        prv_.startedComposition = true;
        prv_.pendingUpdate = true;
        return true;
    case WM_IME_COMPOSITION:
        if (lParam & (GCS_RESULTSTR | GCS_RESULTREADSTR | GCS_RESULTCLAUSE | GCS_RESULTREADCLAUSE))
            prv_.pendingCommit = true;
        else
            prv_.pendingUpdate = true;
        return true;
    case WM_IME_ENDCOMPOSITION:
        if (!prv_.pendingCommit)
            prv_.pendingCancel = true;
        prv_.startedComposition = false;
        return true;
    default:
        return false;
    }
}
