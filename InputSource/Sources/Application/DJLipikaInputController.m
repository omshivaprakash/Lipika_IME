/*
 * LipikaIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2013 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

#import "DJLipikaInputController.h"
#import "DJPreferenceController.h"
#import "DJConversionController.h"
#import "DJLipikaUserSettings.h"
#import "DJLipikaAppDelegate.h"
#import "Constants.h"
#import "DJLogger.h"

@implementation DJLipikaInputController

#pragma mark - Overridden methods of IMKInputController

-(id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self == nil) {
        return self;
    }
    manager = [[DJLipikaClientManager alloc] initWithClient:[[DJLipikaClientDelegate alloc] initWithClient:inputClient]];
    return self;
}

-(void)candidateSelected:(NSAttributedString *)candidateString {
    [manager onCandidateSelected:candidateString.string];
}

-(NSMenu *)menu {
	return [(DJLipikaAppDelegate *)[NSApp delegate] mainMenu];
}

#pragma mark - IMKServerInput and IMKStateSetting protocol methods

-(BOOL)inputText:(NSString *)string client:(id)sender {
    return [manager inputText:string];
}

-(void)commitComposition:(id)sender {
    [manager onEndSession];
}

-(BOOL)didCommandBySelector:(SEL)aSelector client:(id)sender {
    if (aSelector == @selector(deleteBackward:)) {
        return [manager handleBackspace];
    }
    else if (aSelector == @selector(cancelOperation:)) {
        return [manager handleCancel];
    }
    else {
        [manager commit];
    }
    return NO;
}

-(NSArray *)candidates:(id)sender {
    return [manager.candidateManager candidates];
}

// This message is sent when our client gains focus
-(void)activateServer:(id)sender {
    [manager onFocus];
}

// This message is sent when our client looses focus
-(void)deactivateServer:(id)sender {
    [manager onUnFocus];
}

-(IBAction)showPreferences:(id)sender {
/*
 sender is a NSDictionary object with the following keys:
 {
    IMKCommandClient = "<IMKInputSession>";
    IMKCommandMenuItem = "<NSMenuItem>";
    IMKMenuTitle = "<NSString>";
 }
 */
    NSMenuItem *menuItem = [sender objectForKey:kIMKCommandMenuItemName];
    if ([menuItem tag] == 1) {     // Preferrence
        [self showPreferenceImpl:menuItem];
    }
    else if ([menuItem tag] == 2) { // Convert file
        [self showFileConversionImpl:menuItem];
    }
    else if ([menuItem tag] > 2) { // Input Schemes
        [self changeInputScheme:menuItem];
    }
    else {
        [NSException raise:@"Unknown tag" format:@"Unknown menu tag: %ld", [menuItem tag]];
    }
}

#pragma mark - DJLipikaInputController's instance methods

-(void)clearAllOnStates:(NSMenu *)rootMenu {
    NSArray *peerItems = [rootMenu itemArray];
    [peerItems enumerateObjectsUsingBlock:^(NSMenuItem *obj, NSUInteger idx, BOOL *stop) {
        [obj setState:NSOffState];
        if ([obj hasSubmenu]) [self clearAllOnStates:[obj submenu]];
    }];
}

-(void)changeInputScheme:(NSMenuItem *)menuItem {
    NSString *name = [menuItem title];
    NSString *subMenuTitle = [[[menuItem parentItem] submenu] title];
    BOOL isGoogleItem = [subMenuTitle isEqualToString:DJGoogleSubMenu];
    BOOL isSchemeItem = [subMenuTitle isEqualToString:DJSchemeSubMenu];
    BOOL isScriptItem = [subMenuTitle isEqualToString:DJScriptSubMenu];
    // Try to change to specified script and scheme
    @try {
        if (isSchemeItem) {
            [manager changeToSchemeWithName:name forScript:nil];
        }
        else if (isScriptItem) {
            [manager changeToSchemeWithName:nil forScript:name];
        }
        else if (isGoogleItem) {
            [manager changeToCustomSchemeWithName:name];
        }
        else {
            [NSException raise:@"Unknown sub-menu title" format:@"Unknown sub-menu title: %@", subMenuTitle];
        }
    }
    @catch (NSException *exception) {
        NSBeep();
        logFatal(@"Error initializing scheme. %@", [exception description]);
        return;
    }
    [self clearAllOnStates:[[menuItem parentItem] menu]];
    // Turn on state for the script and scheme
    if (isGoogleItem) {
        [menuItem setState:NSOnState];
    }
    else {
        [[[[[(DJLipikaAppDelegate *)[NSApp delegate] mainMenu] itemWithTitle:DJInputMenuItemTitle] submenu] itemWithTitle:[DJLipikaUserSettings schemeName]] setState:NSOnState];
        [[[[[(DJLipikaAppDelegate *)[NSApp delegate] mainMenu] itemWithTitle:DJOutputMenuItemTitle] submenu] itemWithTitle:[DJLipikaUserSettings scriptName]] setState:NSOnState];
    }
}

-(void)showPreferenceImpl:(NSMenuItem *)menuItem {
    static DJPreferenceController *preference;
    if (!preference) {
        preference = [[DJPreferenceController alloc] initWithWindowNibName:@"Preferences"];
    }
    [NSApp activateIgnoringOtherApps:YES];
    [[preference window] makeKeyAndOrderFront:self];
    [preference showWindow:self];
}

-(void)showFileConversionImpl:(NSMenuItem *)menuItem {
    static DJConversionController *preference;
    if (!preference) {
        preference = [[DJConversionController alloc] initWithWindowNibName:@"FileConversion"];
    }
    [NSApp activateIgnoringOtherApps:YES];
    [[preference window] makeKeyAndOrderFront:self];
    [preference showWindow:self];
}

@end
