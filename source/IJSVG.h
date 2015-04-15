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

@class IJSVG;

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

// General API

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

// Special Utilities

/** This method renders the SVG into a bitmap at the size specified by `renderedSize`. The SVG is drawn centered
    and scaled by `scaleFactor`. The resulting bitmap is then trimmed / cropped of transparent pixels (and white pixels
    if `trimWhite` is YES. */
- (NSImage *)trimmedImageOfSVGRenderedAtSize:(NSSize)renderedSize
                                 scaleFactor:(float)scaleFactor
                                   trimWhite:(BOOL)trimWhite;

@end
