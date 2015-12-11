//
//  IJSVGGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGDef.h"
#import "IJSVGTransform.h"

@interface IJSVGGradient : IJSVGDef {
    
    NSGradient * gradient;
    CGGradientRef CGGradient;
    CGFloat angle;
    CGPoint startPoint;
    CGPoint endPoint;
    
}

@property ( nonatomic, retain ) NSGradient * gradient;
@property ( nonatomic, assign ) CGFloat angle;
@property ( nonatomic, assign ) CGPoint startPoint;
@property ( nonatomic, assign ) CGPoint endPoint;
@property ( nonatomic, assign ) CGGradientRef CGGradient;

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors;
- (CGGradientRef)CGGradient;
- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path;

@end
