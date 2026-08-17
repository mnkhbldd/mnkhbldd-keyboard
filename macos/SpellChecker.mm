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

// Latin input cannot distinguish these Cyrillic pairs, so the composer has to
// guess; a same-length suggestion that only swaps within a pair fixes the guess.
static int confusableGroup(unichar c)
{
    switch (c) {
    case 0x0443: case 0x04AF: return 1; // у ү
    case 0x043E: case 0x04E9: return 2; // о ө
    case 0x044D: case 0x0435: return 3; // э е
    case 0x0438: case 0x044B: return 4; // и ы
    default: return 0;
    }
}

static NSString* vowelVariant(NSString* word, NSArray<NSString*>* candidates)
{
    NSString* match = nil;
    for (NSString* cand in candidates) {
        if (cand.length != word.length)
            continue;
        BOOL ok = YES;
        BOOL differs = NO;
        for (NSUInteger i = 0; i < word.length && ok; ++i) {
            unichar a = [word characterAtIndex:i];
            unichar b = [cand characterAtIndex:i];
            if (a == b)
                continue;
            differs = YES;
            int g = confusableGroup(a);
            ok = (g != 0 && g == confusableGroup(b));
        }
        if (!ok || !differs)
            continue;
        if (match && ![match isEqualToString:cand])
            return nil;
        match = cand;
    }
    return match;
}

// Held-down or stuttered keys produce a doubled letter; dropping one copy is
// only accepted when Hunspell independently proposes the result.
static NSString* undoubledVariant(NSString* word, NSArray<NSString*>* candidates)
{
    NSMutableSet<NSString*>* shortened = [NSMutableSet set];
    for (NSUInteger i = 1; i < word.length; ++i) {
        if ([word characterAtIndex:i] != [word characterAtIndex:i - 1])
            continue;
        NSMutableString* s = [word mutableCopy];
        [s deleteCharactersInRange:NSMakeRange(i, 1)];
        [shortened addObject:s];
    }
    if (shortened.count == 0)
        return nil;

    NSString* match = nil;
    for (NSString* cand in candidates) {
        if (![shortened containsObject:cand])
            continue;
        if (match && ![match isEqualToString:cand])
            return nil;
        match = cand;
    }
    return match;
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

    NSString* lower = word.lowercaseString;
    NSMutableArray<NSString*>* candidates = [NSMutableArray array];
    for (const auto& s : _hunspell->suggest(utf8)) {
        NSString* cand = [NSString stringWithUTF8String:s.c_str()];
        if (cand.length == 0 || !isEligibleWord(cand))
            continue; // drops multi-word splits such as "ном юм"
        cand = cand.lowercaseString;
        if (![cand isEqualToString:lower])
            [candidates addObject:cand];
    }
    if (candidates.count == 0)
        return word;

    NSString* chosen = vowelVariant(lower, candidates);
    if (!chosen)
        chosen = undoubledVariant(lower, candidates);
    if (!chosen && candidates.count == 1 && levenshtein(lower, candidates[0]) <= 1)
        chosen = candidates[0];

    if (!chosen)
        return word;

    return applyCase(word, chosen);
}

@end
