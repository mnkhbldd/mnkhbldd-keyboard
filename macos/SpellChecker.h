/*
 * Conservative Hunspell autocorrect for committed Cyrillic words.
 */

#import <Foundation/Foundation.h>

@interface SpellChecker : NSObject

+ (instancetype)shared;

- (BOOL)loadFromDirectory:(NSString*)directory;
- (NSString*)maybeAutocorrect:(NSString*)word;

@end
