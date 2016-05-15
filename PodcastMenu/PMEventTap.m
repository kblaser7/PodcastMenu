//
//  PMEventTap.m
//  PodcastMenu
//
//  Created by Guilherme Rambo on 15/05/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

#import "PMEventTap.h"

@interface PMEventTap ()

@property (nonatomic, copy) void (^mediaKeyEventHandler)(int32_t key, BOOL down);
@property (nonatomic, assign) CFMachPortRef eventPort;

@end

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* context)
{
    PMEventTap *eventTap = (__bridge PMEventTap *)context;
    
    if (type == kCGEventTapDisabledByTimeout) {
        NSLog(@"[PMEventTap] Tap disabled by timeout, reenabling.");
        
        CGEventTapEnable(eventTap.eventPort, true);
        
        return event;
    }
    
    NSEvent *theEvent;
    
    @try {
        theEvent = [NSEvent eventWithCGEvent:event];
    } @catch (NSException *e) {
        NSLog(@"[PMEventTap] Received an unknown event. Exception: %@", e);
        return event;
    }
    
    if (theEvent.type == NSSystemDefined && theEvent.subtype == 8) {
        NSInteger keyCode = ((theEvent.data1 & 0xFFFF0000) >> 16);
        
        // only fast, play and rewind keys are supported
        if (keyCode != NX_KEYTYPE_FAST && keyCode != NX_KEYTYPE_PLAY && keyCode != NX_KEYTYPE_REWIND) {
            return event;
        }
        
        NSInteger keyFlags = (theEvent.data1 & 0x0000FFFF);
        
        BOOL keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
        
        eventTap.mediaKeyEventHandler((int32_t)keyCode, keyState);
        
        return NULL;
    } else {
        return event;
    }
}

@implementation PMEventTap

- (instancetype)initWithMediaKeyEventHandler:(void (^)(int32_t, BOOL))eventHandler
{
    self = [super init];
    
    self.mediaKeyEventHandler = eventHandler;
    
    return self;
}

- (void)start
{
    dispatch_queue_t eventQueue = dispatch_queue_create("br.com.guilhermerambo.EventTap", NULL);
    dispatch_async(eventQueue, ^{
        self.eventPort = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, 0, kCGEventMaskForAllEvents, eventTapCallback, (__bridge void *)self);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventPort, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(self.eventPort, true);
        CFRunLoopRun();
    });
}

@end
