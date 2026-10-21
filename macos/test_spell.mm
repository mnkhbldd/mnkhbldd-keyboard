/*
 * Smoke test for autocorrect policy.
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

        // Latin "u" mapped to the wrong Cyrillic vowel.
        NSString* vowel = [checker maybeAutocorrect:@"уйлчилгээ"];
        if (![vowel isEqualToString:@"үйлчилгээ"])
            return fail([NSString stringWithFormat:@"expected үйлчилгээ, got %@", vowel]);

        // Doubled letter, even though Hunspell also offers suffixed forms.
        NSString* doubled = [checker maybeAutocorrect:@"сайнн"];
        if (![doubled isEqualToString:@"сайн"])
            return fail([NSString stringWithFormat:@"expected сайн, got %@", doubled]);

        // No vowel swap or doubled letter, several suggestions → leave alone.
        NSString* ambiguous = [checker maybeAutocorrect:@"тсахим"];
        if (![ambiguous isEqualToString:@"тсахим"])
            return fail([NSString stringWithFormat:@"ambiguous typo should stay: %@", ambiguous]);

        NSString* caps = [checker maybeAutocorrect:@"САЙН"];
        if (![caps isEqualToString:@"САЙН"])
            return fail([NSString stringWithFormat:@"all-caps good word changed: %@", caps]);

        NSString* capsTypo = [checker maybeAutocorrect:@"Сайнн"];
        if (![capsTypo isEqualToString:@"Сайн"])
            return fail([NSString stringWithFormat:@"expected Сайн, got %@", capsTypo]);

        // Several Hunspell suggestions; corpus frequency picks the common one.
        NSString* dropped = [checker maybeAutocorrect:@"улаанбаатр"];
        if (![dropped isEqualToString:@"улаанбаатар"])
            return fail([NSString stringWithFormat:@"expected улаанбаатар, got %@", dropped]);

        NSString* vowels = [checker maybeAutocorrect:@"оорчлолт"];
        if (![vowels isEqualToString:@"өөрчлөлт"])
            return fail([NSString stringWithFormat:@"expected өөрчлөлт, got %@", vowels]);

        NSString* learnedPath = [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"buuz-test-learned.txt"];
        [[NSFileManager defaultManager] removeItemAtPath:learnedPath error:nil];
        [checker setLearnedWordsFile:learnedPath];
        [checker learnWord:@"Сайнн"];
        if (![[checker maybeAutocorrect:@"сайнн"] isEqualToString:@"сайнн"])
            return fail(@"learned word was still corrected");
        SpellChecker* reloaded = [[SpellChecker alloc] init];
        [reloaded loadFromDirectory:dir];
        [reloaded setLearnedWordsFile:learnedPath];
        if (![[reloaded maybeAutocorrect:@"сайнн"] isEqualToString:@"сайнн"])
            return fail(@"learned word did not persist");
        [[NSFileManager defaultManager] removeItemAtPath:learnedPath error:nil];

        printf("ok (уйлчилгээ→%s, сайнн→%s, улаанбаатр→%s, тсахим unchanged)\n",
               vowel.UTF8String, doubled.UTF8String, dropped.UTF8String);
        return 0;
    }
}
