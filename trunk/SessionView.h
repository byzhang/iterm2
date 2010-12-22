// -*- mode:objc -*-
/*
 **  SessionView.h
 **
 **  Copyright (c) 2010
 **
 **  Author: George Nachman
 **
 **  Project: iTerm2
 **
 **  Description: This view contains a session's scrollview.
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

@interface ShadeView : NSView {
    float alpha;
}

- (void)setAlpha:(float)newAlpha;
- (void)drawRect:(NSRect)frame;

@end


@class PTYSession;
@interface SessionView : NSView {
    PTYSession* session_;
    ShadeView* shade_;
    BOOL dim_;

    float currentAlpha_;
    NSDate* previousUpdate_;
    float changePerSecond_;
    float targetAlpha_;
    NSTimer* timer_;
    BOOL shuttingDown_;
}

- (id)initWithFrame:(NSRect)frame session:(PTYSession*)session;
- (void)dealloc;
- (PTYSession*)session;
- (void)setSession:(PTYSession*)session;
- (void)setDimmed:(BOOL)isDimmed;
- (void)cancelTimers;

@end
