//
//  IJSVGImage.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "IJSVGParser.h"
#import "IJSVGBezierPathAdditions.h"

#define IJSVG_USES_FLIPPED_Y_RENDERING 1

@class IJSVG;

typedef NS_ENUM(uint32_t, IJSVGRenderingDebugOptions)
{
    IJSVGRenderingDebugOptionsNone = 0x0,
    IJSVGRenderingDebugOptionsOutlineClearFillNoStrokeShapes = 0x1 << 0,
};

@protocol IJSVGDelegate <NSObject,IJSVGParserDelegate>

@optional
- (BOOL)svg:(IJSVG *)svg
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject;
- (void)svg:(IJSVG *)svg
handleForeignObject:(IJSVGForeignObject *)foreignObject
   document:(NSXMLDocument *)document;

@end

@interface IJSVG : NSObject <NSPasteboardWriting> {
    
@private
    IJSVGParser * _group;
    CGFloat _scale;
    NSMutableArray * _colors;
    id<IJSVGDelegate> _delegate;
    
}

+ (NSColor *)baseColor;
+ (void)setBaseColor:(NSColor *)color;
+ (id)svgNamed:(NSString *)string;
+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithData:(NSData *)data
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file;
- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (NSImage *)imageWithSize:(NSSize)aSize;
- (void)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (void)drawInRect:(NSRect)rect;
- (NSArray *)colors;
- (NSSize)viewBoxSize;
- (NSData *)PDFData;
- (NSData *)PDFDataWithRect:(NSRect)rect;

- (NSRect)visualBoundingBox;
- (NSRect)boundingBoxIncludingInvisibles;

+ (void)setRenderingDebugOptions:(IJSVGRenderingDebugOptions)renderingDebugOptions;

@end
