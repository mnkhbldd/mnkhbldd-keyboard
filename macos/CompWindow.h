/*
 * Buuz macOS Input Method — CompWindow
 * Floating composition hint panel (parity with Windows CompWindow).
 * Primary composition is shown via IMK marked text; this panel is optional.
 */

#import <Cocoa/Cocoa.h>

@interface CompWindow : NSPanel
- (void)updateWithText:(NSString*)text;
- (void)showNearClient:(id)client;
- (void)hidePanel;
@end
