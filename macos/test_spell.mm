/*
 * Smoke test for Hunspell autocorrect policy.
 * Usage: ./test_spell [dict-dir]
 */

#import <Foundation/Foundation.h>
#import "SpellChecker.h"

static int fail(NSString* msg)
{
    fprintf(stderr, "FAIL: %s\n", msg.UTF8String);
    return 1;
}

int main(int argc, char** argv)
{
    @autoreleasepool {
        NSString* dir = (argc > 1)
            ? [NSString stringWithUTF8String:argv[1]]
            : [[NSFileManager defaultManager].currentDirectoryPath
                  stringByAppendingPathComponent:@"Resources/dict"];

        SpellChecker* checker = [[SpellChecker alloc] init];
        if (![checker loadFromDirectory:dir])
            return fail(@"could not load dictionary");

        NSString* good = [checker maybeAutocorrect:@"сайн"];
        if (![good isEqualToString:@"сайн"])
            return fail([NSString stringWithFormat:@"good word changed: %@", good]);

        NSString* shortWord = [checker maybeAutocorrect:@"а"];
        if (![shortWord isEqualToString:@"а"])
            return fail(@"short word should be skipped");

        NSString* digits = [checker maybeAutocorrect:@"бууз2"];
        if (![digits isEqualToString:@"бууз2"])
            return fail(@"digits should be skipped");

        // Unique 1-edit suggestion (болно); other near-misses are farther.
        NSString* typo = [checker maybeAutocorrect:@"болнө"];
        if (![typo isEqualToString:@"болно"])
            return fail([NSString stringWithFormat:@"expected болно, got %@", typo]);

        // Several close suggestions → leave unchanged.
        NSString* ambiguous = [checker maybeAutocorrect:@"сайнн"];
        if (![ambiguous isEqualToString:@"сайнн"])
            return fail([NSString stringWithFormat:@"ambiguous typo should stay: %@", ambiguous]);

        NSString* caps = [checker maybeAutocorrect:@"САЙН"];
        if (![caps isEqualToString:@"САЙН"])
            return fail([NSString stringWithFormat:@"all-caps good word changed: %@", caps]);

        printf("ok (сайн unchanged, болнө→%s, сайнн unchanged)\n",
               typo.UTF8String);
        return 0;
    }
}
