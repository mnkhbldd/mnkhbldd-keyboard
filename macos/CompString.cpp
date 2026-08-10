/*
 * Copyright 2009-2012 Odbayar Nyamtseren <odbayar.n@gmail.com>
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
#include "CompString.h"

CompString::CompString(InputContext& imc)
  : imc_(imc),
    locked_(false)
{
}

CompString::~CompString()
{
    unlock();
}

bool CompString::lock()
{
    if (!locked_) {
        updateBufferWrappers();
        locked_ = true;
    }
    return true;
}

void CompString::unlock()
{
    locked_ = false;
}

bool CompString::create()
{
    std::memset(imc_.get(), 0, sizeof(InputContext::State));
    imc_->fOpen = true;
    updateBufferWrappers();
    return true;
}

void CompString::clearComp()
{
    setCursorPos(0);
    setDeltaStart(0);

    compReadAttr.resize(0);
    compReadClause.resize(0);
    compReadStr.resize(0);
    compAttr.resize(0);
    compClause.resize(0);
    compStr.resize(0);
}

void CompString::clearResult()
{
    resultReadClause.resize(0);
    resultReadStr.resize(0);
    resultClause.resize(0);
    resultStr.resize(0);
}

DWORD CompString::cursorPos()
{
    return imc_->cursorPos;
}

void CompString::setCursorPos(DWORD pos)
{
    imc_->cursorPos = pos;
}

DWORD CompString::deltaStart()
{
    return imc_->deltaStart;
}

void CompString::setDeltaStart(DWORD pos)
{
    imc_->deltaStart = pos;
}

void CompString::updateBufferWrappers()
{
    InputContext::State* s = imc_.get();

    compReadAttr.init(s->compReadAttr, &s->compReadAttrLen);
    compReadClause.init(s->compReadClause, &s->compReadClauseLen);
    compReadStr.init(s->compReadStr, &s->compReadStrLen);

    compAttr.init(s->compAttr, &s->compAttrLen);
    compClause.init(s->compClause, &s->compClauseLen);
    compStr.init(s->compStr, &s->compStrLen);

    resultReadClause.init(s->resultReadClause, &s->resultReadClauseLen);
    resultReadStr.init(s->resultReadStr, &s->resultReadStrLen);

    resultClause.init(s->resultClause, &s->resultClauseLen);
    resultStr.init(s->resultStr, &s->resultStrLen);
}

void CompString::updateCompReadClause()
{
    compReadClause.resize(0);
    compReadClause.append(0);
    DWORD currentAttr = compReadAttr[0];
    for (DWORD pos = 1; pos < compReadAttr.size(); ++pos) {
        if (compReadAttr[pos] != currentAttr) {
            currentAttr = compReadAttr[pos];
            compReadClause.append(pos);
        }
    }
    compReadClause.append(compReadAttr.size());
}

void CompString::updateCompClause()
{
    compClause.resize(0);
    compClause.append(0);
    DWORD currentAttr = compAttr[0];
    for (DWORD pos = 1; pos < compAttr.size(); ++pos) {
        if (compAttr[pos] != currentAttr) {
            currentAttr = compAttr[pos];
            compClause.append(pos);
        }
    }
    compClause.append(compAttr.size());
}

void CompString::updateResultReadClause()
{
    resultReadClause.resize(0);
    resultReadClause.append(0);
    resultReadClause.append(resultReadStr.size());
}

void CompString::updateResultClause()
{
    resultClause.resize(0);
    resultClause.append(0);
    resultClause.append(resultStr.size());
}
