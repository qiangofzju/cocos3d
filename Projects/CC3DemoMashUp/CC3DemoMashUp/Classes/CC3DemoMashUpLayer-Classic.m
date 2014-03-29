/*
 * CC3DemoMashUpLayer-Classic.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2010-2014 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3DemoMashUpLayer-Classic.h for full API documentation.
 */

#import "CC3DemoMashUpLayer-Classic.h"

/** This implementation of CC3DemoMashUpLayer is used when compiling with cocos2d v1 or v2. */


#if CC3_CC2_CLASSIC

#import "CC3DemoMashUpScene.h"
#import "CC3Actions.h"
#import "CC3CC2Extensions.h"
#import "HUDLayer.h"
#import "HUDScene.h"
#import "ccMacros.h"


/** Scale and position the buttons so they are usable at various screen resolutions. */
#if APPORTABLE
#	define kControlSizeScale		(MAX(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) / 1024.0f)
#	define kControlPositionScale	kControlSizeScale
#else
#	define kControlSizeScale		CCDirector.sharedDirector.contentScaleFactor
#	define kControlPositionScale	1.0
#endif	// APPORTABLE

/** Parameters for setting up the joystick and button controls */
#define kJoystickSideLength				(80.0 * kControlPositionScale)
#define kButtonGrid						(40.0 * kControlPositionScale)
#define kJoystickPadding				(8.0 * kControlPositionScale)
#define kHUDPadding						(8.0 * kControlPositionScale)
#define kJoystickThumbFileName			@"JoystickThumb.png"
#define kSwitchViewButtonFileName		@"ArrowLeftButton48x48.png"
#define kInvasionButtonFileName			@"GridButton48x48.png"
#define kSunlightButtonFileName			@"SunlightButton48x48.png"
#define kZoomButtonFileName				@"ZoomButton48x48.png"
#define kShadowButtonFileName			@"ShadowButton48x48.png"
#define kShadowButtonLatchedFileName	@"ShadowButtonLatched48x48.png"
#define kButtonRingFileName				@"ButtonRing48x48.png"
#define kButtonShineFileName			@"Shine48x48.png"
#define kGlobeName						@"Globe"
#define kPeakShineOpacity				180
#define kButtonAdornmentScale			1.5


// Gesture support under Android is less sophisticated and more challenging than under iOS.
// When running on Android, avoid using gestures, and use underlying touch events instead.
#define kShouldUseGestures				(CC3_IOS && !APPORTABLE)

@interface CC3Layer (TemplateMethods)
-(BOOL) handleTouch: (UITouch*) touch ofType: (uint) touchType;
@end

@implementation CC3DemoMashUpLayer

/**
 * Returns the contained CC3Scene, cast into the appropriate type.
 * This is a convenience method to perform automatic casting.
 */
-(CC3DemoMashUpScene*) mashUpScene { return (CC3DemoMashUpScene*) self.cc3Scene; }

-(void) initializeControls {

	// Set the userInteractionEnabled property to NO to control the scene using gestures,
	// and to YES to control the scene using lower-level touch and mouse events.
	self.userInteractionEnabled = !kShouldUseGestures;
	
	[self addJoysticks];
	[self addSwitchViewButton];
	[self addInvasionButton];
	[self addSunlightButton];
	[self addZoomButton];
	[self addShadowButton];
	[self scheduleUpdate];		// Schedule updates on each frame
}

/** Creates the two joysticks that control the 3D camera direction and location. */
-(void) addJoysticks {
	CCSprite* jsThumb;

	// The joystick that controls the player's (camera's) direction
	jsThumb = [CCSprite spriteWithFile: kJoystickThumbFileName];
	jsThumb.scale = kControlSizeScale;
	
	_directionJoystick = [Joystick joystickWithThumb: jsThumb
											andSize: CGSizeMake(kJoystickSideLength, kJoystickSideLength)];
	_directionJoystick.position = ccp(kJoystickPadding, kJoystickPadding);
	[self addChild: _directionJoystick];
	
	// The joystick that controls the player's (camera's) location
	jsThumb = [CCSprite spriteWithFile: kJoystickThumbFileName];
	jsThumb.scale = kControlSizeScale;
	
	_locationJoystick = [Joystick joystickWithThumb: jsThumb
										   andSize: CGSizeMake(kJoystickSideLength, kJoystickSideLength)];
	[self positionLocationJoystick];
	[self addChild: _locationJoystick];
}

/**
 * Creates a button (actually a single-item menu) in the bottom center of the layer that will
 * allow the user to switch between four different views of the 3D scene.
 */
-(void) addSwitchViewButton {
	
	// Set up the menu item and position it in the bottom center of the layer
	_switchViewMI = [AdornableMenuItemImage itemWithNormalImage: kSwitchViewButtonFileName
												 selectedImage: kSwitchViewButtonFileName
														target: self
													  selector: @selector(switchViewSelected:)];
	_switchViewMI.scale = kControlSizeScale;
	[self positionButtons];
	
	// Instead of having different normal and selected images, the toggle menu item uses an
	// adornment, which is displayed whenever an item is selected.
	CCNodeAdornmentBase* adornment;
	
	// The adornment is a ring that fades in around the menu item and then fades out when
	// the menu item is no longer selected.
	CCSprite* ringSprite = [CCSprite spriteWithFile: kButtonRingFileName];
	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: ringSprite];
	adornment.zOrder = kAdornmentUnderZOrder;
	
	// The adornment could also be a "shine" image that is faded in on-top of the
	// menu item when it is selected, similar to some UIKit toolbar button implementations.
	// To try a "shine" adornment instead, uncomment the following.
//	CCSprite* shineSprite = [CCSprite spriteWithFile: kButtonShineFileName];
//	shineSprite.color = ccYELLOW;
//	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: shineSprite
//	 													    peakOpacity: kPeakShineOpacity];
	
	// Or the menu item adornment could be one that scales the menu item when activated.
	// To try a scaler adornment, uncomment the following line.
//	adornment = [CCNodeAdornmentScaler adornmentToScaleUniformlyBy: kButtonAdornmentScale];
	
	// Attach the adornment to the menu item and center it on the menu item
	adornment.position = ccpCompMult(ccpFromSize(_switchViewMI.contentSize), _switchViewMI.anchorPoint);
	_switchViewMI.adornment = adornment;
	
	CCMenu* viewMenu = [CCMenu menuWithItems: _switchViewMI, nil];
	viewMenu.position = CGPointZero;
	[self addChild: viewMenu];
}

/**
 * Creates a button (actually a single-item menu) in the bottom center of the layer that will
 * allow the user to create a robot invasion.
 */
-(void) addInvasionButton {
	
	// Set up the menu item and position it in the bottom center of the layer
	_invasionMI = [AdornableMenuItemImage itemWithNormalImage: kInvasionButtonFileName
											   selectedImage: kInvasionButtonFileName
													  target: self
													selector: @selector(invade:)];
	_invasionMI.scale = kControlSizeScale;
	[self positionButtons];
	
	// Instead of having different normal and selected images, the toggle menu item uses an
	// adornment, which is displayed whenever an item is selected.
	CCNodeAdornmentBase* adornment;
	
	// The adornment is a ring that fades in around the menu item and then fades out when
	// the menu item is no longer selected.
	CCSprite* ringSprite = [CCSprite spriteWithFile: kButtonRingFileName];
	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: ringSprite];
	adornment.zOrder = kAdornmentUnderZOrder;
	
	// Attach the adornment to the menu item and center it on the menu item
	adornment.position = ccpCompMult(ccpFromSize(_invasionMI.contentSize), _invasionMI.anchorPoint);
	_invasionMI.adornment = adornment;
	
	CCMenu* viewMenu = [CCMenu menuWithItems: _invasionMI, nil];
	viewMenu.position = CGPointZero;
	[self addChild: viewMenu];
}

/**
 * Creates a button (actually a single-item menu) in the bottom center of the layer that will
 * allow the user to turn the sun on or off.
 */
-(void) addSunlightButton {
	
	// Set up the menu item and position it in the bottom center of the layer
	_sunlightMI = [AdornableMenuItemImage itemWithNormalImage: kSunlightButtonFileName
											   selectedImage: kSunlightButtonFileName
													  target: self
													selector: @selector(cycleLights:)];
	_sunlightMI.scale = kControlSizeScale;
	[self positionButtons];
	
	// Instead of having different normal and selected images, the toggle menu item uses an
	// adornment, which is displayed whenever an item is selected.
	CCNodeAdornmentBase* adornment;
	
	// The adornment is a ring that fades in around the menu item and then fades out when
	// the menu item is no longer selected.
	CCSprite* ringSprite = [CCSprite spriteWithFile: kButtonRingFileName];
	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: ringSprite];
	adornment.zOrder = kAdornmentUnderZOrder;
	
	// Attach the adornment to the menu item and center it on the menu item
	adornment.position = ccpCompMult(ccpFromSize(_sunlightMI.contentSize), _sunlightMI.anchorPoint);
	_sunlightMI.adornment = adornment;
	
	CCMenu* viewMenu = [CCMenu menuWithItems: _sunlightMI, nil];
	viewMenu.position = CGPointZero;
	[self addChild: viewMenu];
}

/**
 * Creates a button (actually a single-item menu) in the bottom center of the layer
 * that will allow the user to move between viewing the whole scene and viewing
 * from the previous position.
 */
-(void) addZoomButton {
	
	// Set up the menu item and position it in the bottom center of the layer
	_zoomMI = [AdornableMenuItemImage itemWithNormalImage: kZoomButtonFileName
										   selectedImage: kZoomButtonFileName
												  target: self
												selector: @selector(cycleZoom:)];
	_zoomMI.scale = kControlSizeScale;
	[self positionButtons];
	
	// Instead of having different normal and selected images, the toggle menu
	// item uses a shine adornment, which is displayed whenever an item is selected.
	CCNodeAdornmentBase* adornment;

	CCSprite* shineSprite = [CCSprite spriteWithFile: kButtonShineFileName];
	shineSprite.color = ccWHITE;
	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: shineSprite
															peakOpacity: kPeakShineOpacity];
	
	// Attach the adornment to the menu item and center it on the menu item
	adornment.position = ccpCompMult(ccpFromSize(_zoomMI.contentSize), _zoomMI.anchorPoint);
	_zoomMI.adornment = adornment;
	
	CCMenu* viewMenu = [CCMenu menuWithItems: _zoomMI, nil];
	viewMenu.position = CGPointZero;
	[self addChild: viewMenu];
}

/**
 * Creates a button (actually a single-item menu) in the bottom center of the layer
 * that will allow the user to toggle shadows on and off for a selected node.
 */
-(void) addShadowButton {
	
	// Set up the menu item and position it in the bottom center of the layer.
	// We use a toggle button to indicate when the shadow activations are active.
	CCMenuItem* sb = [CCMenuItemImage itemWithNormalImage: kShadowButtonFileName
											selectedImage: kShadowButtonFileName];
	CCMenuItem* sbl = [CCMenuItemImage itemWithNormalImage: kShadowButtonLatchedFileName
											 selectedImage: kShadowButtonLatchedFileName];
	_shadowMI = [AdornableMenuItemToggle itemWithTarget: self
											  selector: @selector(toggleShadows:)
												 items: sb, sbl, nil];
	_shadowMI.scale = kControlSizeScale;
	[self positionButtons];
	
	// Instead of having different normal and selected images, the toggle menu
	// item uses a shine adornment, which is displayed whenever an item is selected.
	CCNodeAdornmentBase* adornment;
	
	// The adornment is a ring that fades in around the menu item and then fades out when
	// the menu item is no longer selected.
	CCSprite* ringSprite = [CCSprite spriteWithFile: kButtonRingFileName];
	adornment = [CCNodeAdornmentOverlayFader adornmentWithSprite: ringSprite];
	adornment.zOrder = kAdornmentUnderZOrder;
	
	// Attach the adornment to the menu item and center it on the menu item
	adornment.position = ccpCompMult(ccpFromSize(_shadowMI.contentSize), _shadowMI.anchorPoint);
	_shadowMI.adornment = adornment;
	
	CCMenu* viewMenu = [CCMenu menuWithItems: _shadowMI, nil];
	viewMenu.position = CGPointZero;
	[self addChild: viewMenu];
}

/**
 * Positions the right-side location joystick at the right of the layer.
 * This is called at initialization, and anytime the content size of the layer changes
 * to keep the joystick in the correct location within the new layer dimensions.
 */
-(void) positionLocationJoystick {
	_locationJoystick.position = ccp(self.contentSize.width - kJoystickSideLength - kJoystickPadding, kJoystickPadding);
}

/**
 * Positions the buttons between the two joysticks.
 * This is called at initialization, and anytime the content size of the layer changes
 * to keep the button in the correct location within the new layer dimensions.
 */
-(void) positionButtons {
	GLfloat middle = self.contentSize.width / 2.0;
	GLfloat btnY = (kJoystickPadding * 0.5) + (kButtonGrid * 0.5);

	_shadowMI.position = ccp(middle - (kButtonGrid * 0.5), btnY);
	_zoomMI.position = ccp(middle + (kButtonGrid * 0.5), btnY);

	btnY += kButtonGrid;
	_switchViewMI.position = ccp(middle - (kButtonGrid * 1.0), btnY);
	_invasionMI.position = ccp(middle, btnY);
	_sunlightMI.position = ccp(middle + (kButtonGrid * 1.0), btnY);
}


#pragma mark Updating

/**
 * Updates the player (camera) direction and location from the joystick controls
 * and then updates the 3D scene.
 */
-(void) update: (CCTime)dt {
	
	// Update the player direction and position in the scene from the joystick velocities
	self.mashUpScene.playerDirectionControl = _directionJoystick.velocity;
	self.mashUpScene.playerLocationControl = _locationJoystick.velocity;
	[super update: dt];
}

/** The user has pressed the switch camera view button. Tell the 3D scene so it can move the camera. */
-(void) switchViewSelected: (CCMenuItemToggle*) svMI {
	[self.mashUpScene switchCameraTarget];
}

/** The user has pressed the invade button. Tell the 3D scene. */
-(void) invade: (CCMenuItemToggle*) svMI { [self.mashUpScene invade]; }

/** The user has pressed the cycle lights button. Tell the 3D scene. */
-(void) cycleLights: (CCMenuItemToggle*) svMI { [self.mashUpScene cycleLights]; }

/** The user has pressed the zoom button. Tell the 3D scene. */
-(void) cycleZoom: (CCMenuItemToggle*) svMI { [self.mashUpScene cycleZoom]; }

/** The user has pressed the shadow button. Tell the 3D scene. */
-(void) toggleShadows: (CCMenuItemToggle*) svMI {
	self.mashUpScene.isManagingShadows = !self.mashUpScene.isManagingShadows;
}

/**
 * Called automatically when the contentSize has changed.
 * Move the location joystick to keep it in the bottom right corner of this layer
 * and the switch view button to keep it centered between the two joysticks.
 */
-(void) didUpdateContentSizeFrom: (CGSize) oldSize {
	[super didUpdateContentSizeFrom: oldSize];
	[self positionLocationJoystick];
	[self positionButtons];
}


#pragma mark HUD window

/**
 * Opens a small, semi-transparent child HUD (Heads-Up-Display) window on top of the
 * main scene. This HUD window contains a close-up of the rotating globe. This window
 * is a separate CC3Layer containing a separate CC3Scene that contains a copy of the
 * globe node.
 *
 * The HUD window starts minimized at the point on the globe that was touched, and
 * smoothly expands to the top-right corner of the main scene.
 */
-(void) openGlobeHUDFromTouchAt: (CGPoint) touchPoint {
	if (_hudLayer) return;
	
	// Determine an appropriate size for the HUD child window.
	CGSize mySize = self.contentSize;
	GLfloat hudSide = MIN(mySize.width, mySize.height) * 0.5 - (kHUDPadding * 2);
	CGPoint hudPos = ccp(mySize.width - (hudSide + kHUDPadding),
						 mySize.height - (hudSide + kHUDPadding));
	CGSize hudSize = CGSizeMake(hudSide, hudSide);
	
	// Create the HUD CC3Layer, with a semi-transparent background, set its position
	// to the touch-point (offset by the size of the layer), and set its final size.
	// Start it with a small scale.
	_hudLayer = [HUDLayer layer];
	_hudLayer.position = ccpSub(touchPoint, ccpMult(ccpFromSize(hudSize), 0.5));
	_hudLayer.contentSize = hudSize;
	_hudLayer.scale = 0.1;

	// Create and add a new CC3Scene, containing just a copy of the rotating globe,
	// for the HUD layer, and ensure its camera frames the globe.
	_hudLayer.cc3Scene = [self makeHUDScene];

	// Run actions to move and scale the HUD layer from its starting position
	// and size to its final expanded position and size.
	[_hudLayer runAction: [CCActionMoveTo actionWithDuration: 1.0 position: hudPos]];
	[_hudLayer runAction: [CCActionScaleTo actionWithDuration: 1.0 scale: 1.0]];
	[self addChild: _hudLayer];
}

/**
 * Returns a new CC3Scene containing a copy of the globe from the main scene.
 * Sets the globe rotating and makes it semi-transparent.
 */
-(CC3Scene*) makeHUDScene {
	CC3Scene* hudScene = [HUDScene nodeWithName: @"HUDScene"];
	
	CC3Node* globe = [[self.cc3Scene getNodeNamed: kGlobeName] copy];
	globe.location = kCC3VectorZero;
	globe.rotation = kCC3VectorZero;
	[globe runAction: [CCActionRepeatForever actionWithAction: [CC3RotateBy actionWithDuration: 1.0
																				rotateBy: cc3v(0.0, 30.0, 0.0)]]];
	[hudScene addChild: globe];	

	[hudScene createGLBuffers];		// Won't really do anything because the Globe mesh...
									// ...has already been buffered in main scene
	hudScene.opacity = (kCCOpacityFull * 0.75);		// Makes everything in the scene somewhat translucent

	return hudScene;
}

/** Closes the HUD window by using CCActions to fade it out and then remove it. */
-(void) closeGlobeHUDFromTouchAt: (CGPoint) touchPoint {
	[_hudLayer stopAllActions];
	CCActionInterval* fadeHUD = [CCActionFadeTo actionWithDuration: 1.0 opacity: 0];
	CCActionInstant* removeHUD = [CCActionCallFunc actionWithTarget: self
														   selector: @selector(removeGlobeHUD)];
	[_hudLayer runAction: [CCActionSequence actionOne: fadeHUD two: removeHUD]];
}

/** Removes the HUD window if it exists. */
-(void) removeGlobeHUD {
	if (_hudLayer) {
		[self removeChild: _hudLayer cleanup: YES];
		_hudLayer = nil;
	}
}

/** Toggles between opening and closing the HUD window. */
-(void) toggleGlobeHUDFromTouchAt: (CGPoint) touchPoint {
	if (_hudLayer)
		[self closeGlobeHUDFromTouchAt: touchPoint];
	else
		[self openGlobeHUDFromTouchAt: touchPoint];
}


#pragma mark Touch handling

/**
 * The ccTouchMoved:withEvent: method is optional for the <CCTouchDelegateProtocol>.
 * The event dispatcher will not dispatch events for which there is no method
 * implementation. Since the touch-move events are both voluminous and seldom used,
 * the implementation of ccTouchMoved:withEvent: has been left out of the default
 * CC3Layer implementation. To receive and handle touch-move events for object
 * picking, it must be implemented here.
 *
 * This method will not be invoked if gestures have been enabled.
 */
-(void) ccTouchMoved: (UITouch *)touch withEvent: (UIEvent *)event {
	[self handleTouch: touch ofType: kCCTouchMoved];
}

#if CC3_IOS
#pragma mark Gesture support

/**
 * Invoked when this layer is being opened on the view.
 *
 * If we want to use gestures, we add the gesture recognizers here.
 *
 * By using the cc3AddGestureRecognizer: method to add the gesture recognizers,
 * we ensure that they will be torn down when this layer is removed from the view.
 *
 * This layer has child buttons on it. To ensure that those buttons receive their
 * touch events, we set cancelsTouchesInView to NO on the tap gestures recognizer
 * so that that gesture recognizer allows the touch events to propagate to the buttons.
 * We do not need to do that for the other recognizers because we don't want buttons
 * to receive touch events in the middle of a pan or pinch.
 */
-(void) onOpenCC3Layer {
	if (self.isUserInteractionEnabled) return;
	
	// Register for tap gestures to select 3D nodes.
	// This layer has child buttons on it. To ensure that those buttons receive their
	// touch events, we set cancelsTouchesInView to NO so that the gesture recognizer
	// allows the touch events to propagate to the buttons.
	UITapGestureRecognizer* tapSelector = [[UITapGestureRecognizer alloc]
										   initWithTarget: self action: @selector(handleTapSelection:)];
	tapSelector.numberOfTapsRequired = 1;
	tapSelector.cancelsTouchesInView = NO;		// Ensures touches are passed to buttons
	[self cc3AddGestureRecognizer: tapSelector];
	
	// Register for single-finger dragging gestures used to spin the two cubes.
	UIPanGestureRecognizer* dragPanner = [[UIPanGestureRecognizer alloc]
										  initWithTarget: self action: @selector(handleDrag:)];
	dragPanner.minimumNumberOfTouches = 1;
	dragPanner.maximumNumberOfTouches = 1;
	[self cc3AddGestureRecognizer: dragPanner];

	// Register for double-finger dragging to pan the camera.
	UIPanGestureRecognizer* cameraPanner = [[UIPanGestureRecognizer alloc]
											initWithTarget: self action: @selector(handleCameraPan:)];
	cameraPanner.minimumNumberOfTouches = 2;
	cameraPanner.maximumNumberOfTouches = 2;
	[self cc3AddGestureRecognizer: cameraPanner];
	
	// Register for double-finger dragging to pan the camera.
	UIPinchGestureRecognizer* cameraMover = [[UIPinchGestureRecognizer alloc]
											 initWithTarget: self action: @selector(handleCameraMove:)];
	[self cc3AddGestureRecognizer: cameraMover];
}

/**
 * This handler is invoked when a single-tap gesture is recognized.
 *
 * If the tap occurs within a descendant CCNode that wants to capture the touch,
 * such as a menu or button, the gesture is cancelled. Otherwise, the tap is 
 * forwarded to the CC3Scene to pick the 3D node under the tap.
 */
-(void) handleTapSelection: (UITapGestureRecognizer*) gesture {

	// Once the gesture has ended, convert the UI location to a 2D node location and
	// pick the 3D node under that location. Don't forget to test that the gesture is
	// valid and does not conflict with touches handled by this layer or its descendants.
	if ( [self cc3ValidateGesture: gesture] && (gesture.state == UIGestureRecognizerStateEnded) ) {
		CGPoint touchPoint = [self cc3ConvertUIPointToNodeSpace: gesture.location];
		[self.mashUpScene pickNodeFromTapAt: touchPoint];
	}
}

/**
 * This handler is invoked when a single-finger drag gesture is recognized.
 *
 * If the drag starts within a descendant CCNode that wants to capture the touch,
 * such as a menu or button, the gesture is cancelled.
 *
 * The CC3Scene marks where dragging begins to determine the node that is underneath
 * the touch point at that time, and is further notified as dragging proceeds.
 * It uses the velocity of the drag to spin the cube nodes. Finally, the scene is
 * notified when the dragging gesture finishes.
 *
 * The dragging movement is normalized to be specified relative to the size of the
 * layer, making it independant of the size of the layer.
 */
-(void) handleDrag: (UIPanGestureRecognizer*) gesture {
	switch (gesture.state) {
		case UIGestureRecognizerStateBegan:
			if ( [self cc3ValidateGesture: gesture] ) {
				[self.mashUpScene startDraggingAt: [self cc3ConvertUIPointToNodeSpace: gesture.location]];
			}
			break;
		case UIGestureRecognizerStateChanged:
			[self.mashUpScene dragBy: [self cc3NormalizeUIMovement: gesture.translation]
						  atVelocity:[self cc3NormalizeUIMovement: gesture.velocity]];
			break;
		case UIGestureRecognizerStateEnded:
			[self.mashUpScene stopDragging];
			break;
		default:
			break;
	}
}

/**
 * This handler is invoked when a double-finger pan gesture is recognized.
 *
 * If the panning starts within a descendant CCNode that wants to capture the touch,
 * such as a menu or button, the gesture is cancelled.
 *
 * The CC3Scene marks the camera orientation when dragging begins, and is notified
 * as dragging proceeds. It uses the relative translation of the panning movement
 * to determine the new orientation of the camera. Finally, the scene is notified
 * when the dragging gesture finishes.
 *
 * The dragging movement is normalized to be specified relative to the size of the
 * layer, making it independant of the size of the layer.
 */
-(void) handleCameraPan: (UIPanGestureRecognizer*) gesture {
	switch (gesture.state) {
		case UIGestureRecognizerStateBegan:
			if ( [self cc3ValidateGesture: gesture] ) [self.mashUpScene startPanningCamera];
			break;
		case UIGestureRecognizerStateChanged:
			[self.mashUpScene panCameraBy: [self cc3NormalizeUIMovement: gesture.translation]];
			break;
		case UIGestureRecognizerStateEnded:
			[self.mashUpScene stopPanningCamera];
			break;
		default:
			break;
	}
}


/**
 * This handler is invoked when a pinch gesture is recognized.
 *
 * If the pinch starts within a descendant CCNode that wants to capture the touch,
 * such as a menu or button, the gesture is cancelled.
 *
 * The CC3Scene marks the camera location when pinching begins, and is notified
 * as pinching proceeds. It uses the relative scale of the pinch gesture to determine
 * a new location for the camera. Finally, the scene is notified when the pinching
 * gesture finishes.
 *
 * Note that the pinching does not zoom the camera, although the visual effect is
 * very similar. For this application, moving the camera is more flexible and useful
 * than zooming. But other application might prefer to use the pinch gesture scale
 * to modify the uniformScale or fieldOfView properties of the camera, to perform
 * a true zooming effect.
 */
-(void) handleCameraMove: (UIPinchGestureRecognizer*) gesture {
	switch (gesture.state) {
		case UIGestureRecognizerStateBegan:
			if ( [self cc3ValidateGesture: gesture] ) [self.mashUpScene startMovingCamera];
			break;
		case UIGestureRecognizerStateChanged:
			[self.mashUpScene moveCameraBy: gesture.scale];
			break;
		case UIGestureRecognizerStateEnded:
			[self.mashUpScene stopMovingCamera];
			break;
		default:
			break;
	}
}
#endif	// CC3_IOS

@end

#endif	// CC3_CC2_CLASSIC