//
//  IJSVGRadialGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGRadialGradient.h"

@implementation IJSVGRadialGradient

@synthesize cx;
@synthesize cy;
@synthesize fx;
@synthesize fy;
@synthesize radius;

- (void)dealloc
{
    [cx release], cx = nil;
    [cy release], cy = nil;
    [fx release], fx = nil;
    [fy release], fy = nil;
    [radius release], radius = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGRadialGradient * grad = [super copyWithZone:zone];
    grad.fx = self.fx;
    grad.fy = self.fy;
    grad.cx = self.cx;
    grad.cy = self.cy;
    grad.radius = self.radius;
    grad.startPoint = self.startPoint;
    grad.endPoint = self.endPoint;
    return grad;
}


+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
                   startPoint:(CGPoint *)startPoint
                     endPoint:(CGPoint *)endPoint
{
    CGFloat cx = [element attributeForName:@"cx"].stringValue.floatValue;
    CGFloat cy = [element attributeForName:@"cy"].stringValue.floatValue;
    CGFloat radius = [element attributeForName:@"r"].stringValue.floatValue;
    
    // work out each coord, and work out if its a % or not
    // check all against all
    BOOL isPercent = NO;
    if(cx <= 1.f && cy <= 1.f && radius <= 1.f) {
        isPercent = YES;
    } else if((cx >= 0.f && cx <= 1.f) && (cy >= 0.f && cy <= 1.f) &&
              (radius >= 0.f && radius <= 1.f)) {
        isPercent = YES;
    }
    
    if(isPercent == NO) {
        // just unit value
        gradient.cx = [IJSVGGradientUnitLength unitWithString:[element attributeForName:@"cx"].stringValue];
        gradient.cy = [IJSVGGradientUnitLength unitWithString:[element attributeForName:@"cy"].stringValue];
        gradient.radius = [IJSVGGradientUnitLength unitWithString:[element attributeForName:@"r"].stringValue];
    } else {
        // make sure its a percent
        gradient.cx = [IJSVGGradientUnitLength unitWithPercentageString:[element attributeForName:@"cx"].stringValue];
        gradient.cy = [IJSVGGradientUnitLength unitWithPercentageString:[element attributeForName:@"cy"].stringValue];
        gradient.radius = [IJSVGGradientUnitLength unitWithPercentageString:[element attributeForName:@"r"].stringValue];
    }
    
    
    // check for nullability
    if( gradient.gradient != nil ) {
        return nil;
    }
    
    *startPoint = CGPointMake(gradient.cx.valueAsPercentage, gradient.cy.valueAsPercentage);
    *endPoint = CGPointMake(gradient.fx.valueAsPercentage, gradient.fy.valueAsPercentage);
    
    NSArray * colors = nil;
    CGFloat * colorStops = [[self class] computeColorStopsFromString:element colors:&colors];
    NSGradient * ret = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:colorStops
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    free(colorStops);
    return ret;
}

- (void)drawInContextRef:(CGContextRef)ctx
             parentFrame:(NSRect)parentFrame
                   frame:(NSRect)frame
{
    /**

     In order to draw correctly, we must follow the procedures in this document

     https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/gradientUnits

     So the steps are:

     1. Get the coordinate
     2. Apply the transforms from the svg. These are attached to this class on self.transforms, this will contain a MatrixTransform.
     3. If in the UserSpace, translate the result relative to the parent.

     When applying to the radius, the steps are:

     1. Create rect with a width/height = diameter of the radius
     2. Apply the transform
     3. get the new radius by taking the width or height / 2 (since they represented the diameter).

     */

    BOOL isUserSpace = self.units == IJSVGUnitUserSpaceOnUse;

    CGPoint startPoint = (CGPoint)
    {
        .x = self.cx.value,
        .y = self.cy.value
    };

    CGFloat renderRadius = self.radius.value;
    CGPoint gradientPoint = CGPointZero;

    if(self.cx.type == IJSVGUnitLengthTypePercentage)
    {
        startPoint.x = CGRectGetWidth(parentFrame) * startPoint.x;
    }

    if(self.cy.type == IJSVGUnitLengthTypePercentage)
    {
        startPoint.y = CGRectGetHeight(parentFrame) * startPoint.y;
    }

    if(self.radius.type == IJSVGUnitLengthTypePercentage)
    {
        //
        // According to the spec this should be the large radius for the circle so calculate for width and height and use the largest.
        // https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/r
        //
        CGFloat xRadius = CGRectGetWidth(parentFrame) * radius.value;
        CGFloat yRadius = CGRectGetHeight(parentFrame) * radius.value;

        renderRadius = fmax(xRadius, yRadius);
    }

    if(isUserSpace == YES)
    {
        // calculate the rectangle to transform using the radius converted to a diameter
        CGRect radiusCalculationRect = (CGRect)
        {
            .origin = NSZeroPoint,
            .size = (CGSize) {
                .width = renderRadius * 2,
                .height = renderRadius * 2
            }
        };

        // apply the transforms from the svg file
        for(IJSVGTransform * gradientTransform in self.transforms)
        {
            radiusCalculationRect = CGRectApplyAffineTransform(radiusCalculationRect, gradientTransform.CGAffineTransform);
        }

        // update the radius
        renderRadius = CGRectGetHeight(radiusCalculationRect) / 2.f;
    }

    // now calculate the center point
    gradientPoint = startPoint;

    // apply the transforms from the svg
    for(IJSVGTransform * gradientTransform in self.transforms)
    {
        gradientPoint = CGPointApplyAffineTransform(gradientPoint, gradientTransform.CGAffineTransform);
    }

    if(isUserSpace == YES)
    {
        // if in the suer space offset the origin to be relative to the parent
        CGAffineTransform transform;
        transform = CGAffineTransformMakeTranslation(-parentFrame.origin.x,
                                                     -parentFrame.origin.y);

        gradientPoint = CGPointApplyAffineTransform(gradientPoint, transform);
    }

    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation; 
    CGContextDrawRadialGradient(ctx, self.CGGradient, gradientPoint, 0.f, gradientPoint, renderRadius, options);
}

@end
