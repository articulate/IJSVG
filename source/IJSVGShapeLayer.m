//
//  IJSVGShapeLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGShapeLayer.h"
#import "IJSVGGradientLayer.h"
#import "IJSVGRadialGradient.h"

@implementation IJSVGShapeLayer

IJSVG_LAYER_DEFAULT_SYNTHESIZE

- (void)dealloc
{
    IJSVG_LAYER_DEFAULT_DEALLOC_INSTRUCTIONS
}

- (void)addSublayer:(CALayer *)layer {
    if([layer isKindOfClass:[IJSVGLayer class]] == NO &&
       [layer isKindOfClass:[IJSVGShapeLayer class]] == NO) {
        NSString * r = [NSString stringWithFormat:@"The layer must be an instance of IJSVGLayer, %@ given.",
                        [layer class]];
        NSException * exception = [NSException exceptionWithName:@"IJSVGInvalidSublayerException"
                                                          reason:r
                                                        userInfo:nil];
        @throw exception;
    }
    [super addSublayer:layer];
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if(self.backingScaleFactor == newFactor) {
        return;
    }
    backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    [self setNeedsDisplay];
};

- (void)renderInContext:(CGContextRef)ctx
{
   
    if(self.blendingMode != kCGBlendModeNormal) {
        CGContextSaveGState(ctx);
        CGContextSetBlendMode(ctx, self.blendingMode);
        [super renderInContext:ctx];
        CGContextRestoreGState(ctx);
        return;
    }
    [super renderInContext:ctx];
}

- (CGPoint)absoluteOrigin
{
    return CGPointZero;
}

@end
