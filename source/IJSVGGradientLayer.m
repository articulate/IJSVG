//
//  IJSVGGradientLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGGradientLayer.h"
#import "IJSVGLinearGradient.h"
#import "IJSVGRadialGradient.h"

@implementation IJSVGGradientLayer

@synthesize gradient;

- (void)dealloc
{
    [gradient release], gradient = nil;
    [super dealloc];
}

- (id)init
{
    if((self = [super init]) != nil) {
        self.requiresBackingScaleHelp = YES;
    }
    return self;
}

- (void)drawInContext:(CGContextRef)ctx
{
    [super drawInContext:ctx];
 
    // nothing to do :(
    if(self.gradient == nil) {
        return;
    }

    CGRect boundingBoxRect = self.frame;
    CGRect parentFrame = self.superlayer.frame;
    
    BOOL isUserSpace = NO;

    if(self.gradient.units == IJSVGUnitUserSpaceOnUse)
    {
        isUserSpace = YES;
        boundingBoxRect = self.viewBox;
    }

    [self.gradient drawInContextRef:ctx parentFrame:parentFrame frame:boundingBoxRect];
}

@end
