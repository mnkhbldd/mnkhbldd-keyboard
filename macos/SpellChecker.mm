#import "SpellChecker.h"

#include "hunspell.hxx"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {

using U16 = std::u16string;

const char16_t kAlphabet[] = u"абвгдеёжзийклмноөпрстуүфхцчшщъыьэюя";

// Tuned with `make eval-spell` (tools/eval_spell.mm). A candidate's score is
// ln(corpus count) - kTypoWeight * typoDistance, and it must carry
// kMinPosterior of the probability mass shared with the other candidates
// and the word as typed.
const double kTypoWeight = 0.6;
const double kVowelCost = 0.15;
const double kNearCost = 0.5;
const double kMinPosterior = 0.95;
const uint32_t kMinCandidateFreq = 8;
const uint32_t kMinUnvettedFreq = 60;
const uint32_t kAttestedTypedFreq = 40;
const uint32_t kExactDominance = 10;
const uint32_t kExactMinFreq = 1;
const uint32_t kUnseenFreq = 2;
const size_t kMaxVowelVariants = 64;

U16 toU16(NSString* s)
{
    U16 out(s.length, u'\0');
    [s getCharacters:(unichar*)out.data() range:NSMakeRange(0, s.length)];
    return out;
}

NSString* fromU16(const U16& s)
{
    return [NSString stringWithCharacters:(const unichar*)s.data() length:s.size()];
}

std::string toUtf8(const U16& s)
{
    return std::string(fromU16(s).UTF8String ?: "");
}

// Latin input cannot distinguish these Cyrillic pairs, so the composer has to
// guess from vowel harmony; swapping within a pair is the cheapest repair.
char16_t confusablePartner(char16_t c)
{
    switch (c) {
    case u'у': return u'ү';
    case u'ү': return u'у';
    case u'о': return u'ө';
    case u'ө': return u'о';
    case u'э': return u'е';
    case u'е': return u'э';
    case u'и': return u'ы';
    case u'ы': return u'и';
    default: return 0;
    }
}

// The Latin key a Cyrillic letter is typed with, for letters typed with one key.
char latinKey(char16_t c)
{
    static const char16_t cyr[] = u"абвгджзийклмноөпрстуүфхцыэ";
    static const char lat[] = "abvgdjziiklmnooprstuufhcye";
    for (int i = 0; cyr[i]; ++i)
        if (cyr[i] == c)
            return lat[i];
    return 0;
}

bool keysAdjacent(char a, char b)
{
    static const char* rows[] = {"qwertyuiop", "asdfghjkl", "zxcvbnm"};
    int ra = -1, ca = 0, rb = -1, cb = 0;
    for (int r = 0; r < 3; ++r) {
        if (const char* p = strchr(rows[r], a)) { ra = r; ca = (int)(p - rows[r]); }
        if (const char* p = strchr(rows[r], b)) { rb = r; cb = (int)(p - rows[r]); }
    }
    return ra >= 0 && rb >= 0 && std::abs(ra - rb) <= 1 && std::abs(ca - cb) <= 1;
}

// Letters typed as a two-key sequence collapse to a one-key letter when the
// second key is missed: sh→s, ch→c, kh→k, ya→a, yu→u, yo→o, ye→e.
bool missedSecondKey(char16_t a, char16_t b)
{
    auto pair = [&](char16_t x, char16_t y) {
        return (a == x && b == y) || (a == y && b == x);
    };
    return pair(u'ш', u'с') || pair(u'ч', u'ц') || pair(u'х', u'к') ||
           pair(u'я', u'а') || pair(u'ю', u'у') || pair(u'ё', u'о') ||
           pair(u'е', u'э') || pair(u'я', u'ы') || pair(u'ю', u'ы');
}

double substituteCost(char16_t a, char16_t b)
{
    if (a == b)
        return 0;
    if (confusablePartner(a) == b)
        return kVowelCost;
    if (missedSecondKey(a, b))
        return kNearCost;
    char ka = latinKey(a), kb = latinKey(b);
    if (ka && kb && keysAdjacent(ka, kb))
        return kNearCost;
    return 1;
}

// Restricted Damerau-Levenshtein where each operation costs roughly what
// it costs a Buuz user to produce that mistake on a QWERTY keyboard.
double typoDistance(const U16& typed, const U16& cand)
{
    const size_t n = typed.size(), m = cand.size();
    std::vector<std::vector<double>> d(n + 1, std::vector<double>(m + 1));
    auto indel = [](const U16& s, size_t i) {
        // A repeated or dropped copy of a doubled letter (аа, оо, нн...).
        bool doubled = (i > 0 && s[i] == s[i - 1]) || (i + 1 < s.size() && s[i] == s[i + 1]);
        return doubled ? kNearCost : 1.0;
    };
    for (size_t i = 1; i <= n; ++i)
        d[i][0] = d[i - 1][0] + indel(typed, i - 1);
    for (size_t j = 1; j <= m; ++j)
        d[0][j] = d[0][j - 1] + indel(cand, j - 1);
    for (size_t i = 1; i <= n; ++i) {
        for (size_t j = 1; j <= m; ++j) {
            double v = std::min({d[i - 1][j] + indel(typed, i - 1),
                                 d[i][j - 1] + indel(cand, j - 1),
                                 d[i - 1][j - 1] + substituteCost(typed[i - 1], cand[j - 1])});
            if (i > 1 && j > 1 && typed[i - 1] == cand[j - 2] && typed[i - 2] == cand[j - 1])
                v = std::min(v, d[i - 2][j - 2] + 1);
            d[i][j] = v;
        }
    }
    return d[n][m];
}

void vowelVariants(const U16& word, std::vector<U16>& out)
{
    out.assign(1, word);
    for (size_t i = 0; i < word.size(); ++i) {
        char16_t p = confusablePartner(word[i]);
        if (!p)
            continue;
        size_t n = out.size();
        if (n * 2 > kMaxVowelVariants)
            break;
        for (size_t k = 0; k < n; ++k) {
            U16 v = out[k];
            v[i] = p;
            out.push_back(std::move(v));
        }
    }
}

template <typename F>
void forEachEdit(const U16& w, F&& emit)
{
    const size_t n = w.size();
    for (size_t i = 0; i < n; ++i) {
        U16 del = w;
        del.erase(i, 1);
        emit(del);
    }
    for (size_t i = 0; i + 1 < n; ++i) {
        if (w[i] == w[i + 1])
            continue;
        U16 t = w;
        std::swap(t[i], t[i + 1]);
        emit(t);
    }
    for (size_t i = 0; i < n; ++i) {
        for (const char16_t* c = kAlphabet; *c; ++c) {
            if (*c == w[i] || *c == confusablePartner(w[i]))
                continue;
            U16 s = w;
            s[i] = *c;
            emit(s);
        }
    }
    for (size_t i = 0; i <= n; ++i) {
        for (const char16_t* c = kAlphabet; *c; ++c) {
            U16 s = w;
            s.insert(s.begin() + i, *c);
            emit(s);
        }
    }
}

BOOL isEligibleWord(NSString* word)
{
    if (word.length < 2)
        return NO;
    NSCharacterSet* letters = [NSCharacterSet letterCharacterSet];
    for (NSUInteger i = 0; i < word.length; ++i) {
        if (![letters characterIsMember:[word characterAtIndex:i]])
            return NO;
    }
    return YES;
}

BOOL isAllUppercase(NSString* word)
{
    NSCharacterSet* upper = [NSCharacterSet uppercaseLetterCharacterSet];
    NSCharacterSet* letters = [NSCharacterSet letterCharacterSet];
    BOOL anyLetter = NO;
    for (NSUInteger i = 0; i < word.length; ++i) {
        unichar c = [word characterAtIndex:i];
        if ([letters characterIsMember:c]) {
            anyLetter = YES;
            if (![upper characterIsMember:c])
                return NO;
        }
    }
    return anyLetter;
}

NSString* applyCase(NSString* original, NSString* suggestion)
{
    if (suggestion.length == 0)
        return suggestion;
    if (isAllUppercase(original))
        return suggestion.uppercaseString;
    unichar first = [original characterAtIndex:0];
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:first]) {
        NSString* head = [[suggestion substringToIndex:1] uppercaseString];
        NSString* tail = [[suggestion substringFromIndex:1] lowercaseString];
        return [head stringByAppendingString:tail];
    }
    return suggestion;
}

} // namespace

@implementation SpellChecker
{
    std::unique_ptr<Hunspell> _hunspell;
    std::unordered_map<U16, uint32_t> _freq;
    std::unordered_set<U16> _learned;
    NSString* _learnedPath;
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
        NSString* support = [NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        if (support)
            [instance setLearnedWordsFile:[support
                stringByAppendingPathComponent:@"Buuz/learned-words.txt"]];
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
    [self loadFrequencies:[directory stringByAppendingPathComponent:@"mn_freq.txt"]];
    NSLog(@"[Buuz] Hunspell dictionary loaded from %@ (%zu frequencies)",
          directory, _freq.size());
    return YES;
}

- (void)loadFrequencies:(NSString*)path
{
    _freq.clear();
    NSString* text = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    if (!text) {
        NSLog(@"[Buuz] word frequencies missing at %@", path);
        return;
    }
    _freq.reserve(260000);
    [text enumerateLinesUsingBlock:^(NSString* line, BOOL*) {
        NSRange tab = [line rangeOfString:@"\t"];
        if (tab.location == NSNotFound)
            return;
        long long count = [[line substringFromIndex:NSMaxRange(tab)] longLongValue];
        if (count > 0)
            self->_freq[toU16([line substringToIndex:tab.location])] =
                (uint32_t)std::min<long long>(count, UINT32_MAX);
    }];
}

- (void)setLearnedWordsFile:(NSString*)path
{
    _learnedPath = path;
    _learned.clear();
    NSString* text = path ? [NSString stringWithContentsOfFile:path
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil]
                          : nil;
    [text enumerateLinesUsingBlock:^(NSString* line, BOOL*) {
        if (line.length)
            self->_learned.insert(toU16(line.lowercaseString));
    }];
}

- (void)learnWord:(NSString*)word
{
    if (!isEligibleWord(word))
        return;
    NSString* lower = word.lowercaseString;
    if (!_learned.insert(toU16(lower)).second || !_learnedPath)
        return;
    [[NSFileManager defaultManager]
        createDirectoryAtPath:[_learnedPath stringByDeletingLastPathComponent]
  withIntermediateDirectories:YES
                   attributes:nil
                        error:nil];
    if (FILE* f = fopen(_learnedPath.fileSystemRepresentation, "a")) {
        fprintf(f, "%s\n", lower.UTF8String);
        fclose(f);
    }
}

- (uint32_t)freq:(const U16&)w
{
    auto it = _freq.find(w);
    return it == _freq.end() ? 0 : it->second;
}

- (bool)spell:(const U16&)w
{
    return _hunspell->spell(toUtf8(w));
}

// The composer's vowel-harmony guess and stuttered doubled letters need no
// frequency evidence: Hunspell accepting the repaired word is enough, unless
// several repairs are valid and the corpus does not clearly prefer one.
- (U16)exactRepair:(const U16&)word
{
    std::vector<U16> bases{word};
    for (size_t i = 1; i < word.size(); ++i) {
        if (word[i] == word[i - 1]) {
            U16 s = word;
            s.erase(i, 1);
            bases.push_back(std::move(s));
        }
    }
    std::unordered_set<U16> tried;
    std::vector<U16> valid;
    std::vector<U16> variants;
    for (const U16& base : bases) {
        vowelVariants(base, variants);
        for (const U16& v : variants) {
            if (v != word && tried.insert(v).second && [self freq:v] >= kExactMinFreq &&
                [self spell:v])
                valid.push_back(v);
        }
    }
    if (valid.empty())
        return U16();
    if (valid.size() == 1)
        return valid[0];
    std::sort(valid.begin(), valid.end(), [&](const U16& a, const U16& b) {
        return [self freq:a] > [self freq:b];
    });
    if ([self freq:valid[0]] >= kExactDominance * ([self freq:valid[1]] + 1))
        return valid[0];
    return U16();
}

// Picks the candidate that best trades corpus frequency against how unlikely
// the typing mistake is. Returns empty when no candidate clearly wins.
- (U16)rankedCorrection:(const U16&)word
{
    if (_freq.empty())
        return U16();

    std::unordered_set<U16> seen;
    auto consider = [&](const U16& cand) {
        if (cand.size() >= 2 && cand != word && _freq.count(cand))
            seen.insert(cand);
    };
    std::vector<U16> variants;
    vowelVariants(word, variants);
    for (const U16& v : variants) {
        consider(v);
        forEachEdit(v, consider);
    }

    struct Scored { U16 word; double score; };
    std::vector<Scored> ranked;
    auto score = [&](const U16& cand, uint32_t f) {
        ranked.push_back({cand, std::log((double)f + 1) - kTypoWeight * typoDistance(word, cand)});
    };
    for (const U16& cand : seen) {
        uint32_t f = [self freq:cand];
        if (f < kMinUnvettedFreq && ![self spell:cand])
            continue; // the corpus has typos of its own
        score(cand, f);
    }
    // Words Hunspell knows but the corpus never saw cannot win, but a close one
    // makes the correction ambiguous.
    std::unordered_set<U16> unseen;
    forEachEdit(word, [&](const U16& e) {
        if (e.size() >= 2 && !_freq.count(e) && unseen.insert(e).second && [self spell:e])
            score(e, kUnseenFreq);
    });
    if (ranked.empty())
        return U16();
    std::sort(ranked.begin(), ranked.end(),
              [](const Scored& a, const Scored& b) { return a.score > b.score; });

    double top = ranked[0].score;
    double total = std::exp(std::log((double)[self freq:word] + 1) - top);
    for (const Scored& r : ranked)
        total += std::exp(r.score - top);
    if (1.0 / total < kMinPosterior || [self freq:ranked[0].word] < kMinCandidateFreq)
        return U16();
    return ranked[0].word;
}

- (NSString*)maybeAutocorrect:(NSString*)word
{
    if (!_hunspell || !word || !isEligibleWord(word))
        return word;

    NSString* lowerStr = word.lowercaseString;
    U16 lower = toU16(lowerStr);
    if (_learned.count(lower) || [self spell:lower] || [self spell:toU16(word)])
        return word;
    if ([self freq:lower] >= kAttestedTypedFreq)
        return word; // names and loanwords Hunspell does not know

    U16 chosen = [self exactRepair:lower];
    if (chosen.empty())
        chosen = [self rankedCorrection:lower];
    if (chosen.empty())
        return word;
    return applyCase(word, fromU16(chosen));
}

@end
