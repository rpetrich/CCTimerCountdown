//
//  CCTimerCountdown.x
//  CCTimerCountdown
//
//  Created by Zane Helton on 08.11.2015.
//  Copyright (c) 2015 Zane Helton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>

@interface TimerManager
+ (instancetype)sharedManager;
- (double)remainingTime;
@end

@interface UIConcreteLocalNotification
- (NSDate *)fireDate;
@end

@interface SBCCShortcutButtonController
- (void)setHidden:(_Bool)arg1;
- (UIView *)view;
@end

@interface SBCCButtonSectionController
- (NSString *)prettyPrintTime:(int)seconds;
- (void)updateLabel:(NSTimer *)timer;
@end

/*
	Heavily documented for educational purposes
 */
%hook SBCCButtonSectionController

UILabel *timeRemainingLabel;
NSDate *pendingDate;
NSTimer *pendingTimer;

%new
- (void)updateLabel:(NSTimer *)timer {
	[timeRemainingLabel setText:[self prettyPrintTime:[pendingDate timeIntervalSinceDate:[NSDate date]]]];
}

- (void)viewWillAppear:(_Bool)arg1 {
	[pendingTimer invalidate];
	// grab the time manager (model (where all the information resides))
	TimerManager *timeManager = [%c(TimerManager) sharedManager];
	// get the notification from the time manager
	UIConcreteLocalNotification *notification = MSHookIvar<UIConcreteLocalNotification *>(timeManager, "_notification");
	// calculate the time between when the timer goes off and now (in seconds)
	pendingDate = [notification fireDate];
	NSTimeInterval secondsBetweenNowAndFireDate = [pendingDate timeIntervalSinceDate:[NSDate date]];
	// create our label as long as there is a timer running
	if (secondsBetweenNowAndFireDate > 0) {
		// grab the timer cc shortcut from a SBCCButtonSectionController ivar
		NSDictionary *ccShortcuts = MSHookIvar<NSDictionary *>(self, "_moduleControllersByID");
		// grab the timer cc button from the ivar's mutable array
		SBCCShortcutButtonController *timerButton = [ccShortcuts objectForKey:@"com.apple.mobiletimer"];
		// hide the image view so we can see the label better
		[[[[timerButton view] subviews] lastObject] setHidden:YES];
		// create a label to display the time
		timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [[timerButton view] frame].size.width, [[timerButton view] frame].size.height)];
		[timeRemainingLabel setText:[self prettyPrintTime:secondsBetweenNowAndFireDate]];
		[timeRemainingLabel setFont:[UIFont systemFontOfSize:12]];
		[timeRemainingLabel setTextAlignment:NSTextAlignmentCenter];
		[[timerButton view] addSubview:timeRemainingLabel];

		// create a timer to keep our label up-to-date
		pendingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(updateLabel:) userInfo:nil repeats:YES];
	}
	return %orig;
}

- (void)viewDidDisappear:(BOOL)animated
{
	[pendingTimer invalidate];
	pendingTimer = nil;
	%orig();
}

%new
// giving credit where due
// http://stackoverflow.com/a/7059284/3411191
- (NSString *)prettyPrintTime:(int)seconds {
	int hours = floor(seconds /  (60 * 60));
	float minute_divisor = seconds % (60 * 60);
	int minutes = floor(minute_divisor / 60);
	float seconds_divisor = seconds % 60;
	seconds = ceil(seconds_divisor);
	if (hours > 0) {
		return [NSString stringWithFormat:@"%0.2d:%0.2d:%0.2d", hours, minutes, seconds];
	} else {
		return [NSString stringWithFormat:@"%0.2d:%0.2d", minutes, seconds];
	}
}

%end