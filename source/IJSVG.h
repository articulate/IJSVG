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

/*  This is a baked-in value that determines whether the IJSVG
    engine should use a flipped Y coordinate system. By default
    this is now ON, however for the original IJSVG example app
    and tests this should be disabled by default. */

#ifdef IJSVG_EXAMPLE_TESTS_NO_FLIPPED_Y
    #define IJSVG_USES_FLIPPED_Y_RENDERING 0
#else
    #define IJSVG_USES_FLIPPED_Y_RENDERING 1
#endif

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
    CGFloat _clipScale;
    NSMutableArray * _colors;
    id<IJSVGDelegate> _delegate;
    
}

+ (NSColor *)baseColor;
- (BOOL)isFont;
- (NSArray *)glyphs;
+ (void)setBaseColor:(NSColor *)color;
+ (id)svgNamed:(NSString *)string;
+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithData:(NSData *)data
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error;
- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error;
- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error
                 delegate:(id<IJSVGDelegate>)delegate;
- (NSImage *)imageWithSize:(NSSize)aSize;
- (NSImage *)imageWithSize:(NSSize)aSize
                     error:(NSError **)error;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError **)error;
- (BOOL)drawInRect:(NSRect)rect;
- (BOOL)drawInRect:(NSRect)rect
             error:(NSError **)error;
- (NSArray *)colors;
- (NSSize)viewBoxSize;
- (NSData *)PDFData;
- (NSData *)PDFData:(NSError **)error;
- (NSData *)PDFDataWithRect:(NSRect)rect;
- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error;

- (NSRect)visualBoundingBox;
- (NSRect)boundingBoxIncludingInvisibles;

+ (void)setRenderingDebugOptions:(IJSVGRenderingDebugOptions)renderingDebugOptions;

@end
