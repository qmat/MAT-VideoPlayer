#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "SPK-NSScreen.h"

#define kRendererEventMask (NSLeftMouseDownMask | NSLeftMouseDraggedMask | NSLeftMouseUpMask | NSRightMouseDownMask | NSRightMouseDraggedMask | NSRightMouseUpMask | NSOtherMouseDownMask | NSOtherMouseUpMask | NSOtherMouseDraggedMask | NSKeyDownMask | NSKeyUpMask | NSFlagsChangedMask | NSScrollWheelMask | NSTabletPointMask | NSTabletProximityMask)
#define kRendererFPS 60.0

@interface PlayerApplication : NSApplication <NSApplicationDelegate>
{
	NSOpenGLContext*			_openGLContext;
	QCRenderer*					_renderer;
	NSString*					_filePath;
	NSTimer*					_renderTimer;
	NSTimeInterval				_startTime;
	NSSize						_screenSize;
	CGDirectDisplayID			displayID;
}
@end

@implementation PlayerApplication

- (id) init
{
	//We need to be our own delegate
	if(self = [super init])
	[self setDelegate:self];
	
	return self;
}

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification 
{
	GLint							value = 1;
	NSArray*						screens = [NSScreen screens];
	
	displayID = [[screens objectAtIndex:[screens count] - 1] displayID];
	
	NSOpenGLPixelFormatAttribute	attributes[] = {
														NSOpenGLPFAFullScreen,
														NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(displayID),
														NSOpenGLPFANoRecovery,
														NSOpenGLPFADoubleBuffer,
														NSOpenGLPFAAccelerated,
														NSOpenGLPFADepthSize, 24,
														NSOpenGLPFAMultisample,
														NSOpenGLPFASampleBuffers, 1,
														NSOpenGLPFASamples, 4,
														(NSOpenGLPixelFormatAttribute) 0
													};
	NSOpenGLPixelFormat*			format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	NSOpenPanel*					openPanel;
	
//	//If no composition file was dropped on the application's icon, we need to ask the user for one
//	if(_filePath == nil) {
//		openPanel = [NSOpenPanel openPanel];
//		[openPanel setAllowsMultipleSelection:NO];
//		[openPanel setCanChooseDirectories:NO];
//		[openPanel setCanChooseFiles:YES];
//		if([openPanel runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@"qtz"]] != NSOKButton) {
//			NSLog(@"No composition file specified");
//			[NSApp terminate:nil];
//		}
//		_filePath = [[openPanel filename] retain];
//	}
	
	_filePath = [[[NSBundle mainBundle] pathForResource:@"MAT-DocoPlayer" ofType:@"qtz"] retain];
	
	//Capture the main screen and cache its dimensions
	CGDisplayCapture(displayID);
	CGDisplayHideCursor(displayID);
	_screenSize.width = CGDisplayPixelsWide(displayID);
	_screenSize.height = CGDisplayPixelsHigh(displayID);
	
	//Create the fullscreen OpenGL context on the main screen (double-buffered with color and depth buffers)
	_openGLContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
	if(_openGLContext == nil) {
		NSLog(@"Cannot create OpenGL context");
		[NSApp terminate:nil];
	}
	[_openGLContext setFullScreen];
	[_openGLContext setValues:&value forParameter:kCGLCPSwapInterval];
	
	//Create the QuartzComposer Renderer with that OpenGL context and the specified composition file
	_renderer = [[QCRenderer alloc] initWithOpenGLContext:_openGLContext pixelFormat:format file:_filePath];
	if(_renderer == nil) {
		NSLog(@"Cannot create QCRenderer");
		[NSApp terminate:nil];
	}
	
	//Tell it where the documentaries are
	[_renderer setValue:[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] forInputKey:@"Movie_Folder"];
	
	//Create a timer which will regularly call our rendering method
	_renderTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / (NSTimeInterval)kRendererFPS) target:self selector:@selector(_render:) userInfo:nil repeats:YES] retain];
	if(_renderTimer == nil) {
		NSLog(@"Cannot create NSTimer");
		[NSApp terminate:nil];
	}
}

- (void) renderWithEvent:(NSEvent*)event
{
	NSTimeInterval			time = [NSDate timeIntervalSinceReferenceDate];
	NSPoint					mouseLocation;
	NSMutableDictionary*	arguments;
	
	//Let's compute our local time
	if(_startTime == 0) {
		_startTime = time;
		time = 0;
	}
	else
	time -= _startTime;
	
	//We setup the arguments to pass to the composition (normalized mouse coordinates and an optional event)
	mouseLocation = [NSEvent mouseLocation];
	mouseLocation.x /= _screenSize.width;
	mouseLocation.y /= _screenSize.height;
	arguments = [NSMutableDictionary dictionaryWithObject:[NSValue valueWithPoint:mouseLocation] forKey:QCRendererMouseLocationKey];
	if(event)
	[arguments setObject:event forKey:QCRendererEventKey];
	
	//Render a frame
	if(![_renderer renderAtTime:time arguments:arguments])
	NSLog(@"Rendering failed at time %.3fs", time);
	
	//Flush the OpenGL context to display the frame on screen
	[_openGLContext flushBuffer];
}

- (void) _render:(NSTimer*)timer
{
	//Simply call our rendering method, passing no event to the composition
	[self renderWithEvent:nil];
}

- (void) sendEvent:(NSEvent*)event
{
//	//Sod the [Esc] key, don't want to exit by accident: so we have ctrl-alt-command-q
//	if(([event type] == NSKeyDown) && ([event modifierFlags] & (NSControlKeyMask + NSCommandKeyMask + NSAlternateKeyMask)) && ([[event charactersIgnoringModifiers] isEqualTo:@"q"]))
//		[NSApp terminate:nil];

	if(([event type] == NSKeyDown) && ([event modifierFlags] & NSCommandKeyMask && ([[event charactersIgnoringModifiers] isEqualTo:@"q"])))
		[NSApp terminate:nil];
	
	//If the renderer is active and we have a meaningful event, render immediately passing that event to the composition
	if(_renderer && (NSEventMaskFromType([event type]) & kRendererEventMask))
		[self renderWithEvent:event];
	else
		[super sendEvent:event];
}

- (void) applicationWillTerminate:(NSNotification*)aNotification 
{
	//Stop the timer
	[_renderTimer invalidate];
	[_renderTimer release];
	
	//Destroy the renderer
	[_renderer release];
	
	//Destroy the OpenGL context
	[_openGLContext clearDrawable];
	[_openGLContext release];
	
	//Release main screen
	if(CGDisplayIsCaptured(displayID)) {
		CGDisplayShowCursor(displayID);
		CGDisplayRelease(displayID);
	}
	
	//Release path
	[_filePath release];
}

@end

int main(int argc, const char *argv[])
{
    return NSApplicationMain(argc, argv);
}
