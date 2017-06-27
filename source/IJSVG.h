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
#import "IJSVGLayerTree.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGImageLayer.h"

@class IJSVG;

void IJSVGBeginTransactionLock();
void IJSVGEndTransactionLock();
void IJSVGObtainTransactionLock(dispatch_block_t block, BOOL renderOnMainThread);


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
- (void)svg:(IJSVG *)svg
foundSubSVG:(IJSVG *)subSVG
withSVGString:(NSString *)subSVGString;

@end

typedef CGFloat (^IJSVGRenderingBackingScaleFactorHelper)();

@interface IJSVG : NSObject <NSPasteboardWriting, IJSVGParserDelegate> {
    
@private
    IJSVGParser * _group;
    CGFloat _scale;
    CGFloat _clipScale;
    id<IJSVGDelegate> _delegate;
    IJSVGLayer * _layerTree;
    CGRect _viewBox;
    CGSize _proposedViewSize;
    CGFloat _lastProposedBackingScale;
    
    struct {
        unsigned int shouldHandleForeignObject: 1;
        unsigned int handleForeignObject: 1;
        unsigned int shouldHandleSubSVG: 1;
    } _respondsTo;
    
}

// set this to be called when the layer is about to draw, it will call this
// and ask for the scale of the backing store where its going to be drawn
// and apply the scale to each layer that has custom drawing against it, mainly
// pattern and gradient layers
@property (nonatomic, copy) IJSVGRenderingBackingScaleFactorHelper renderingBackingScaleHelper;

// global overwriting rules for when rendering an SVG, this will overide any
// fillColor, strokeColor, pattern and gradient fill
@property (nonatomic, retain) NSColor * fillColor;
@property (nonatomic, retain) NSColor * strokeColor;

- (NSXMLDocument *)copySVGDocument;
- (void)prepForDrawingInView:(NSView *)view;
- (BOOL)isFont;
- (NSRect)viewBox;
- (NSArray *)glyphs;
- (NSString *)identifier;
- (IJSVGLayer *)layer;
- (IJSVGLayer *)layerWithTree:(IJSVGLayerTree *)tree;
- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive;

- (CGFloat)computeBackingScale:(CGFloat)scale;
- (void)discardDOM;

+ (id)svgNamed:(NSString *)string;
+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate;

+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithImage:(NSImage *)image;

- (id)initWithSVGLayer:(IJSVGGroupLayer *)group
               viewBox:(NSRect)viewBox;

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGDelegate>)delegate
          closeDocument:(BOOL)closeDocument;

- (id)initWithSVGString:(NSString *)string;

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error;

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache;
- (id)initWithFile:(NSString *)file;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error;
- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache;
- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error;
- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
                    error:(NSError **)error
                 delegate:(id<IJSVGDelegate>)delegate;
- (NSImage *)imageWithSize:(NSSize)aSize;
- (NSImage *)imageWithSize:(NSSize)aSize
                     error:(NSError **)error;
- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError **)error;
- (BOOL)drawInRect:(NSRect)rect;
- (BOOL)drawInRect:(NSRect)rect
             error:(NSError **)error;
- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context;

- (NSSize)viewBoxSize;
- (NSData *)PDFData;
- (NSData *)PDFData:(NSError **)error;
- (NSData *)PDFDataWithRect:(NSRect)rect;
- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error;

/** This method will return the visual bounding box in the coordinate system of the SVG file. This will be needed when working with
    the svg in its NSXmlDocument format */
- (NSRect)visualBoundingBoxRawSVGCoordinates;

/** This method will return the visual bounding box including invisible shapes and will also take into account if the image is flipped
    for rendering. This will be needed when working with the svg in its NSXmlDocument format */
- (NSRect)boundingBoxIncludingInvisiblesRawSVGCoordinates;

/** This method will return the visual bounding box for rendering and will also take into account if the image is flipped
    for rendering. This is the correct bounding rectangle to use when rendering to the screen */
- (NSRect)visualBoundingBoxForRendering;

/** This method will return the visual bounding box including invisible shapes and will also take into account if the image is flipped 
    for rendering. This is the correct bounding rectangle to use when rendering to the screen */
- (NSRect)boundingBoxIncludingInvisiblesForRendering;

+ (void)setRenderingDebugOptions:(IJSVGRenderingDebugOptions)renderingDebugOptions;

@end
