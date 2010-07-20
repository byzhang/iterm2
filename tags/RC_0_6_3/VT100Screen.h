// -*- mode:objc -*-
// $Id: VT100Screen.h,v 1.12 2003-02-12 07:52:47 ujwal Exp $
/*
 **  VT100Screen.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the VT100 screen.
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

#import <Cocoa/Cocoa.h>
#import "VT100Terminal.h"
#import "PTYTask.h"
#import "PTYSession.h"

#define TABWINDOW	300

@interface VT100Screen : NSObject
{
    int WIDTH;
    int HEIGHT;
    int CURSOR_X;
    int CURSOR_Y;
    int SAVE_CURSOR_X;
    int SAVE_CURSOR_Y;
    int SCROLL_TOP;
    int SCROLL_BOTTOM;
    BOOL tabStop[TABWINDOW];
    BOOL CURSOR_IN_MIDDLE;

    NSTextStorage *STORAGE;
    NSFont *FONT, *NAFONT;
    NSSize FONT_SIZE;
    VT100Terminal *TERMINAL;
    PTYTask *SHELL;
    PTYSession *SESSION;
    NSWindow *WINDOW;
    int charset[4], saveCharset[4];
    
    unsigned int  TOP_LINE;
    unsigned int  LINE_LIMIT;
    int  OLD_CURSOR_INDEX;
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
			width:(int)width
		       height:(int)height;
+ (NSSize)requireSizeWithFont:(NSFont *)font;
+ (NSSize)screenSizeInFrame:(NSRect)frame  font:(NSFont *)font;
+ (void)setPlayBellFlag:(BOOL)flag;
+ (NSSize) fontSize:(NSFont *)font;

- (id)init;
- (void)dealloc;

- (NSString *)description;

- (void)initScreen;
- (void)setWidth:(int)width height:(int)height;
- (void)resizeWidth:(int)width height:(int)height;
- (int)width;
- (int)height;

- (void)setTerminal:(VT100Terminal *)terminal;
- (VT100Terminal *)terminal;
- (void)setShellTask:(PTYTask *)shell;
- (PTYTask *)shellTask;
- (NSWindow *) window;
- (void)setWindow:(NSWindow *)window;
- (void)setSession:(PTYSession *)session;

- (void)setTextStorage:(NSTextStorage *)storage;
- (NSTextStorage *)textStorage;
- (void)beginEditing;
- (void)endEditing;
- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont;
- (NSFont *)font;
- (NSFont *)nafont;
- (void)setLineLimit:(unsigned int)maxline;

// edit screen buffer
- (void)putToken:(VT100TCC)token;
- (void)clearBuffer;

// internal
- (void)setDoubleWidthString:(NSString *)s;
- (void)setASCIIString:(NSString *)s;
- (void)setASCIIStringToX:(int)x
                     Y:(int)y
                string:(NSString *)string;
- (void)setNewLine;
- (void)deleteCharacters:(int)n;
- (void)backSpace;
- (void)setTab;
- (void)clearScreen;
- (void)eraseInDisplay:(VT100TCC)token;
- (void)eraseInLine:(VT100TCC)token;
- (void)selectGraphicRendition:(VT100TCC)token;
- (void)cursorLeft:(int)n;
- (void)cursorRight:(int)n;
- (void)cursorUp:(int)n;
- (void)cursorDown:(int)n;
- (void)cursorToX: (int) x;
- (void)cursorToX:(int)x Y:(int)y; 
- (void)saveCursorPosition;
- (void)restoreCursorPosition;
- (void)setTopBottom:(VT100TCC)token;
- (void)scrollUp;
- (void)scrollDown;
- (void)playBell;
- (void)removeOverLine;
- (void)deviceReport:(VT100TCC)token;
- (void)deviceAttribute:(VT100TCC)token;
- (void)insertBlank: (int)n;
- (void)insertLines: (int)n;
- (void)deleteLines: (int)n;
- (void)trimLine: (int) y;
- (void)showCursor;
- (void)showCursor:(BOOL)show;
- (void)blink;
- (int) cursorX;
- (int) cursorY;

- (NSAttributedString *)attrString:(NSString *)str ascii:(BOOL)asc;
- (NSAttributedString *)defaultAttrString:(NSString *)str;
- (int) getIndex:(int)x y:(int)y;
- (BOOL) isDoubleWidthCharacter:(unichar)code;

- (void) clearTabStop;

- (NSString *)translate: (NSString *)s;

@end
