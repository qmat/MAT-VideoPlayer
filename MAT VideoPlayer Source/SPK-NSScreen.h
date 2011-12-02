//
//  SPK-Screen.h
//  spark cinema - engine
//
//  Created by Toby Harris on 02/03/2009.
//  Copyright 2009 aka *spark. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSScreen (SPKAdditions)

- (CGDirectDisplayID) displayID;
- (NSTimeInterval) refreshPeriodActual;
- (NSTimeInterval) refreshPeriodNominal;

@end
