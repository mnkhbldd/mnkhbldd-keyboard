/*
 * Measures autocorrect quality the way users hit it: sample real words,
 * spell them in Latin as a Buuz user would, add a Latin typo, run them
 * through the composer and autocorrect, and compare with the original.
 *
 * Usage: eval_spell DICT_DIR [WORDS] [SEED]
 */

#import <Foundation/Foundation.h>
#import "SpellChecker.h"

#include "CompString.h"
#include "Composer.h"
#include "InputContext.h"
#include "hunspell.hxx"

#include <cstdio>
#include <map>
#include <random>
#include <string>
#include <vector>

static NSString* latinFor(NSString* cyr)
{
    static NSDictionary<NSString*, NSString*>* map = @{
        @"а": @"a", @"б": @"b", @"в": @"v", @"г": @"g", @"д": @"d",
        @"е": @"ye", @"ё": @"yo", @"ж": @"j", @"з": @"z", @"и": @"i",
        @"й": @"i", @"к": @"k", @"л": @"l", @"м": @"m", @"н": @"n",
        @"о": @"o", @"ө": @"o", @"п": @"p", @"р": @"r", @"с": @"s",
        @"т": @"t", @"у": @"u", @"ү": @"u", @"ф": @"f", @"х": @"h",
        @"ц": @"c", @"ч": @"ch", @"ш": @"sh", @"щ": @"sxc", @"ъ": @"\"",
        @"ы": @"y", @"ь": @"'", @"э": @"e", @"ю": @"yu", @"я": @"ya",
    };
    NSMutableString* out = [NSMutableString string];
    for (NSUInteger i = 0; i < cyr.length; ++i) {
        NSString* ch = [cyr substringWithRange:NSMakeRange(i, 1)];
        NSString* lat = map[ch];
        if (!lat)
            return nil;
        // "sh" and "ch" would merge into ш / ч.
        if ([lat isEqualToString:@"h"] && ([out hasSuffix:@"s"] || [out hasSuffix:@"c"]))
            lat = @"kh";
        [out appendString:lat];
    }
    return out;
}

static NSString* convert(NSString* latin)
{
    static InputContext* imc = [] {
        auto* c = new InputContext();
        CompString cs(*c);
        cs.create();
        return c;
    }();
    BYTE keyState[256] = {};
    CompString cs(*imc);
    cs.lock();
    for (NSUInteger i = 0; i < latin.length; ++i) {
        WCHAR ch = [latin characterAtIndex:i];
        if (composer->processKey(*imc, 0, ch, keyState))
            composer->toAsciiEx(*imc, 0, ch, keyState);
    }
    composer->finishComp(*imc, cs);
    NSString* out = [[NSString alloc] initWithCharacters:(const unichar*)cs.resultStr.ptr()
                                                  length:cs.resultStr.size()];
    cs.clearResult();
    imc->clearNotifications();
    return out;
}

static const char* kRows[] = {"qwertyuiop", "asdfghjkl", "zxcvbnm"};

static std::string neighbors(char c)
{
    std::string out;
    for (int r = 0; r < 3; ++r) {
        const char* p = strchr(kRows[r], c);
        if (!p)
            continue;
        int col = (int)(p - kRows[r]);
        for (int dr = -1; dr <= 1; ++dr) {
            int rr = r + dr;
            if (rr < 0 || rr > 2)
                continue;
            for (int dc = -1; dc <= 1; ++dc) {
                int cc = col + dc;
                if ((dr == 0 && dc == 0) || cc < 0 || cc >= (int)strlen(kRows[rr]))
                    continue;
                out.push_back(kRows[rr][cc]);
            }
        }
    }
    return out;
}

static NSString* typo(NSString* latin, std::mt19937& rng, NSString** kind)
{
    std::string s(latin.UTF8String);
    std::vector<size_t> letters;
    for (size_t i = 0; i < s.size(); ++i)
        if (isalpha((unsigned char)s[i]))
            letters.push_back(i);
    if (letters.size() < 2)
        return nil;
    size_t i = letters[rng() % letters.size()];
    switch (rng() % 4) {
    case 0: {
        std::string nb = neighbors(s[i]);
        if (nb.empty())
            return nil;
        s[i] = nb[rng() % nb.size()];
        *kind = @"adjacent";
        break;
    }
    case 1:
        s.erase(i, 1);
        *kind = @"dropped";
        break;
    case 2:
        s.insert(i, 1, s[i]);
        *kind = @"doubled";
        break;
    default:
        if (i + 1 >= s.size() || s[i] == s[i + 1])
            return nil;
        std::swap(s[i], s[i + 1]);
        *kind = @"swapped";
        break;
    }
    return [NSString stringWithUTF8String:s.c_str()];
}

struct Tally {
    int fixed = 0, wrong = 0, unchanged = 0;
    int total() const { return fixed + wrong + unchanged; }
};

int main(int argc, char** argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: eval_spell DICT_DIR [WORDS] [SEED]\n");
            return 2;
        }
        NSString* dir = [NSString stringWithUTF8String:argv[1]];
        int wanted = argc > 2 ? atoi(argv[2]) : 3000;
        std::mt19937 rng(argc > 3 ? (unsigned)atoi(argv[3]) : 7);

        composer = new Composer();
        SpellChecker* checker = [[SpellChecker alloc] init];
        if (![checker loadFromDirectory:dir])
            return 1;
        NSString* aff = [dir stringByAppendingPathComponent:@"mn_MN.aff"];
        NSString* dic = [dir stringByAppendingPathComponent:@"mn_MN.dic"];
        Hunspell hun(aff.fileSystemRepresentation, dic.fileSystemRepresentation);

        NSString* freqText = [NSString stringWithContentsOfFile:
            [dir stringByAppendingPathComponent:@"mn_freq.txt"]
            encoding:NSUTF8StringEncoding error:nil];
        // RARE=1 samples words the corpus has seen only a few times, closer to
        // what a frequency list cannot vouch for.
        NSUInteger lo = getenv("RARE") ? 30000 : 0, hi = getenv("RARE") ? 150000 : 30000;
        NSMutableArray<NSString*>* pool = [NSMutableArray array];
        NSUInteger rank = 0;
        for (NSString* line in [freqText componentsSeparatedByString:@"\n"]) {
            if (rank++ < lo)
                continue;
            if (rank > hi)
                break;
            NSString* w = [line componentsSeparatedByString:@"\t"].firstObject;
            if (w.length >= 3 && hun.spell(w.UTF8String))
                [pool addObject:w];
        }
        if (pool.count == 0) {
            fprintf(stderr, "no words to sample\n");
            return 1;
        }

        std::map<std::string, Tally> tallies;
        int cleanChanged = 0, cleanTotal = 0;
        NSMutableArray<NSString*>* wrongExamples = [NSMutableArray array];
        NSMutableArray<NSString*>* missExamples = [NSMutableArray array];

        auto judge = [&](const std::string& cat, NSString* expect, NSString* input) {
            if (hun.spell(input.UTF8String))
                return; // a real word; no spellchecker can know it was meant otherwise
            NSString* got = [checker maybeAutocorrect:input];
            Tally& t = tallies[cat];
            if ([got isEqualToString:expect]) {
                ++t.fixed;
            } else if ([got isEqualToString:input]) {
                ++t.unchanged;
                if (missExamples.count < 25)
                    [missExamples addObject:[NSString stringWithFormat:@"%@ %@ (want %@)",
                        @(cat.c_str()), input, expect]];
            } else {
                ++t.wrong;
                if (wrongExamples.count < 40)
                    [wrongExamples addObject:[NSString stringWithFormat:@"%@ %@ -> %@ (want %@)",
                        @(cat.c_str()), input, got, expect]];
            }
        };

        NSDate* start = [NSDate date];
        int calls = 0;
        for (int n = 0; n < wanted; ++n) {
            NSString* word = pool[rng() % pool.count];
            NSString* latin = latinFor(word);
            if (!latin)
                continue;
            NSString* conv = convert(latin);
            if ([conv isEqualToString:word]) {
                ++cleanTotal;
                ++calls;
                if (![[checker maybeAutocorrect:conv] isEqualToString:word])
                    ++cleanChanged;
            } else {
                ++calls;
                judge("harmony", word, conv);
            }
            for (int k = 0; k < 2; ++k) {
                NSString* kind = nil;
                NSString* bad = typo(latin, rng, &kind);
                if (!bad)
                    continue;
                NSString* badConv = convert(bad);
                if ([badConv isEqualToString:word])
                    continue;
                ++calls;
                judge(kind.UTF8String, word, badConv);
            }
        }
        double elapsed = -[start timeIntervalSinceNow];

        Tally all;
        printf("%-9s %6s %7s %7s %9s\n", "case", "n", "fixed", "wrong", "unchanged");
        for (auto& [cat, t] : tallies) {
            printf("%-9s %6d %6.1f%% %6.1f%% %8.1f%%\n", cat.c_str(), t.total(),
                   100.0 * t.fixed / t.total(), 100.0 * t.wrong / t.total(),
                   100.0 * t.unchanged / t.total());
            all.fixed += t.fixed;
            all.wrong += t.wrong;
            all.unchanged += t.unchanged;
        }
        printf("%-9s %6d %6.1f%% %6.1f%% %8.1f%%\n", "ALL", all.total(),
               100.0 * all.fixed / all.total(), 100.0 * all.wrong / all.total(),
               100.0 * all.unchanged / all.total());
        printf("correct words changed: %d / %d\n", cleanChanged, cleanTotal);
        printf("avg %.2f ms per word\n", 1000.0 * elapsed / std::max(calls, 1));

        if (getenv("SHOW")) {
            printf("\nwrong:\n");
            for (NSString* s in wrongExamples)
                printf("  %s\n", s.UTF8String);
            printf("\nmissed:\n");
            for (NSString* s in missExamples)
                printf("  %s\n", s.UTF8String);
        }
        return 0;
    }
}
