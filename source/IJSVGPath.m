//
//  IJSVGPath.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGPath.h"
#import "IJSVGGroup.h"

@implementation IJSVGPath

@synthesize path;
@synthesize subpath;

- (void)dealloc
{
    [subpath release], subpath = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super init] ) != nil )
    {
        subpath = [[NSBezierPath bezierPath] retain];
        path = subpath; // for legacy use
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGPath * node = [super copyWithZone:zone];
    [node overwritePath:self.path];
    return node;
}

- (NSPoint)currentPoint
{
    return [subpath currentPoint];
}

- (NSBezierPath *)currentSubpath
{
    return subpath;
}

- (void)close
{
    [subpath closePath];
}

- (void)overwritePath:(NSBezierPath *)aPath
{
    [subpath release], subpath = nil;
    subpath = [aPath retain];
    path = subpath;
}

- (BOOL)isInvisibleFillAndStroke
{
    /*  There are some important caveats around IJSVG path fill/stroke color,
        and some rendering/conversion differences between the two. It's unclear
        whether these are bugs/oversights within IJSVG or whether they fulfill
        some requirements of the SVG spec or were added for import compatibility
        reasons. To summarize:
     
        • When fillColor is nil, the path will still be rendered! It will
        be rendered using the context's default fill color (black) or it
        can inherit the fillColor from its parent.
     
        • When fillColor == +clearColor, it will still be rendered! The
        normal -fill codepath will be run and the path will be drawn
        (albeit invisibily).
     
        • strokeColor behaves differently! A nil strokeColor is always considered
        as "no stroke" and the path stroke rendering is skipped entirely
     
        • [!!] Shapes in Adobe Illustrator that are saved to SVGs and then
        imported and deserialized into IJSVG models have some slightly unexpected
        properties:
            - AI shapes with NO fill and NO stroke will be given a CLEAR fill and
            NIL stroke
            - Some shapes which are black fill will be given a NIL fillColor
            which then results in the default black rendering
     
     */
    
    BOOL invisible = ((self.fillColor == [NSColor clearColor]) &&
                      (!self.strokeColor || self.strokeColor == [NSColor clearColor]) &&
                      (self.fillGradient == nil));
    
    return invisible;
}

@end
