/*
 * Buuz macOS Input Method — ImeInterface equivalent (IMKInputController)
 *
 * Uses inputText:key:modifiers:client: (classic IMK path). handleEvent alone
 * is unreliable on newer macOS and can swallow keys without inserting them.
 */

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#include "Composer.h"
#include "InputContext.h"
#include "CompString.h"
#include "PlatformTypes.h"
#import "SpellChecker.h"

@interface BuuzInputController : IMKInputController
@end

@implementation BuuzInputController
{
    InputContext* _imc;
    BYTE _keyState[256];
    // Last autocorrection, revertible by an immediate Backspace once the
    // character that triggered it (_undoSuffix) has been inserted.
    NSString* _undoTyped;
    NSString* _undoCorrected;
    NSString* _undoSuffix;
}

- (id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)client
{
    self = [super initWithServer:server delegate:delegate client:client];
    if (self) {
        _imc = new InputContext();
        CompString cs(*_imc);
        cs.create();
        memset(_keyState, 0, sizeof(_keyState));
        NSLog(@"[Buuz] controller init");
    }
    return self;
}

- (void)dealloc
{
    delete _imc;
    _imc = nullptr;
}

static NSRange NotFoundRange(void)
{
    return NSMakeRange(NSNotFound, NSNotFound);
}

static NSString* utf16ToNSString(const WCHAR* data, DWORD len)
{
    if (!data || len == 0)
        return @"";
    return [[NSString alloc] initWithCharacters:(const unichar*)data length:len];
}

- (id)activeClient:(id)sender
{
    if (sender)
        return sender;
    return [self client];
}

- (void)insertPlainText:(NSString*)text client:(id)client
{
    if (text.length == 0 || !client)
        return;
    [client insertText:text replacementRange:NotFoundRange()];
}

- (void)clearMarkedText:(id)client
{
    if (!client)
        return;
    [client setMarkedText:@""
           selectionRange:NSMakeRange(0, 0)
         replacementRange:NotFoundRange()];
}

- (void)applyComposerResult:(id)client
{
    if (!_imc || !composer)
        return;

    InputContext::PrivateData* prv = _imc->prv();
    CompString cs(*_imc);
    if (!cs.lock())
        return;

    if (prv->pendingCommit) {
        NSString* result = utf16ToNSString(cs.resultStr.ptr(), cs.resultStr.size());
        NSString* corrected = [[SpellChecker shared] maybeAutocorrect:result];
        if (![corrected isEqualToString:result]) {
            _undoTyped = result;
            _undoCorrected = corrected;
        }
        [self clearMarkedText:client];
        [self insertPlainText:corrected client:client];
        cs.clearResult();
    } else if (prv->pendingCancel) {
        [self clearMarkedText:client];
    } else if (prv->pendingUpdate) {
        NSString* marked = utf16ToNSString(cs.compStr.ptr(), cs.compStr.size());
        NSInteger cursor = (NSInteger)cs.cursorPos();
        if (cursor < 0)
            cursor = 0;
        if (cursor > (NSInteger)marked.length)
            cursor = (NSInteger)marked.length;

        if (marked.length == 0) {
            [self clearMarkedText:client];
        } else {
            NSDictionary* attrs = @{
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
            };
            NSAttributedString* attr =
                [[NSAttributedString alloc] initWithString:marked attributes:attrs];
            [client setMarkedText:attr
                   selectionRange:NSMakeRange((NSUInteger)cursor, 0)
                 replacementRange:NotFoundRange()];
        }
    }

    _imc->clearNotifications();
}

- (void)updateKeyStateFromModifiers:(NSUInteger)flags
{
    _keyState[VK_SHIFT]   = (flags & NSEventModifierFlagShift) ? 0x80 : 0;
    _keyState[VK_CAPITAL] = (flags & NSEventModifierFlagCapsLock) ? 0x01 : 0;
}

- (UINT)virtKeyFromKeyCode:(NSInteger)keyCode
{
    switch (keyCode) {
    case 51:  return VK_BACK;
    case 117: return VK_DELETE;
    case 123: return VK_LEFT;
    case 124: return VK_RIGHT;
    case 115: return VK_HOME;
    case 119: return VK_END;
    case 56:
    case 60:  return VK_SHIFT;
    case 57:  return VK_CAPITAL;
    default:  return 0;
    }
}

- (WCHAR)charCodeFromString:(NSString*)string
{
    if (string.length == 0)
        return 0;
    unichar ch = [string characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '\'' || ch == '"')
        return (WCHAR)ch;
    return 0;
}

- (void)clearUndo
{
    _undoTyped = nil;
    _undoCorrected = nil;
    _undoSuffix = nil;
}

// Replaces "<corrected><suffix>" before the caret with what the user typed,
// but only after reading it back from the client, so an app that moved the
// caret or cannot report its text just gets a normal Backspace.
- (BOOL)revertCorrection:(NSString*)typed
               corrected:(NSString*)corrected
                  suffix:(NSString*)suffix
                  client:(id)client
{
    NSString* expected = [corrected stringByAppendingString:suffix];
    NSRange sel = [client selectedRange];
    if (sel.location == NSNotFound || sel.length != 0 || sel.location < expected.length)
        return NO;
    NSRange range = NSMakeRange(sel.location - expected.length, expected.length);
    NSString* actual = [[client attributedSubstringFromRange:range] string];
    if (![actual isEqualToString:expected])
        return NO;
    [client insertText:typed replacementRange:range];
    [[SpellChecker shared] learnWord:typed];
    return YES;
}

// Ctrl+Shift+M: autocorrect every word in the selection. Ctrl+Option is
// VoiceOver's modifier and what window managers bind; Ctrl+Shift is free.
// Apps that cannot report the selected text get a beep instead of a blind
// replacement.
- (void)fixSelection:(id)client
{
    if ([self isComposing])
        [self commitIfNeeded:client];
    [self clearUndo];

    NSRange sel = [client selectedRange];
    if (sel.location == NSNotFound || sel.length == 0) {
        NSBeep();
        return;
    }
    NSString* text = [[client attributedSubstringFromRange:sel] string];
    if (text.length != sel.length) {
        NSBeep();
        return;
    }
    NSString* fixed = [[SpellChecker shared] autocorrectText:text];
    if (![fixed isEqualToString:text])
        [client insertText:fixed replacementRange:sel];
}

- (BOOL)isComposing
{
    if (!_imc)
        return NO;
    CompString cs(*_imc);
    return cs.lock() && cs.compStr.size() != 0;
}

- (BOOL)commitIfNeeded:(id)client
{
    if (![self isComposing] || !composer)
        return NO;
    CompString cs(*_imc);
    if (!cs.lock())
        return NO;
    composer->finishComp(*_imc, cs);
    [self applyComposerResult:client];
    return YES;
}

// Primary IMK entry point on modern macOS.
- (BOOL)inputText:(NSString*)string
              key:(NSInteger)keyCode
        modifiers:(NSUInteger)flags
           client:(id)sender
{
    id client = [self activeClient:sender];
    NSLog(@"[Buuz] inputText string=%@ key=%ld mods=%lu", string, (long)keyCode, (unsigned long)flags);

    if (!composer || !_imc) {
        if (string.length > 0) {
            [self insertPlainText:string client:client];
            return YES;
        }
        return NO;
    }

    NSString* undoTyped = _undoTyped;
    NSString* undoCorrected = _undoCorrected;
    NSString* undoSuffix = _undoSuffix;
    [self clearUndo];

    NSUInteger mods = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    const NSUInteger chord = NSEventModifierFlagCommand | NSEventModifierFlagControl |
                             NSEventModifierFlagOption | NSEventModifierFlagShift;
    if (keyCode == 46 &&
        (mods & chord) == (NSEventModifierFlagControl | NSEventModifierFlagShift)) {
        [self fixSelection:client];
        return YES;
    }
    if (mods & (NSEventModifierFlagCommand | NSEventModifierFlagControl))
        return NO;

    if (keyCode == 51 && undoSuffix && ![self isComposing] &&
        [self revertCorrection:undoTyped corrected:undoCorrected suffix:undoSuffix client:client])
        return YES;

    [self updateKeyStateFromModifiers:flags];

    UINT virtKey = [self virtKeyFromKeyCode:keyCode];
    WCHAR charCode = [self charCodeFromString:string];

    // Latin letters / quote → convert via Composer (same as Windows IME).
    if (charCode != 0 && composer->processKey(*_imc, virtKey, charCode, _keyState)) {
        _imc->clearNotifications();
        composer->toAsciiEx(*_imc, virtKey, charCode, _keyState);
        [self applyComposerResult:client];
        return YES;
    }

    // Backspace / arrows while composing.
    if (virtKey != 0 && [self isComposing] &&
        composer->processKey(*_imc, virtKey, 0, _keyState)) {
        _imc->clearNotifications();
        composer->toAsciiEx(*_imc, virtKey, 0, _keyState);
        [self applyComposerResult:client];
        return YES;
    }

    // Any other key while composing → commit first, then insert the key.
    if ([self isComposing])
        [self commitIfNeeded:client];

    // Return / Enter must be handed to the app (insertNewline:). Inserting
    // "\r" via insertText often does nothing; Cmd+Enter worked only because
    // Command modifiers already returned NO above.
    if (keyCode == 36 || keyCode == 76)
        return NO;

    // Backspace / navigation when not composing → let the app handle it.
    if (virtKey == VK_BACK || virtKey == VK_DELETE ||
        virtKey == VK_LEFT || virtKey == VK_RIGHT ||
        virtKey == VK_HOME || virtKey == VK_END ||
        virtKey == VK_SHIFT || virtKey == VK_CAPITAL) {
        return NO;
    }

    // Space, digits, punctuation, etc. — must insert ourselves.
    // Do not insert \r/\n here; Return is handled above / via insertNewline:.
    if (string.length > 0) {
        unichar ch = [string characterAtIndex:0];
        if (ch == '\r' || ch == '\n')
            return NO;
        if (ch >= 0x20 || ch == '\t') {
            [self insertPlainText:string client:client];
            if (_undoCorrected)
                _undoSuffix = string;
            return YES;
        }
    }

    return NO;
}

- (BOOL)didCommandBySelector:(SEL)aSelector client:(id)sender
{
    // Commit composition, then let newline/tab reach the client.
    if (aSelector == @selector(insertNewline:) ||
        aSelector == @selector(insertTab:) ||
        aSelector == @selector(cancelOperation:)) {
        id client = [self activeClient:sender];
        if ([self isComposing]) {
            if (aSelector == @selector(cancelOperation:)) {
                CompString cs(*_imc);
                if (cs.lock() && composer) {
                    composer->cancelComp(*_imc, cs);
                    [self applyComposerResult:client];
                }
                return YES;
            }
            [self commitIfNeeded:client];
        }
        return NO; // let newline/tab still happen
    }
    return NO;
}

- (void)commitComposition:(id)sender
{
    [self commitIfNeeded:[self activeClient:sender]];
    [self clearUndo];
}

- (void)activateServer:(id)sender
{
    NSLog(@"[Buuz] activateServer");
    if (_imc)
        _imc->get()->fOpen = true;
}

- (void)deactivateServer:(id)sender
{
    NSLog(@"[Buuz] deactivateServer");
    [self clearUndo];
    if (!_imc)
        return;
    if ([self isComposing] && composer) {
        CompString cs(*_imc);
        if (cs.lock()) {
            composer->cancelComp(*_imc, cs);
            [self applyComposerResult:[self activeClient:sender]];
        }
    }
    _imc->get()->fOpen = false;
}

@end
