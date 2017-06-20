//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGLinearGradient.h"
#import "IJSVGUtils.h"

@implementation IJSVGLinearGradient

+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGLinearGradient *)aGradient
                   startPoint:(CGPoint *)startPoint
                     endPoint:(CGPoint *)endPoint
{
    
    CGFloat px1 = [[element attributeForName:@"x1"] stringValue].floatValue;
    CGFloat px2 = [[element attributeForName:@"x2"] stringValue].floatValue;
    CGFloat py1 = [[element attributeForName:@"y1"] stringValue].floatValue;
    CGFloat py2 = [[element attributeForName:@"y2"] stringValue].floatValue;
    
    // work out each coord, and work out if its a % or not
    // annoyingly we need to check them all against each other -_-
    BOOL isPercent = NO;
    if(px1 <= 1.f && px2 <= 1.f && py1 <= 1.f && py2 <= 1.f) {
        isPercent = YES;
    } else if((px1 >= 0.f && px1 <= 1.f) && (px2 >= 0.f && px2 <= 1.f) &&
              (py1 >= 0.f && py1 <= 1.f) && (py2 >= 0.f && py2 <= 1.f)) {
        isPercent = YES;
    }
    
    // assume its a vertical / horizonal
    if(isPercent == NO) {
        // just ask unit for the value
        aGradient.x1 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"x1"] stringValue] ?: @"0"];
        aGradient.x2 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"x2"] stringValue] ?: @"100"];
        aGradient.y1 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"y1"] stringValue] ?: @"0"];
        aGradient.y2 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"y2"] stringValue] ?: @"0"];
    } else {
        // make sure its a percent!
        aGradient.x1 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"x1"] stringValue] ?: @"0"];
        aGradient.x2 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"x2"] stringValue] ?: @"1"];
        aGradient.y1 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"y1"] stringValue] ?: @"0"];
        aGradient.y2 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"y2"] stringValue] ?: @"0"];
    }

    // compute the color stops and colours
    NSArray * colors = nil;
    CGFloat * stopsParams = [[self class] computeColorStopsFromString:element
                                                               colors:&colors];
    
    // create the gradient with the colours
    NSGradient * grad = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:stopsParams
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    
    free(stopsParams);
    return grad;
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
     2. If a percent, convert to a pixel value using the parent container as the reference size for the percents
     2. Apply the transforms from the svg. These are attached to this class on self.transforms, this will contain a MatrixTransform.
     3. If in the UserSpace, translate the result relative to the parent.
     
     */

    BOOL isUserSpace = self.units == IJSVGUnitUserSpaceOnUse;

    __block CGPoint startPoint;
    __block CGPoint endPoint;

    void (^applyTransform)(CGAffineTransform transform) = ^(CGAffineTransform transform) {
        startPoint = CGPointApplyAffineTransform(startPoint, transform);
        endPoint = CGPointApplyAffineTransform(endPoint, transform);
    };

    // The base start and end point values read from the svg for this linear gradient
    startPoint = (CGPoint) {
        .x = self.x1.value,
        .y = self.y1.value
    };

    endPoint = (CGPoint) {
        .x = self.x2.value,
        .y = self.y2.value
    };

    // If if the values are percents, convert them to actual pixel values using the parent container
    // as the reference for conversion

    if(self.x1.type == IJSVGUnitLengthTypePercentage)
    {
        startPoint.x = CGRectGetWidth(parentFrame) * startPoint.x;
    }

    if(self.y1.type == IJSVGUnitLengthTypePercentage)
    {
        startPoint.y = CGRectGetHeight(parentFrame) * startPoint.y;
    }

    if(self.x2.type == IJSVGUnitLengthTypePercentage)
    {
        endPoint.x = CGRectGetWidth(parentFrame) * endPoint.x;
    }

    if(self.y2.type == IJSVGUnitLengthTypePercentage)
    {
        endPoint.y = CGRectGetHeight(parentFrame) * endPoint.y;
    }

    // apply the transforms specified on the gradient element
    for(IJSVGTransform * gradientTransform in self.transforms) {
        applyTransform(gradientTransform.CGAffineTransform);
    }

    // move the origin to the user space
    if(isUserSpace == YES) {

        // apply the absolute transform
        CGAffineTransform transform;
        transform = CGAffineTransformMakeTranslation(-parentFrame.origin.x,
                                                     -parentFrame.origin.y);

        applyTransform(transform);
    }

    // start and end, draw before both and after
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;

    // draw the gradient
    CGContextDrawLinearGradient(ctx, self.CGGradient, startPoint, endPoint, options);

    return;
}

@end
