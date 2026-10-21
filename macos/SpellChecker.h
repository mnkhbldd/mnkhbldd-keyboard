/*
 * Conservative autocorrect for committed Cyrillic words: Hunspell decides
 * what is misspelled, corpus word frequencies decide what to replace it with.
 */

#import <Foundation/Foundation.h>

@interface SpellChecker : NSObject

+ (instancetype)shared;

- (BOOL)loadFromDirectory:(NSString*)directory;
- (NSString*)maybeAutocorrect:(NSString*)word;

// Words the user rejected a correction for are never corrected again.
- (void)learnWord:(NSString*)word;
- (void)setLearnedWordsFile:(NSString*)path;

@end
