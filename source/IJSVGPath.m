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
@synthesize lastControlPoint;

- (void)dealloc
{
    if(subpath!=nil) {
        [subpath release], subpath = nil;
    }
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

- (CGPathRef)newPathRefByAutoClosingPath:(BOOL)autoClose
{
    NSInteger i = 0;
    NSInteger numElements = [self.path elementCount];
    NSBezierPath * bezPath = self.path;
    
    // nothing to return
    if(numElements == 0) {
        return NULL;
    }
    
    CGMutablePathRef aPath = CGPathCreateMutable();
    
    NSPoint points[3];
    BOOL didClosePath = YES;
    
    for (i = 0; i < numElements; i++) {
        switch ([bezPath elementAtIndex:i associatedPoints:points])
        {
                
            // move
            case NSMoveToBezierPathElement: {
                CGPathMoveToPoint(aPath, NULL, points[0].x, points[0].y);
                break;
            }
                
            // line
            case NSLineToBezierPathElement: {
                CGPathAddLineToPoint(aPath, NULL, points[0].x, points[0].y);
                didClosePath = NO;
                break;
            }
                
            // curve
            case NSCurveToBezierPathElement: {
                CGPathAddCurveToPoint(aPath, NULL, points[0].x, points[0].y,
                                      points[1].x, points[1].y,
                                      points[2].x, points[2].y);
                didClosePath = NO;
                break;
            }
                
            // close
            case NSClosePathBezierPathElement: {
                CGPathCloseSubpath(aPath);
                didClosePath = YES;
                break;
            }
        }
    }
    
    if (!didClosePath && autoClose) {
        CGPathCloseSubpath(aPath);
    }
    
    // create immutable and release
    CGPathRef pathToReturn = CGPathCreateCopy(aPath);
    CGPathRelease(aPath);
    
    return pathToReturn;
}

@end
