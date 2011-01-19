/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiViewProxy.h"
#import "TiAnimation.h"
#import "TiTab.h"
#import "TiUIWindow.h"
#import "TiUIView.h"
#import "TiViewController.h"

typedef enum
{
	TiOrientationNone = 0,
	TiOrientationAny = 0xFFFF,
	
	TiOrientationPortrait			= 1 << UIInterfaceOrientationPortrait,
	TiOrientationPortraitUpsideDown	= 1 << UIInterfaceOrientationPortraitUpsideDown,
	TiOrientationLandscapeLeft		= 1 << UIInterfaceOrientationLandscapeLeft,
	TiOrientationLandscapeRight		= 1 << UIInterfaceOrientationLandscapeRight,

	TiOrientationLandscapeOnly		= TiOrientationLandscapeLeft | TiOrientationLandscapeRight,
	TiOrientationPortraitOnly		= TiOrientationPortrait | TiOrientationPortraitUpsideDown,
	
} TiOrientationFlags;

#define TI_ORIENTATION_ALLOWED(flag,bit)	(flag & (1<<bit))
#define TI_ORIENTATION_SET(flag,bit)		(flag |= (1<<bit))

typedef enum
{
	TiWindowClosed		= 0x00,	//Unattached, unopened, uninterested
	TiWindowLoading		= 0x01,	//Windows with an url will go into this state. Intending to open once the JS does a single pass
	TiWindowOpenable	= 0x02, //This is when the window wants to open, but is blocked by an older window still loading or opening.
	TiWindowOpening		= 0x04, //This occurs if the window is being presented with an animation, either via ViewController, or by us
	TiWindowOpened		= 0x08, //The window is open and acting as normal.
	TiWindowClosable	= 0x10, //Like openable, this is is when the window wants to close, but is blocked by another window still loading or opening.
	TiWindowClosing		= 0x20, //Like opening, this occurs if the window is being animated, 
	TiWindowUnloading	= 0x40,	//Windows with an url will go into this state, as the JS context is finishing the last actions.

	TiWindowAnimating	= TiWindowOpening | TiWindowClosing,

} TiWindowState;

@protocol TiParentWindow;
@protocol TiChildWindow <NSObject>

@property(nonatomic,readwrite,assign)	id<TiParentWindow> parentWindow;
@property(nonatomic,readonly,assign)	TiOrientationFlags orientationFlags;

@property(nonatomic,readonly,assign)	TiWindowState windowState;

//Should this be a should, or an attach?
-(void)windowWillOpen:(BOOL)animated;
-(void)windowDidOpen:(BOOL)animated;
-(void)windowWillClose:(BOOL)animated;
-(void)windowDidClose:(BOOL)animated;

@end

@protocol TiParentWindow <NSObject>

-(void)childWindowChangedOrientationFlags:(id<TiChildWindow>) childWindow;
-(void)childWindowChangedState:(id<TiChildWindow>) childWindow;

@end

/*	TiWindowState is a finite state machine.
 *	
 *	A created window starts out Closed.
 *		With a JS thread, as soon as an url is applied, immediately goes into a loading.
 *	A parentWindow is set. The child sends a childWindowChangedState. If an url still loading, that's a Loading.
 *		Otherwise, the child is Openable.
 *	The parent getting an Openable changed state will start the window opening sequence.
 *	The parent sends a windowWillOpen. The child goes into Opening.
 *	The parent sends a windowDidOpen. The child goes into Opened.
 *	
 *	If the child programmatically wants to close, it goes into Closable, sending the message.
 *	That's right, the actual closing is handled by the parent. If the window is open or closable,
 *	The parent can send the windowWillClose. The child goes into closing.
 *	The parent sends a windowDidClose. The child goes into Unloading if there's JS. Otherwise, it's closed and released.
 */



TiOrientationFlags TiOrientationFlagsFromObject(id args);

// specialization for TiViews that act like top level 
// windows when opened, closed, etc.
//
@interface TiWindowProxy : TiViewProxy<TiAnimationDelegate,TiUIViewController,TiChildWindow> {
@protected
	BOOL opened;
	BOOL focused;
	BOOL fullscreenFlag;
	BOOL modalFlag;
	BOOL restoreFullscreen;
	BOOL navWindow;
	TiViewProxy<TiTab> *tab;
	UIViewController *controller;
	UINavigationController *navController;
@private
	BOOL opening;
	BOOL attached;
	BOOL closing;
	BOOL splashTransitionAnimation;
	int transitionAnimation;
	NSMutableArray *reattachWindows;
	UIView *closeView;
	UIViewController *tempController;

	NSObject<TiParentWindow> * parentWindow;
	TiWindowState windowState;
	TiOrientationFlags orientationFlags;
}

-(void)fireFocus:(BOOL)newFocused;

#pragma mark Public APIs

@property(nonatomic,readonly)	NSNumber *opened;
@property(nonatomic,readonly)	NSNumber *focused;
@property(nonatomic,readonly)	BOOL closing;

-(void)open:(id)args;
-(void)close:(id)args;
-(TiProxy*)tabGroup;
-(TiProxy<TiTab>*)tab;

#pragma mark Internal
-(void)attachViewToTopLevelWindow;
-(void)windowReady;
-(BOOL)handleFocusEvents;
-(BOOL)_isChildOfTab;
-(void)_associateTab:(UIViewController*)controller_ navBar:(UINavigationController*)navbar_ tab:(TiProxy<TiTab>*)tab_;
-(void)prepareForNavView:(UINavigationController*)navController_;

@property(nonatomic,readwrite,assign)	TiWindowState windowState;

@property(nonatomic,readwrite,retain)	UIViewController *controller;
@property(nonatomic,readwrite,retain)	UINavigationController *navController;

-(void)replaceController;
-(UIWindow*)_window;
-(BOOL)_handleOpen:(id)args;
-(BOOL)_handleClose:(id)args;
-(void)_tabAttached;
-(void)_tabDetached;
-(void)_tabFocus;
-(void)_tabBlur;

-(void)_tabBeforeFocus;
-(void)_tabBeforeBlur;

-(void)setupWindowDecorations;

@end
