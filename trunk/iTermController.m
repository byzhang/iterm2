// -*- mode:objc -*-
// $Id: iTermController.m,v 1.78 2008-10-17 04:02:45 yfabian Exp $
/*
 **  iTermController.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **      Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the main application delegate and handles the addressbook functions.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import <iTerm/iTermController.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYSession.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/ITAddressBookMgr.h>
#import <iTerm/iTermGrowlDelegate.h>
#import "PasteboardHistory.h"
#import <Carbon/Carbon.h>
#import "iTermApplicationDelegate.h"
#import "iTermApplication.h"
#import "UKCrashReporter/UKCrashReporter.h"
#import "PTYTab.h"
#import "iTermKeyBindingMgr.h"
#import "iTerm/PseudoTerminal.h"
#import "iTermExpose.h"

@interface NSApplication (Undocumented)
- (void)_cycleWindowsReversed:(BOOL)back;
@end

// Constants for saved window arrangement key names.
static NSString* DEFAULT_ARRANGEMENT_NAME = @"Default";
static NSString* APPLICATION_SUPPORT_DIRECTORY = @"~/Library/Application Support";
static NSString *SUPPORT_DIRECTORY = @"~/Library/Application Support/iTerm";
static NSString *SCRIPT_DIRECTORY = @"~/Library/Application Support/iTerm/Scripts";
static NSString* WINDOW_ARRANGEMENTS = @"Window Arrangements";

// Comparator for sorting encodings
static NSInteger _compareEncodingByLocalizedName(id a, id b, void *unused)
{
    NSString *sa = [NSString localizedNameOfStringEncoding: [a unsignedIntValue]];
    NSString *sb = [NSString localizedNameOfStringEncoding: [b unsignedIntValue]];
    return [sa caseInsensitiveCompare: sb];
}


@implementation iTermController

static iTermController* shared = nil;
static BOOL initDone = NO;

+ (iTermController*)sharedInstance;
{
    if(!shared && !initDone) {
        shared = [[iTermController alloc] init];
        initDone = YES;
    }

    return shared;
}

+ (void)sharedInstanceRelease
{
    [shared release];
    shared = nil;
}


// init
- (id)init
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[iTermController init]",
          __FILE__, __LINE__);
#endif
    self = [super init];

    UKCrashReporterCheckForCrash();

    // create the iTerm directory if it does not exist
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // create the "~/Library/Application Support" directory if it does not exist
    if([fileManager fileExistsAtPath: [APPLICATION_SUPPORT_DIRECTORY stringByExpandingTildeInPath]] == NO)
        [fileManager createDirectoryAtPath: [APPLICATION_SUPPORT_DIRECTORY stringByExpandingTildeInPath] attributes: nil];

    if([fileManager fileExistsAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath]] == NO)
        [fileManager createDirectoryAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath] attributes: nil];

    terminalWindows = [[NSMutableArray alloc] init];
    keyWindowIndexMemo_ = -1;

    // Activate Growl
    /*
     * Need to add routine in iTerm prefs for Growl support and
     * PLIST check here.
     */
    gd = [iTermGrowlDelegate sharedInstance];

    return (self);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[iTermController dealloc]",
        __FILE__, __LINE__);
#endif
    // Close all terminal windows
    while ([terminalWindows count] > 0) {
        [[terminalWindows objectAtIndex:0] close];
    }
    NSAssert([terminalWindows count] == 0, @"Expected terminals to be gone");
    [terminalWindows release];

    // Release the GrowlDelegate
    if(gd)
        [gd release];

    [super dealloc];
}

- (void)updateWindowTitles
{
    for (PseudoTerminal* terminal in terminalWindows) {
        if ([terminal currentSessionName]) {
            [terminal setWindowTitle];
        }
    }
}

// Action methods
- (IBAction)newWindow:(id)sender
{
    [self launchBookmark:nil inTerminal: nil];
}

- (void) newSessionInTabAtIndex: (id) sender
{
    Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkWithGuid:[sender representedObject]];
    if (bookmark) {
        [self launchBookmark:bookmark inTerminal:FRONT];
    }
}

- (void) showHideFindBar
{
    [[self currentTerminal] showHideFindBar];
}

- (int)keyWindowIndexMemo
{
    return keyWindowIndexMemo_;
}

- (void)setKeyWindowIndexMemo:(int)i
{
    keyWindowIndexMemo_ = i;
}

- (void)newSessionInWindowAtIndex: (id) sender
{
    Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkWithGuid:[sender representedObject]];
    if (bookmark) {
        [self launchBookmark:bookmark inTerminal:nil];
    }
}

// meant for action for menu items that have a submenu
- (void) noAction: (id) sender
{

}

- (IBAction)newSession:(id)sender
{
    [self launchBookmark:nil inTerminal: FRONT];
}

// navigation
- (IBAction)previousTerminal:(id)sender
{
    [NSApp _cycleWindowsReversed:YES];
}
- (IBAction)nextTerminal:(id)sender
{
    [NSApp _cycleWindowsReversed:NO];
}

- (BOOL)hasWindowArrangement
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:WINDOW_ARRANGEMENTS] objectForKey:DEFAULT_ARRANGEMENT_NAME] != nil;
}

- (void)saveWindowArrangement
{
    NSMutableArray* terminalArrangements = [NSMutableArray arrayWithCapacity:[terminalWindows count]];
    for (PseudoTerminal* terminal in terminalWindows) {
        if (![terminal isHotKeyWindow]) {
            [terminalArrangements addObject:[terminal arrangement]];
        }
    }
    NSMutableDictionary* arrangements = [NSMutableDictionary dictionaryWithObject:terminalArrangements
                                                                           forKey:DEFAULT_ARRANGEMENT_NAME];
    [[NSUserDefaults standardUserDefaults] setObject:arrangements forKey:WINDOW_ARRANGEMENTS];

    // Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"iTermSavedArrangementChanged"
                                                        object:nil
                                                      userInfo:nil];
}

- (void)loadWindowArrangement
{
    NSDictionary* arrangements = [[NSUserDefaults standardUserDefaults] objectForKey:WINDOW_ARRANGEMENTS];
    NSArray* terminalArrangements = [arrangements objectForKey:DEFAULT_ARRANGEMENT_NAME];
    for (NSDictionary* terminalArrangement in terminalArrangements) {
        PseudoTerminal* term = [PseudoTerminal terminalWithArrangement:terminalArrangement];
        [self addInTerminals:term];
    }
}

// Return all the terminals in the given screen.
- (NSArray*)_terminalsInScreen:(NSScreen*)screen
{
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:0];
    for (PseudoTerminal* term in terminalWindows) {
        if ([[term window] deepestScreen] == screen) {
            [result addObject:term];
        }
    }
    return result;
}

// Arrange terminals horizontally, in multiple rows if needed.
- (void)arrangeTerminals:(NSArray*)terminals inFrame:(NSRect)frame
{
    if ([terminals count] == 0) {
        return;
    }

    // Determine the new width for all windows, not less than some minimum.
    float x = 0;
    float w = frame.size.width / [terminals count];
    float minWidth = 400;
    for (PseudoTerminal* term in terminals) {
        float termMinWidth = [term minWidth];
        minWidth = MAX(minWidth, termMinWidth);
    }
    if (w < minWidth) {
        // Width would be too narrow. Pick the smallest width larger than minWidth
        // that evenly  divides the screen up horizontally.
        int maxWindowsInOneRow = floor(frame.size.width / minWidth);
        w = frame.size.width / maxWindowsInOneRow;
    }

    // Find the window whose top is nearest the top of the screen. That will be the
    // new top of all the windows in the first row.
    float highestTop = 0;
    for (PseudoTerminal* terminal in terminals) {
        NSRect r = [[terminal window] frame];
        if (r.origin.y < frame.origin.y) {
            // Bottom of window is below dock. Pretend its bottom abuts the dock.
            r.origin.y = frame.origin.y;
        }
        float top = r.origin.y + r.size.height;
        if (top > highestTop) {
            highestTop = top;
        }
    }

    // Ensure the bottom of the last row of windows will be above the bottom of the screen.
    int rows = ceil((w * (float)[terminals count]) / frame.size.width);
    float maxHeight = frame.size.height / rows;
    if (rows > 1 && highestTop - maxHeight * rows < frame.origin.y) {
        highestTop = frame.origin.y + maxHeight * rows;
    }

    if (highestTop > frame.origin.y + frame.size.height) {
        // Don't let the top of the first row go above the top of the screen. This is just
        // paranoia.
        highestTop = frame.origin.y + frame.size.height;
    }

    float yOffset = 0;
    NSMutableArray *terminalsCopy = [NSMutableArray arrayWithArray:terminals];

    // Grab the window that would move the least and move it. This isn't a global
    // optimum, but it is reasonably stable.
    while ([terminalsCopy count] > 0) {
        // Find the leftmost terminal.
        PseudoTerminal* terminal = nil;
        float bestDistance = 0;
        int bestIndex = 0;

        for (int j = 0; j < [terminalsCopy count]; ++j) {
            PseudoTerminal* t = [terminalsCopy objectAtIndex:j];
            if (t) {
                NSRect r = [[t window] frame];
                float y = highestTop - r.size.height + yOffset;
                float dx = x - r.origin.x;
                float dy = y - r.origin.y;
                float distance = dx*dx + dy*dy;
                if (terminal == nil || distance < bestDistance) {
                    bestDistance = distance;
                    terminal = t;
                    bestIndex = j;
                }
            }
        }

        // Remove it from terminalsCopy.
        [terminalsCopy removeObjectAtIndex:bestIndex];

        // Create an animation to move it to its new position.
        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:3];

        [dict setObject:[terminal window] forKey:NSViewAnimationTargetKey];
        [dict setObject:[NSValue valueWithRect:[[terminal window] frame]]
                 forKey:NSViewAnimationStartFrameKey];
        float y = highestTop - [[terminal window] frame].size.height;
        float h = MIN(maxHeight, [[terminal window] frame].size.height);
        if (rows > 1) {
            // The first row can be a bit ragged vertically but subsequent rows line up
            // at the tops of the windows.
            y = frame.origin.y + frame.size.height - h;
        }
        [dict setObject:[NSValue valueWithRect:NSMakeRect(x,
                                                          y + yOffset,
                                                          w,
                                                          h)]
                 forKey:NSViewAnimationEndFrameKey];
        x += w;
        if (x > frame.size.width - w) {
            // Wrap around to the next row of windows.
            x = 0;
            yOffset -= maxHeight;
        }
        NSViewAnimation* theAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:dict, nil]];

        // Set some additional attributes for the animation.
        [theAnim setDuration:0.75];
        [theAnim setAnimationCurve:NSAnimationEaseInOut];

        // Run the animation.
        [theAnim startAnimation];

        // The animation has finished, so go ahead and release it.
        [theAnim release];
    }
}

- (void)arrangeHorizontally
{
    [iTermExpose exitIfActive];
    
    // Un-full-screen each window. This is done in two steps because
    // toggleFullScreen deallocs self.
    for (PseudoTerminal* t in terminalWindows) {
        if ([t fullScreen]) {
            [t toggleFullScreen:self];
        }
    }

    // For each screen, find the terminals in it and arrange them. This way
    // terminals don't move from screen to screen in this operation.
    for (NSScreen* screen in [NSScreen screens]) {
        [self arrangeTerminals:[self _terminalsInScreen:screen]
                       inFrame:[screen visibleFrame]];
    }
}

- (PseudoTerminal*)currentTerminal
{
    return FRONT;
}

- (void)terminalWillClose:(PseudoTerminal*)theTerminalWindow
{
    if (FRONT == theTerminalWindow) {
        [self setCurrentTerminal: nil];
    }
    if (theTerminalWindow) {
        [self removeFromTerminalsAtIndex:[terminalWindows indexOfObject:theTerminalWindow]];
    }
}

// Build sorted list of encodings
- (NSArray *) sortedEncodingList
{
    NSStringEncoding const *p;
    NSMutableArray *tmp = [NSMutableArray array];

    for (p = [NSString availableStringEncodings]; *p; ++p)
        [tmp addObject:[NSNumber numberWithUnsignedInt:*p]];
    [tmp sortUsingFunction: _compareEncodingByLocalizedName context:NULL];

    return (tmp);
}

- (void)_addBookmark:(Bookmark*)bookmark toMenu:(NSMenu*)aMenu target:(id)aTarget withShortcuts:(BOOL)withShortcuts selector:(SEL)selector alternateSelector:(SEL)alternateSelector
{
    NSMenuItem* aMenuItem = [[[NSMenuItem alloc] initWithTitle:[bookmark objectForKey:KEY_NAME]
                                                        action:selector
                                                 keyEquivalent:@""] autorelease];
    if (withShortcuts) {
        if ([bookmark objectForKey:KEY_SHORTCUT] != nil) {
            NSString* shortcut = [bookmark objectForKey:KEY_SHORTCUT];
            shortcut = [shortcut lowercaseString];
            [aMenuItem setKeyEquivalent:shortcut];
        }
    }

    unsigned int modifierMask = NSCommandKeyMask | NSControlKeyMask;
    [aMenuItem setKeyEquivalentModifierMask:modifierMask];
    [aMenuItem setRepresentedObject:[bookmark objectForKey:KEY_GUID]];
    [aMenuItem setTarget:aTarget];
    [aMenu addItem:aMenuItem];

    if (alternateSelector) {
        aMenuItem = [[aMenuItem copy] autorelease];
        [aMenuItem setKeyEquivalentModifierMask:modifierMask | NSAlternateKeyMask];
        [aMenuItem setAlternate:YES];
        [aMenuItem setAction:alternateSelector];
        [aMenuItem setTarget:self];
        [aMenu addItem:aMenuItem];
    }
}

- (void)_addBookmarksForTag:(NSString*)tag toMenu:(NSMenu*)aMenu target:(id)aTarget withShortcuts:(BOOL)withShortcuts selector:(SEL)selector alternateSelector:(SEL)alternateSelector openAllSelector:(SEL)openAllSelector
{
    NSMenuItem* aMenuItem = [[[NSMenuItem alloc] initWithTitle:tag action:@selector(noAction:) keyEquivalent:@""] autorelease];
    NSMenu* subMenu = [[[NSMenu alloc] init] autorelease];
    int count = 0;
    for (int i = 0; i < [[BookmarkModel sharedInstance] numberOfBookmarks]; ++i) {
        Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkAtIndex:i];
        NSArray* tags = [bookmark objectForKey:KEY_TAGS];
        for (int j = 0; j < [tags count]; ++j) {
            if ([tag localizedCaseInsensitiveCompare:[tags objectAtIndex:j]] == NSOrderedSame) {
                ++count;
                [self _addBookmark:bookmark
                            toMenu:subMenu
                            target:aTarget
                     withShortcuts:withShortcuts
                          selector:selector
                 alternateSelector:alternateSelector];
                break;
            }
        }
    }
    [aMenuItem setSubmenu:subMenu];
    [aMenuItem setTarget:self];
    [aMenu addItem:aMenuItem];

    if (openAllSelector && count > 1) {
        [subMenu addItem:[NSMenuItem separatorItem]];
        aMenuItem = [[[NSMenuItem alloc] initWithTitle:
                      NSLocalizedStringFromTableInBundle(@"Open All",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass: [iTermController class]],
                                                         @"Context Menu")
                                                action:openAllSelector
                                         keyEquivalent:@""] autorelease];
        unsigned int modifierMask = NSCommandKeyMask | NSControlKeyMask;
        [aMenuItem setKeyEquivalentModifierMask:modifierMask];
        [aMenuItem setRepresentedObject:subMenu];
        if ([self respondsToSelector:openAllSelector]) {
            [aMenuItem setTarget:self];
        } else {
            assert([aTarget respondsToSelector:openAllSelector]);
            [aMenuItem setTarget:aTarget];
        }
        [subMenu addItem:aMenuItem];
        aMenuItem = [[aMenuItem copy] autorelease];
    }
}

- (void)_newSessionsInManyWindowsInMenu:(NSMenu*)parent
{
    for (NSMenuItem* item in [parent itemArray]) {
        if (![item isSeparatorItem] && ![item submenu]) {
            NSString* guid = [item representedObject];
            Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkWithGuid:guid];
            if (bookmark) {
                [self launchBookmark:bookmark inTerminal:nil];
            }
        } else if (![item isSeparatorItem] && [item submenu]) {
            [self _newSessionsInManyWindowsInMenu:[item submenu]];
        }
    }
}

- (void)newSessionsInManyWindows:(id)sender
{
    [self _newSessionsInManyWindowsInMenu:[sender representedObject]];
}

- (void)_openNewSessionsInWindow:(NSMenu*)parent
{
    PseudoTerminal* term = [self currentTerminal];
    for (NSMenuItem* item in [parent itemArray]) {
        if (![item isSeparatorItem] && ![item submenu] && ![item isAlternate]) {
            NSString* guid = [item representedObject];
            Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkWithGuid:guid];
            if (bookmark) {
                if (!term) {
                    PTYSession* session = [self launchBookmark:bookmark inTerminal:nil];
                    term = [[session tab] realParentWindow];
                } else {
                    [self launchBookmark:bookmark inTerminal:term];
                }
            }
        } else if (![item isSeparatorItem] && [item submenu] && ![item isAlternate]) {
            NSMenu* sub = [item submenu];
            [self _openNewSessionsInWindow:sub];
        }
    }
}

- (void)newSessionsInWindow:(id)sender
{
    [self _openNewSessionsInWindow:[sender representedObject]];
}

- (void)addBookmarksToMenu:(NSMenu *)aMenu target:(id)aTarget withShortcuts:(BOOL)withShortcuts selector:(SEL)selector openAllSelector:(SEL)openAllSelector alternateSelector:(SEL)alternateSelector
{
    NSArray* tags = [[BookmarkModel sharedInstance] allTags];
    int count = 0;
    NSArray* sortedTags = [tags sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (int i = 0; i < [sortedTags count]; ++i) {
        [self _addBookmarksForTag:[sortedTags objectAtIndex:i]
                           toMenu:aMenu
                           target:aTarget
                    withShortcuts:withShortcuts
                         selector:selector
                alternateSelector:alternateSelector
                  openAllSelector:openAllSelector];
        ++count;
    }
    for (int i = 0; i < [[BookmarkModel sharedInstance] numberOfBookmarks]; ++i) {
        Bookmark* bookmark = [[BookmarkModel sharedInstance] bookmarkAtIndex:i];
        if ([[bookmark objectForKey:KEY_TAGS] count] == 0) {
            ++count;
            [self _addBookmark:bookmark
                        toMenu:aMenu
                        target:aTarget
                 withShortcuts:withShortcuts
                      selector:selector
             alternateSelector:alternateSelector];
        }
    }

    if (count > 1) {
        [aMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem* aMenuItem = [[[NSMenuItem alloc] initWithTitle:
                                  NSLocalizedStringFromTableInBundle(@"Open All",
                                                                     @"iTerm",
                                                                     [NSBundle bundleForClass: [iTermController class]],
                                                                     @"Context Menu")
                                                            action:openAllSelector
                                                     keyEquivalent:@""] autorelease];
        unsigned int modifierMask = NSCommandKeyMask | NSControlKeyMask;
        [aMenuItem setKeyEquivalentModifierMask:modifierMask];
        [aMenuItem setRepresentedObject:aMenu];
        if ([self respondsToSelector:openAllSelector]) {
            [aMenuItem setTarget:self];
        } else {
            assert([aTarget respondsToSelector:openAllSelector]);
            [aMenuItem setTarget:aTarget];
        }
        [aMenu addItem:aMenuItem];
        aMenuItem = [[aMenuItem copy] autorelease];
    }
}

- (void)irAdvance:(int)dir
{
    [FRONT irAdvance:dir];
}

+ (void)switchToSpaceInBookmark:(Bookmark*)aDict
{
    if ([aDict objectForKey:KEY_SPACE]) {
        int spaceNum = [[aDict objectForKey:KEY_SPACE] intValue];
        if (spaceNum > 0 && spaceNum < 10) {
            // keycodes for digits 1-9. Send control-n to switch spaces.
            // TODO: This would get remapped by the event tap. It requires universal access to be on and
            // spaces to be configured properly. But we don't tell the users this.
            int codes[] = { 18, 19, 20, 21, 23, 22, 26, 28, 25 };
            CGEventRef e = CGEventCreateKeyboardEvent (NULL, (CGKeyCode)codes[spaceNum - 1], true);
            CGEventSetFlags(e, kCGEventFlagMaskControl);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);

            e = CGEventCreateKeyboardEvent (NULL, (CGKeyCode)codes[spaceNum - 1], false);
            CGEventSetFlags(e, kCGEventFlagMaskControl);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);
        }
    }
}

// Executes an addressbook command in new window or tab
- (id)launchBookmark:(NSDictionary *)bookmarkData inTerminal:(PseudoTerminal *)theTerm
{
    PseudoTerminal *term;
    NSDictionary *aDict;

    aDict = bookmarkData;
    if (aDict == nil) {
        aDict = [[BookmarkModel sharedInstance] defaultBookmark];
        if (!aDict) {
            NSMutableDictionary* temp = [[[NSMutableDictionary alloc] init] autorelease];
            [ITAddressBookMgr setDefaultsInBookmark:temp];
            [temp setObject:[BookmarkModel freshGuid] forKey:KEY_GUID];
            aDict = temp;
        }
    }

    // Where do we execute this command?
    if (theTerm == nil) {
        [iTermController switchToSpaceInBookmark:aDict];
        term = [[[PseudoTerminal alloc] initWithSmartLayout:YES 
                                                 windowType:[aDict objectForKey:KEY_WINDOW_TYPE] ? [[aDict objectForKey:KEY_WINDOW_TYPE] intValue] : WINDOW_TYPE_NORMAL
                                                     screen:[aDict objectForKey:KEY_SCREEN] ? [[aDict objectForKey:KEY_SCREEN] intValue] : -1] autorelease];
        [self addInTerminals:term];
    } else {
        term = theTerm;
    }

    PTYSession* session = [term addNewSession:aDict];

    // This function is activated from the dock icon's context menu so make sure
    // that the new window is on top of all other apps' windows. For some reason,
    // makeKeyAndOrderFront does nothing.
    if (![[term window] isKeyWindow]) {
        [NSApp arrangeInFront:self];
    }

    return session;
}

- (id)launchBookmark:(NSDictionary *)bookmarkData inTerminal:(PseudoTerminal *)theTerm withCommand:(NSString *)command
{
    PseudoTerminal *term;
    NSDictionary *aDict;

    aDict = bookmarkData;
    if (aDict == nil) {
        aDict = [[BookmarkModel sharedInstance] defaultBookmark];
        if (!aDict) {
            NSMutableDictionary* temp = [[[NSMutableDictionary alloc] init] autorelease];
            [ITAddressBookMgr setDefaultsInBookmark:temp];
            [temp setObject:[BookmarkModel freshGuid] forKey:KEY_GUID];
            aDict = temp;
        }
    }

    // Where do we execute this command?
    if (theTerm == nil) {
        [iTermController switchToSpaceInBookmark:aDict];
        term = [[[PseudoTerminal alloc] initWithSmartLayout:YES 
                                                 windowType:[aDict objectForKey:KEY_WINDOW_TYPE] ? [[aDict objectForKey:KEY_WINDOW_TYPE] intValue] : WINDOW_TYPE_NORMAL
                                                     screen:[aDict objectForKey:KEY_SCREEN] ? [[aDict objectForKey:KEY_SCREEN] intValue] : -1] autorelease];
        [self addInTerminals:term];
    } else {
        term = theTerm;
    }

    return [term addNewSession: aDict withCommand: command];
}

- (id)launchBookmark:(NSDictionary *)bookmarkData inTerminal:(PseudoTerminal *)theTerm withURL:(NSString *)url
{
    PseudoTerminal *term;
    NSDictionary *aDict;

    aDict = bookmarkData;
    // $$ is a prefix/suffix of a variabe.
    if (aDict == nil || [[ITAddressBookMgr bookmarkCommand:aDict] isEqualToString:@"$$"]) {
        Bookmark* prototype = aDict;
        if (!prototype) {
            prototype = [[BookmarkModel sharedInstance] defaultBookmark];
        }
        if (!prototype) {
            NSMutableDictionary* temp = [[[NSMutableDictionary alloc] init] autorelease];
            [ITAddressBookMgr setDefaultsInBookmark:temp];
            [temp setObject:[BookmarkModel freshGuid] forKey:KEY_GUID];
            prototype = temp;
        }

        NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithDictionary:prototype];
        NSURL *urlRep = [NSURL URLWithString: url];
        NSString *urlType = [urlRep scheme];

        if ([urlType compare:@"ssh" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSMutableString *tempString = [NSMutableString stringWithString:@"ssh "];
            if ([urlRep user]) [tempString appendFormat:@"-l %@ ", [urlRep user]];
            if ([urlRep port]) [tempString appendFormat:@"-p %@ ", [urlRep port]];
            if ([urlRep host]) [tempString appendString:[urlRep host]];
            [tempDict setObject:tempString forKey:KEY_COMMAND];
            aDict = tempDict;
        }
        else if ([urlType compare:@"ftp" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSMutableString *tempString = [NSMutableString stringWithFormat:@"ftp %@", url];
            [tempDict setObject:tempString forKey:KEY_COMMAND];
            aDict = tempDict;
        }
        else if ([urlType compare:@"telnet" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSMutableString *tempString = [NSMutableString stringWithString:@"telnet "];
            if ([urlRep user]) [tempString appendFormat:@"-l %@ ", [urlRep user]];
            if ([urlRep host]) {
                [tempString appendString:[urlRep host]];
                if ([urlRep port]) [tempString appendFormat:@" %@", [urlRep port]];
            }
            [tempDict setObject:tempString forKey:KEY_COMMAND];
            aDict = tempDict;
        }
    }

    // Where do we execute this command?
    if (theTerm == nil) {
        [iTermController switchToSpaceInBookmark:aDict];
        term = [[[PseudoTerminal alloc] initWithSmartLayout:YES
                                                 windowType:[aDict objectForKey:KEY_WINDOW_TYPE] ? [[aDict objectForKey:KEY_WINDOW_TYPE] intValue] : WINDOW_TYPE_NORMAL
                                                     screen:[aDict objectForKey:KEY_SCREEN] ? [[aDict objectForKey:KEY_SCREEN] intValue] : -1] autorelease];
        [self addInTerminals: term];
    } else {
        term = theTerm;
    }

    return [term addNewSession: aDict withURL: url];
}

- (void)launchScript:(id)sender
{
    NSString *fullPath = [NSString stringWithFormat: @"%@/%@", [SCRIPT_DIRECTORY stringByExpandingTildeInPath], [sender title]];

    if ([[[sender title] pathExtension] isEqualToString: @"scpt"]) {
        NSAppleScript *script;
        NSDictionary *errorInfo = [NSDictionary dictionary];
        NSURL *aURL = [NSURL fileURLWithPath: fullPath];

        // Make sure our script suite registry is loaded
        [NSScriptSuiteRegistry sharedScriptSuiteRegistry];

        script = [[NSAppleScript alloc] initWithContentsOfURL: aURL error: &errorInfo];
        [script executeAndReturnError: &errorInfo];
        [script release];
    }
    else {
        [[NSWorkspace sharedWorkspace] launchApplication:fullPath];
    }

}

- (PTYTextView *) frontTextView
{
    return ([[FRONT currentSession] TEXTVIEW]);
}

-(int)numberOfTerminals
{
    return [terminalWindows count];
}

- (NSUInteger)indexOfTerminal:(PseudoTerminal*)terminal
{
    return [terminalWindows indexOfObject:terminal];
}

-(PseudoTerminal*)terminalAtIndex:(int)i
{
    return [terminalWindows objectAtIndex:i];
}

static PseudoTerminal* GetHotkeyWindow()
{
    iTermController* cont = [iTermController sharedInstance];
    NSArray* terminals = [cont terminals];
    for (PseudoTerminal* term in terminals) {
        if ([term isHotKeyWindow]) {
            return term;
        }
    }
    return nil;
}

- (PseudoTerminal*)hotKeyWindow
{
    return GetHotkeyWindow();
}

static void RollInHotkeyTerm(PseudoTerminal* term)
{
    NSLog(@"Roll in visor");
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    NSRect rect = [[term window] frame];
    [NSApp activateIgnoringOtherApps:YES];
    [[term window] makeKeyAndOrderFront:nil];
    switch ([term windowType]) {
        case WINDOW_TYPE_NORMAL:
            rect.origin.x = -rect.size.width;
            rect.origin.y = -rect.size.height;
            [[term window] setFrame:rect display:NO];

            rect.origin.x = (screenFrame.size.width - rect.size.width) / 2;
            rect.origin.y = screenFrame.origin.y + (screenFrame.size.height - rect.size.height) / 2;
            [[[term window] animator] setFrame:rect display:YES];
            break;

        case WINDOW_TYPE_TOP:
            rect.origin.y = screenFrame.origin.y + screenFrame.size.height - rect.size.height;
            [[[term window] animator] setFrame:rect display:YES];
            break;

        case WINDOW_TYPE_FULL_SCREEN:
            [[[term window] animator] setAlphaValue:1];
            break;
    }
}

static void OpenHotkeyWindow()
{
    NSLog(@"Open visor");
    iTermController* cont = [iTermController sharedInstance];
    Bookmark* bookmark = [[PreferencePanel sharedInstance] hotkeyBookmark];
    if (bookmark) {
        PTYSession* session = [cont launchBookmark:bookmark inTerminal:nil];
        PseudoTerminal* term = [[session tab] realParentWindow];
        [term setIsHotKeyWindow:YES];

        if ([term windowType] == WINDOW_TYPE_FULL_SCREEN) {
            [[term window] setAlphaValue:0];
        } else {
            // place it above the screen so it can be rolled in.
            NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
            NSRect rect = [[term window] frame];
            if ([term windowType] == WINDOW_TYPE_TOP) {
                rect.origin.y = screenFrame.origin.y + screenFrame.size.height + rect.size.height;
            } else {
                rect.origin.y = -rect.size.height;
                rect.origin.x = -rect.size.width;
            }
            [[term window] setFrame:rect display:YES];
        }
        RollInHotkeyTerm(term);
    }
}

- (void)resetWindowAlphaValues
{
    NSLog(@"Set window alpha values to 1.");
    for (PseudoTerminal* term in [[iTermController sharedInstance] terminals]) {
        [[term window] setAlphaValue:1];
    }
}

- (void)showNonHotKeyWindowsAndSetAlphaTo:(float)a
{
    PseudoTerminal* hotkeyTerm = GetHotkeyWindow();
    for (PseudoTerminal* term in [[iTermController sharedInstance] terminals]) {
        [[term window] setAlphaValue:a];
        if (term != hotkeyTerm) {
            [[term window] makeKeyAndOrderFront:nil];
        }
    }
    // Unhide all windows and bring the one that was at the top to the front.
    int i = [[iTermController sharedInstance] keyWindowIndexMemo];
    if (i >= 0 && i < [[[iTermController sharedInstance] terminals] count]) {
        [[[[[iTermController sharedInstance] terminals] objectAtIndex:i] window] makeKeyAndOrderFront:nil];
    }
}

- (void)showOtherWindows:(PseudoTerminal*)hotkeyTerm
{
    NSLog(@"make all non-visor windows key and order front.");
    // Only hotkey window was visible. Hide the app, make all windows transparent.
    [NSApp hide:nil];
    [self showNonHotKeyWindowsAndSetAlphaTo:0];
    // Reset window alpha values later. That will happen
    // after the [NSApp hide] takes effect, so the windows don't briefly appear and then
    // disappear.
    [[iTermController sharedInstance] performSelector:@selector(resetWindowAlphaValues)
                        withObject:nil
                        afterDelay:[[NSAnimationContext currentContext] duration]]; 
}

static void RollOutHotkeyTerm(PseudoTerminal* term, BOOL showOtherWindows)
{
    NSLog(@"Roll out visor");
    if (![[term window] isVisible]) {
        NSLog(@"RollOutHotkeyTerm returning because term isn't visible.");
        return;
    }
    BOOL temp = [term isHotKeyWindow];
    [term setIsHotKeyWindow:NO];
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    NSRect rect = [[term window] frame];
    switch ([term windowType]) {
        case WINDOW_TYPE_NORMAL:
            rect.origin.x = -rect.size.width;
            rect.origin.y = -rect.size.height;
            [[[term window] animator] setFrame:rect display:YES];
            break;

        case WINDOW_TYPE_TOP:
            rect.origin.y = screenFrame.size.height;
            NSLog(@"SLOW: Set y=%f", rect.origin.y);
            [[[term window] animator] setFrame:rect display:YES];
            break;

        case WINDOW_TYPE_FULL_SCREEN:
            [[[term window] animator] setAlphaValue:0];
            break;
    }

    [[term window] performSelector:@selector(orderOut:)
                        withObject:nil
                        afterDelay:[[NSAnimationContext currentContext] duration]]; 

    if (showOtherWindows) {
        [[iTermController sharedInstance] performSelector:@selector(showOtherWindows:)
                                               withObject:term
                                               afterDelay:[[NSAnimationContext currentContext] duration]]; 
    }
    [term setIsHotKeyWindow:temp];
}

- (void)showHotKeyWindow
{
    PseudoTerminal* hotkeyTerm = GetHotkeyWindow();
    if (hotkeyTerm) {
        NSLog(@"Showing existing visor");
        int i = 0;
        [[iTermController sharedInstance] setKeyWindowIndexMemo:-1];
        for (PseudoTerminal* term in [[iTermController sharedInstance] terminals]) {
            if (![NSApp isActive]) {
                if (term != hotkeyTerm) {
                    NSLog(@"orderOut non-visor window");
                    [[term window] orderOut:nil];
                    [term setIsOrderedOut:YES];
                }
            } else {
                if (term != hotkeyTerm && [[term window] isKeyWindow]) {
                    [[iTermController sharedInstance] setKeyWindowIndexMemo:i];
                }
            }
            i++;
        }
        NSLog(@"Activate iterm2");
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        RollInHotkeyTerm(hotkeyTerm);
    } else {
        NSLog(@"Open new visor window");
        if (![NSApp isActive]) {
            NSLog(@"iterm2 is not active");
            for (PseudoTerminal* term in [[iTermController sharedInstance] terminals]) {
                if (term != hotkeyTerm) {
                    NSLog(@"orderOut non-visor window");
                    [[term window] orderOut:nil];
                    [term setIsOrderedOut:YES];
                }
            }
        }
        OpenHotkeyWindow();
    }
}

- (BOOL)isHotKeyWindowOpen
{
    PseudoTerminal* term = GetHotkeyWindow();
    return term && [[term window] isVisible];
}

- (BOOL)_isAnyNontHotKeyWindowVisible
{
    PseudoTerminal* hotkeyTerm = GetHotkeyWindow();
    BOOL isAnyNonHotWindowVisible = NO;
    for (PseudoTerminal* term in [[iTermController sharedInstance] terminals]) {
        if (term != hotkeyTerm) {
            if ([[term window] isVisible]) {
                NSLog(@"found visible non-visor window");
                isAnyNonHotWindowVisible = YES;
                break;
            }
        }
    }
    return isAnyNonHotWindowVisible;
}

- (void)fastHideHotKeyWindow
{
    NSLog(@"fastHideHotKeyWindow");
    PseudoTerminal* term = GetHotkeyWindow();
    if (term) {
        NSLog(@"fastHideHotKeyWindow - found a hot term");
        // Temporarily tell the hotkeywindow that it's not hot so that it doesn't try to hide itself
        // when losing key status.
        BOOL temp = [term isHotKeyWindow];
        [term setIsHotKeyWindow:NO];

        // Immediately hide the hotkey window.
        [[term window] orderOut:nil];

        // Move the hotkey window to its offscreen location or its natural alpha value.
        NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
        NSRect rect = [[term window] frame];
        switch ([term windowType]) {
            case WINDOW_TYPE_NORMAL:
                rect.origin.x = -rect.size.width;
                rect.origin.y = -rect.size.height;
                [[term window] setFrame:rect display:YES];
                break;

            case WINDOW_TYPE_TOP:
                // Note that this rect is different than in RollOutHotkeyTerm(). For some reason,
                // in this code path, the screen's origin is not included. I don't know why.
                rect.origin.y = screenFrame.size.height + screenFrame.origin.y;
                NSLog(@"FAST: Set y=%f", rect.origin.y);
                [[term window] setFrame:rect display:YES];
                break;

            case WINDOW_TYPE_FULL_SCREEN:
                [[term window] setAlphaValue:0];
                break;
        }

        // Immediately show all other windows.
        [self showNonHotKeyWindowsAndSetAlphaTo:1];

        // Restore hotkey window's status.
        [term setIsHotKeyWindow:temp];
    }
}

- (void)hideHotKeyWindow:(PseudoTerminal*)hotkeyTerm
{
    NSLog(@"visor is key");
    BOOL isAnyNonHotWindowVisible = [self _isAnyNontHotKeyWindowVisible];
    RollOutHotkeyTerm(hotkeyTerm, !isAnyNonHotWindowVisible);
}

void OnHotKeyEvent(void)
{
    NSLog(@"hotkey pressed");
    PreferencePanel* prefPanel = [PreferencePanel sharedInstance];
    if ([prefPanel hotkeyTogglesWindow]) {
        NSLog(@"visor enabled");
        PseudoTerminal* hotkeyTerm = GetHotkeyWindow();
        if (hotkeyTerm) {
            NSLog(@"already have a visor created");
            if ([[hotkeyTerm window] isKeyWindow]) {
                [[iTermController sharedInstance] hideHotKeyWindow:hotkeyTerm];
            } else {
                NSLog(@"visor not key");
                [[iTermController sharedInstance] showHotKeyWindow];
            }
        } else {
            NSLog(@"no visor created yet");
            [[iTermController sharedInstance] showHotKeyWindow];
        }
    } else if ([NSApp isActive]) {
        NSWindow* prefWindow = [prefPanel window];
        NSWindow* appKeyWindow = [[NSApplication sharedApplication] keyWindow];
        if (prefWindow != appKeyWindow ||
            ![iTermApplication isTextFieldInFocus:[prefPanel hotkeyField]]) {
            [NSApp hide:nil];
        }
    } else {
        iTermController* controller = [iTermController sharedInstance];
        int n = [controller numberOfTerminals];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        if (n == 0) {
            [controller newWindow:nil];
        }
    }
}

- (BOOL)eventIsHotkey:(NSEvent*)e
{
    return (hotkeyCode_ &&
            ([e modifierFlags] & hotkeyModifiers_) == hotkeyModifiers_ &&
            [e keyCode] == hotkeyCode_);
}

/*
 * The callback is passed a proxy for the tap, the event type, the incoming event,
 * and the refcon the callback was registered with.
 * The function should return the (possibly modified) passed in event,
 * a newly constructed event, or NULL if the event is to be deleted.
 *
 * The CGEventRef passed into the callback is retained by the calling code, and is
 * released after the callback returns and the data is passed back to the event
 * system.  If a different event is returned by the callback function, then that
 * event will be released by the calling code along with the original event, after
 * the event data has been passed back to the event system.
 */
static CGEventRef OnTappedEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    iTermController* cont = refcon;
    if (type == kCGEventTapDisabledByTimeout) {
        NSLog(@"kCGEventTapDisabledByTimeout");
        if (cont->machPortRef) {
            NSLog(@"Re-enabling event tap");
            CGEventTapEnable(cont->machPortRef, true);
        }
        return NULL;
    } else if (type == kCGEventTapDisabledByUserInput) {
        NSLog(@"kCGEventTapDisabledByUserInput");
        if (cont->machPortRef) {
            NSLog(@"Re-enabling event tap");
            CGEventTapEnable(cont->machPortRef, true);
        }
        return NULL;
    }

    NSEvent* cocoaEvent = [NSEvent eventWithCGEvent:event];
    BOOL callDirectly = NO;
    if ([NSApp isActive]) {
        // Remap modifier keys only while iTerm2 is active; otherwise you could just use the
        // OS's remap feature.
        NSString* unmodkeystr = [cocoaEvent charactersIgnoringModifiers];
        unichar unmodunicode = [unmodkeystr length] > 0 ? [unmodkeystr characterAtIndex:0] : 0;
        unsigned int modflag = [cocoaEvent modifierFlags];
        NSString *keyBindingText;
        PreferencePanel* prefPanel = [PreferencePanel sharedInstance];
        BOOL tempDisabled = [prefPanel remappingDisabledTemporarily];
        BOOL isDoNotRemap = [iTermKeyBindingMgr actionForKeyCode:unmodunicode
                                                       modifiers:modflag
                                                            text:&keyBindingText
                                                     keyMappings:nil] == KEY_ACTION_DO_NOT_REMAP_MODIFIERS;
        BOOL keySheetOpen = [[prefPanel keySheet] isKeyWindow] && [prefPanel keySheetIsOpen];
        if ((!tempDisabled && !isDoNotRemap) ||  // normal case, whether keysheet is open or not
            (!tempDisabled && isDoNotRemap && keySheetOpen)) {  // about to change dnr to non-dnr
            [iTermKeyBindingMgr remapModifiersInCGEvent:event
                                              prefPanel:prefPanel];
            cocoaEvent = [NSEvent eventWithCGEvent:event];
        }
        if (tempDisabled && !isDoNotRemap) {
            callDirectly = YES;
        }
    } else {
        // Update cocoaEvent with a remapped modifier (if it appropriate to do
        // so). This has an effect only if the remapped key is the hotkey.
        CGEventRef eventCopy = CGEventCreateCopy(event);
        NSString* unmodkeystr = [cocoaEvent charactersIgnoringModifiers];
        unichar unmodunicode = [unmodkeystr length] > 0 ? [unmodkeystr characterAtIndex:0] : 0;
        unsigned int modflag = [cocoaEvent modifierFlags];
        NSString *keyBindingText;
        BOOL isDoNotRemap = [iTermKeyBindingMgr actionForKeyCode:unmodunicode
                                                       modifiers:modflag
                                                            text:&keyBindingText
                                                     keyMappings:nil] == KEY_ACTION_DO_NOT_REMAP_MODIFIERS;
        if (!isDoNotRemap) {
            [iTermKeyBindingMgr remapModifiersInCGEvent:eventCopy
                                              prefPanel:[PreferencePanel sharedInstance]];
        }
        cocoaEvent = [NSEvent eventWithCGEvent:eventCopy];
        CFRelease(eventCopy);
    }
    if ([cont eventIsHotkey:cocoaEvent]) {
        OnHotKeyEvent();
        return NULL;
    }

    if (callDirectly) {
        // Send keystroke directly to preference panel when setting do-not-remap for a key; for
        // system keys, NSApp sendEvent: is never called so this is the last chance.
        [[PreferencePanel sharedInstance] shortcutKeyDown:cocoaEvent];
        return nil;
    }
    return event;
}

- (void)unregisterHotkey
{
    hotkeyCode_ = 0;
    hotkeyModifiers_ = 0;
}

- (BOOL)haveEventTap
{
    return machPortRef != 0;
}

- (BOOL)startEventTap
{
    if (![self haveEventTap]) {
        DebugLog(@"Register event tap.");
        machPortRef = CGEventTapCreate(kCGHIDEventTap,
                                       kCGHeadInsertEventTap,
                                       kCGEventTapOptionDefault,
                                       CGEventMaskBit(kCGEventKeyDown),
                                       (CGEventTapCallBack)OnTappedEvent,
                                       self);
        if (machPortRef) {
            CFRunLoopSourceRef eventSrc;

            eventSrc = CFMachPortCreateRunLoopSource(NULL, machPortRef, 0);
            if (eventSrc == NULL) {
                DebugLog(@"CFMachPortCreateRunLoopSource failed.");
                NSLog(@"CFMachPortCreateRunLoopSource failed.");
                CFRelease(machPortRef);
                machPortRef = 0;
                return NO;
            } else {
                DebugLog(@"Adding run loop source.");
                // Get the CFRunLoop primitive for the Carbon Main Event Loop, and add the new event souce
                CFRunLoopAddSource(CFRunLoopGetCurrent(),
                                   eventSrc,
                                   kCFRunLoopCommonModes);
                CFRelease(eventSrc);
            }
            return YES;
        } else {
            return NO;
        }
    } else {
        return YES;
    }
}

- (BOOL)registerHotkey:(int)keyCode modifiers:(int)modifiers
{
    hotkeyCode_ = keyCode;
    hotkeyModifiers_ = modifiers & (NSCommandKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSShiftKeyMask);
    if (![self startEventTap]) {
        switch (NSRunAlertPanel(@"Could not enable hotkey",
                                @"You have assigned a \"hotkey\" that opens iTerm2 at any time. To use it, you must turn on \"access for assistive devices\" in the Universal Access preferences panel in System Preferences and restart iTerm2.",
                                @"OK",
                                @"Open System Preferences",
                                @"Disable Hotkey",
                                nil)) {
            case NSAlertOtherReturn:
                [[PreferencePanel sharedInstance] disableHotkey];
                break;

            case NSAlertAlternateReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                return NO;
        }
    }
    return YES;
}

- (void)beginRemappingModifiers
{
    if (![self startEventTap]) {
        switch (NSRunAlertPanel(@"Could not remap modifiers",
                                @"You have chosen to remap certain modifier keys. For this to work for all key combinations (such as cmd-tab), you must turn on \"access for assistive devices\" in the Universal Access preferences panel in System Preferences and restart iTerm2.",
                                @"OK",
                                @"Open System Preferences",
                                nil,
                                nil)) {
            case NSAlertAlternateReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
        }
    }
}

@end

// keys for to-many relationships:
NSString *terminalsKey = @"terminals";

// Scripting support
@implementation iTermController (KeyValueCoding)

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    BOOL ret;
    // NSLog(@"key = %@", key);
    ret = [key isEqualToString:@"terminals"] || [key isEqualToString:@"currentTerminal"];
    return (ret);
}

// accessors for to-many relationships:
- (NSArray*)terminals
{
    // NSLog(@"iTerm: -terminals");
    return (terminalWindows);
}

- (void)setTerminals:(NSArray*)terminals
{
    // no-op
}

// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInTerminalsAtIndex:(unsigned)theIndex
{
    //NSLog(@"iTerm: valueInTerminalsAtIndex %d: %@", theIndex, [terminalWindows objectAtIndex: theIndex]);
    return ([terminalWindows objectAtIndex: theIndex]);
}

- (void)setCurrentTerminal:(PseudoTerminal*)thePseudoTerminal
{
    FRONT = thePseudoTerminal;

    // make sure this window is the key window
    if ([thePseudoTerminal windowInited] && [[thePseudoTerminal window] isKeyWindow] == NO) {
        [[thePseudoTerminal window] makeKeyAndOrderFront: self];
    }

    // Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"iTermWindowBecameKey"
                                                        object:thePseudoTerminal
                                                      userInfo:nil];

}

-(void)replaceInTerminals:(PseudoTerminal *)object atIndex:(unsigned)theIndex
{
    // NSLog(@"iTerm: replaceInTerminals 0x%x atIndex %d", object, theIndex);
    [terminalWindows replaceObjectAtIndex: theIndex withObject: object];
    [self updateWindowTitles];
}

- (void)addInTerminals:(PseudoTerminal*)object
{
    // NSLog(@"iTerm: addInTerminals 0x%x", object);
    [self insertInTerminals:object atIndex:[terminalWindows count]];
    [self updateWindowTitles];
}

- (void)insertInTerminals:(PseudoTerminal*)object
{
    // NSLog(@"iTerm: insertInTerminals 0x%x", object);
    [self insertInTerminals:object atIndex:[terminalWindows count]];
    [self updateWindowTitles];
}

-(void)insertInTerminals:(PseudoTerminal *)object atIndex:(unsigned)theIndex
{
    if ([terminalWindows containsObject: object] == YES) {
        return;
    }

    [terminalWindows insertObject:object atIndex:theIndex];
    [self updateWindowTitles];
    if (![object isInitialized]) {
        [object initWithSmartLayout:YES
                         windowType:WINDOW_TYPE_NORMAL
                             screen:-1];
    }
}

-(void)removeFromTerminalsAtIndex:(unsigned)theIndex
{
    // NSLog(@"iTerm: removeFromTerminalsAtInde %d", theIndex);
    [terminalWindows removeObjectAtIndex: theIndex];
    [self updateWindowTitles];
}

// a class method to provide the keys for KVC:
- (NSArray*)kvcKeys
{
    static NSArray *_kvcKeys = nil;
    if( nil == _kvcKeys ){
        _kvcKeys = [[NSArray alloc] initWithObjects:
            terminalsKey,  nil ];
    }
    return _kvcKeys;
}

@end

