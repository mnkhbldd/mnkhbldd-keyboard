/*
 * Copyright 2009 Odbayar Nyamtseren <odbayar.n@gmail.com>
 *
 * Init.cpp equivalent — macOS IMK server entry point.
 */

#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#include "Composer.h"

IMKServer* g_server = nil;

static void buuzLog(NSString* fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void buuzLog(NSString* fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    NSString* msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[Buuz] %@", msg);
    FILE* fp = fopen("/tmp/buuz.log", "a");
    if (fp) {
        fprintf(fp, "%s\n", msg.UTF8String);
        fclose(fp);
    }
}

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        composer = new Composer();

        NSApplication* app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        NSString* connectionName =
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"InputMethodConnectionName"];
        if (!connectionName)
            connectionName = @"com.odbayar.inputmethod.buuz_Connection";

        NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleId)
            bundleId = @"com.odbayar.inputmethod.buuz";

        buuzLog(@"starting server connection=%@ bundle=%@", connectionName, bundleId);

        g_server = [[IMKServer alloc] initWithName:connectionName
                                  bundleIdentifier:bundleId];
        if (!g_server) {
            buuzLog(@"FATAL: IMKServer failed to start");
            return 1;
        }

        buuzLog(@"IMKServer ready, entering run loop");
        [app run];

        delete composer;
        composer = nullptr;
    }
    return 0;
}
