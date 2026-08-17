#import "SpellChecker.h"

#include "hunspell.hxx"

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

@implementation SpellChecker
{
    std::unique_ptr<Hunspell> _hunspell;
}

+ (instancetype)shared
{
    static SpellChecker* instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[SpellChecker alloc] init];
        NSString* dir = [[[NSBundle mainBundle] resourcePath]
            stringByAppendingPathComponent:@"dict"];
        [instance loadFromDirectory:dir];
    });
    return instance;
}

- (BOOL)loadFromDirectory:(NSString*)directory
{
    NSString* aff = [directory stringByAppendingPathComponent:@"mn_MN.aff"];
    NSString* dic = [directory stringByAppendingPathComponent:@"mn_MN.dic"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:aff] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:dic]) {
        NSLog(@"[Buuz] spell dictionary missing at %@", directory);
        _hunspell.reset();
        return NO;
    }
    try {
        _hunspell.reset(new Hunspell(aff.fileSystemRepresentation,
                                     dic.fileSystemRepresentation));
    } catch (...) {
        NSLog(@"[Buuz] failed to load Hunspell dictionary");
        _hunspell.reset();
        return NO;
    }
    NSLog(@"[Buuz] Hunspell dictionary loaded from %@", directory);
    return YES;
}

static BOOL isEligibleWord(NSString* word)
{
    if (word.length < 2)
        return NO;
    NSCharacterSet* letters = [NSCharacterSet letterCharacterSet];
    for (NSUInteger i = 0; i < word.length; ++i) {
        unichar c = [word characterAtIndex:i];
        if (![letters characterIsMember:c])
            return NO;
    }
    return YES;
}

static int levenshtein(NSString* a, NSString* b)
{
    const NSUInteger n = a.length;
    const NSUInteger m = b.length;
    if (n == 0)
        return (int)m;
    if (m == 0)
        return (int)n;

    std::vector<int> prev(m + 1), cur(m + 1);
    for (NSUInteger j = 0; j <= m; ++j)
        prev[j] = (int)j;

    for (NSUInteger i = 1; i <= n; ++i) {
        cur[0] = (int)i;
        unichar ca = [a characterAtIndex:i - 1];
        for (NSUInteger j = 1; j <= m; ++j) {
            unichar cb = [b characterAtIndex:j - 1];
            int cost = (ca == cb) ? 0 : 1;
            cur[j] = std::min({prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost});
        }
        prev.swap(cur);
    }
    return prev[m];
}

static BOOL isAllUppercase(NSString* word)
{
    NSCharacterSet* upper = [NSCharacterSet uppercaseLetterCharacterSet];
    BOOL anyLetter = NO;
    for (NSUInteger i = 0; i < word.length; ++i) {
        unichar c = [word characterAtIndex:i];
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c]) {
            anyLetter = YES;
            if (![upper characterIsMember:c])
                return NO;
        }
    }
    return anyLetter;
}

static NSString* applyCase(NSString* original, NSString* suggestion)
{
    if (suggestion.length == 0)
        return suggestion;
    if (isAllUppercase(original))
        return suggestion.uppercaseString;
    unichar first = [original characterAtIndex:0];
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:first]) {
        NSString* head = [[suggestion substringToIndex:1] uppercaseString];
        NSString* tail = suggestion.length > 1
            ? [[suggestion substringFromIndex:1] lowercaseString]
            : @"";
        return [head stringByAppendingString:tail];
    }
    return suggestion;
}

- (NSString*)maybeAutocorrect:(NSString*)word
{
    if (!_hunspell || !word || !isEligibleWord(word))
        return word;

    std::string utf8(word.UTF8String ? word.UTF8String : "");
    if (utf8.empty())
        return word;

    if (_hunspell->spell(utf8))
        return word;

    std::vector<std::string> suggestions = _hunspell->suggest(utf8);
    if (suggestions.empty())
        return word;

    NSString* chosen = nil;
    if (suggestions.size() == 1) {
        chosen = [NSString stringWithUTF8String:suggestions[0].c_str()];
    } else {
        int closeCount = 0;
        NSString* close = nil;
        for (const auto& s : suggestions) {
            NSString* cand = [NSString stringWithUTF8String:s.c_str()];
            if (!cand)
                continue;
            if (levenshtein(word, cand) <= 1) {
                closeCount++;
                close = cand;
            }
        }
        if (closeCount == 1)
            chosen = close;
    }

    if (!chosen || chosen.length == 0 || [chosen isEqualToString:word])
        return word;

    return applyCase(word, chosen);
}

@end
