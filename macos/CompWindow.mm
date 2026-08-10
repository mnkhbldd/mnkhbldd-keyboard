/*
 * Buuz macOS Input Method — CompWindow
 */

#import <InputMethodKit/InputMethodKit.h>
#import "CompWindow.h"

@implementation CompWindow
{
    NSTextField* _label;
}

- (instancetype)init
{
    NSRect frame = NSMakeRect(0, 0, 200, 28);
    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:YES];
    if (self) {
        self.level = NSFloatingWindowLevel;
        self.opaque = NO;
        self.backgroundColor = [[NSColor blackColor] colorWithAlphaComponent:0.85];
        self.hasShadow = YES;
        self.ignoresMouseEvents = YES;

        _label = [[NSTextField alloc] initWithFrame:NSInsetRect(frame, 8, 4)];
        _label.bezeled = NO;
        _label.drawsBackground = NO;
        _label.editable = NO;
        _label.selectable = NO;
        _label.textColor = [NSColor whiteColor];
        _label.font = [NSFont systemFontOfSize:16];
        _label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.contentView addSubview:_label];
    }
    return self;
}

- (void)updateWithText:(NSString*)text
{
    _label.stringValue = text ?: @"";
    [_label sizeToFit];
    NSSize size = _label.frame.size;
    size.width += 16;
    size.height += 8;
    [self setContentSize:size];
}

- (void)showNearClient:(id)client
{
    NSRect lineRect = NSMakeRect(100, 100, 0, 20);
    if ([client conformsToProtocol:@protocol(IMKTextInput)]) {
        NSRect rect = NSZeroRect;
        [(id<IMKTextInput>)client attributesForCharacterIndex:0 lineHeightRectangle:&rect];
        if (!NSIsEmptyRect(rect))
            lineRect = rect;
    }
    NSPoint origin = NSMakePoint(NSMinX(lineRect), NSMinY(lineRect) - self.frame.size.height - 4);
    [self setFrameOrigin:origin];
    [self orderFront:nil];
}

- (void)hidePanel
{
    [self orderOut:nil];
}

@end
