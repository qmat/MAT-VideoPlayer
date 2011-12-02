//
//  SPK-Screen.m
//  spark cinema - engine
//
//  Created by Toby Harris on 02/03/2009.
//  Copyright 2009 aka *spark. All rights reserved.
//

#import "SPK-NSScreen.h"

static CVReturn _displayLinkCallBack(CVDisplayLinkRef displayLink, const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
	// do nothing, this is just to enable the display link so we can get CVDisplayLinkGetActualOutputVideoRefreshPeriod
	return kCVReturnSuccess;
}

@implementation NSScreen (SPKAdditions)

- (CGDirectDisplayID) displayID
{
	// (from docs) you can also retrieve the CGDirectDisplayID value associated with the screen from this dictionary. To access this value, specify the Objective-C string @"NSScreenNumber" as the key when requesting the item from the dictionary. The value associated with this key is an NSNumber object containing the display ID value. This string is only valid when used as a key for the dictionary returned by this method.
	return (CGDirectDisplayID)[[[self deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
}

- (long) refreshRateCRT
{
	// after http://www.carbondev.com/site/?page=CGDisplayAvailableModes
	// (from docs) kCGDisplayRefreshRate - Specifies a CFNumber double-precision floating point value that represents the refresh rate of a CRT display. Some displays may not use conventional video vertical and horizontal sweep in painting the screen; these displays report a refresh rate of 0.
	long value = 0;
	CFNumberRef numRef;
	numRef = (CFNumberRef)CFDictionaryGetValue(CGDisplayCurrentMode([self displayID]), kCGDisplayRefreshRate); 
	if (numRef != NULL)
		CFNumberGetValue(numRef, kCFNumberLongType, &value); 	
	return value;
}

- (NSTimeInterval) refreshPeriodNominal
{
	CVDisplayLinkRef displayLink;
	NSTimeInterval period = 0;
	
	if(CVDisplayLinkCreateWithCGDisplay([self displayID], &displayLink) == kCVReturnSuccess) {
		CVTime periodAsCVTime = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink);
		if (! periodAsCVTime.flags & kCVTimeIsIndefinite) period = (NSTimeInterval)periodAsCVTime.timeValue/periodAsCVTime.timeScale;
		NSLog(@"SPK-NSScreen refreshPeriodNominal period is %f", period);
		// QTGetTimeInterval(periodAsCVTime, &period);
		CVDisplayLinkRelease(displayLink);
	} else {
		NSLog(@"SPK-NSScreen refreshPeriodNominal failed to create display link");
	}
	return period;
}

- (NSTimeInterval) refreshPeriodActual
{
	CVDisplayLinkRef displayLink;
	NSTimeInterval period = 0;
	CVReturn returnCode;

	returnCode = CVDisplayLinkCreateWithCGDisplay([self displayID], &displayLink);
	if (returnCode == kCVReturnSuccess) {
		CVDisplayLinkSetOutputCallback(displayLink, _displayLinkCallBack, self);
		returnCode = CVDisplayLinkStart(displayLink);
		if (returnCode == kCVReturnSuccess) {	
			period = CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink);
			CVDisplayLinkStop(displayLink);
			NSLog(@"SPK-NSScreen refreshPeriodActual period is %f", period);
		} else { 
			NSLog(@"SPK-NSScreen refreshPeriod failed to start display link, error %i", returnCode);
		}
		CVDisplayLinkRelease(displayLink);
	} else {
		NSLog(@"SPK-NSScreen refreshPeriod failed to create display link, error %i", returnCode);
	}
	return period;
}

@end
