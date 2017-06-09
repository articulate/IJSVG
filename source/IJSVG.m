//
//  IJSVGImage.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGCache.h"
#import "IJSVGTransaction.h"


static IJSVGRenderingDebugOptions _IJSVGrenderingDebugOptions = IJSVGRenderingDebugOptionsNone;

@implementation IJSVG

@synthesize fillColor;
@synthesize strokeColor;
@synthesize renderingBackingScaleHelper;

- (void)dealloc
{
    [renderingBackingScaleHelper release], renderingBackingScaleHelper = nil;
    [fillColor release], fillColor = nil;
    [strokeColor release], strokeColor = nil;
    [_group release], _group = nil;
    [_layerTree release], _layerTree = nil;
    [super dealloc];
}

+ (id)svgNamed:(NSString *)string
         error:(NSError **)error
{
    return [[self class] svgNamed:string
                            error:error
                         delegate:nil];
}

+ (id)svgNamed:(NSString *)string
{
    return [[self class] svgNamed:string
                            error:nil];
}

+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
      delegate:(id<IJSVGDelegate>)delegate
{
    return [[self class] svgNamed:string
                         useCache:useCache
                            error:nil
                         delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate
{
    return [[self class] svgNamed:string
                            error:nil
                         delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
         error:(NSError **)error
      delegate:(id<IJSVGDelegate>)delegate
{
    return [self svgNamed:string
                 useCache:YES
                    error:error
                 delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
         error:(NSError **)error
      delegate:(id<IJSVGDelegate>)delegate
{
    NSBundle * bundle = [NSBundle mainBundle];
    NSString * str = nil;
    NSString * ext = [string pathExtension];
    if( ext == nil || ext.length == 0 ) {
        ext = @"svg";
    }
    if( ( str = [bundle pathForResource:[string stringByDeletingPathExtension] ofType:ext] ) != nil ) {
        return [[[self alloc] initWithFile:str
                                  useCache:useCache
                                     error:error
                                  delegate:delegate] autorelease];
    }
    return nil;
}

- (id)initWithImage:(NSImage *)image
{
    __block IJSVGGroupLayer * layer = nil;
    __block IJSVGImageLayer * imageLayer = nil;
    
    // make sure we obtain a lock, with whatever we do with layers!
    IJSVGObtainTransactionLock(^{
        // create the layers we require
        layer = [[[IJSVGGroupLayer alloc] init] autorelease];
        imageLayer = [[[IJSVGImageLayer alloc] initWithImage:image] autorelease];
        [layer addSublayer:imageLayer];
    }, NO);
    
    // return the initialized SVG
    return [self initWithSVGLayer:layer
                          viewBox:imageLayer.frame];
}

- (id)initWithSVGLayer:(IJSVGGroupLayer *)group
               viewBox:(NSRect)viewBox
{
    // this completely bypasses passing of files
    if((self = [super init]) != nil) {
        // keep the layer tree
        _layerTree = [group retain];
        _viewBox = viewBox;
        
        // any setups
        [self _setupBasicsFromAnyInitializer];
    }
    return self;
}


- (id)initWithFile:(NSString *)file
{
    return [self initWithFile:file
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
{
    return [self initWithFile:file
                     useCache:useCache
                        error:nil
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file]
                            useCache:useCache
                               error:error
                            delegate:delegate];
}

- (id)initWithFile:(NSString *)file
             error:(NSError **)error
{
    return [self initWithFile:file
                        error:error
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFile:file
                        error:nil
                     delegate:delegate];
}

- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file]
                            useCache:YES
                               error:error
                            delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL *)aURL
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:nil
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:error
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
{
    return [self initWithFilePathURL:aURL
                            useCache:useCache
                               error:nil
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:nil
                            delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
                    error:(NSError **)error
                 delegate:(id<IJSVGDelegate>)delegate
{
#ifndef __clang_analyzer__
    
    // check the cache first
    if( useCache && [IJSVGCache enabled] ) {
        IJSVG * svg = nil;
        if( ( svg = [IJSVGCache cachedSVGForFileURL:aURL] ) != nil ) {
            // have to release, as this was called from an alloc..!
            [self release];
            return [svg retain];
        }
    }
    
    // create the object
    if( ( self = [super init] ) != nil ) {
        NSError * anError = nil;
        _delegate = delegate;
        
        // this is a really quick check against the delegate
        // for methods that exist
        [self _checkDelegate];
        
        // create the group
        _group = [[IJSVGParser groupForFileURL:aURL
                                         error:&anError
                                      delegate:self] retain];
        
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];
        
        // something went wrong...
        if( _group == nil ) {
            if( error != NULL ) {
                *error = anError;
            }
            [self release], self = nil;
            return nil;
        }
        
        // cache the file
        if( useCache && [IJSVGCache enabled] ) {
            [IJSVGCache cacheSVG:self
                         fileURL:aURL];
        }
    }
#endif
    return self;
}

- (id)initWithSVGString:(NSString *)string
{
    return [self initWithSVGString:string
                             error:nil
                          delegate:nil];
}

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
{
    return [self initWithSVGString:string
                             error:error
                          delegate:nil];
}

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGDelegate>)delegate
{
    if((self = [super init]) != nil) {
        // this is basically the same as init with URL just
        // bypasses the loading of a file
        NSError * anError = nil;
        _delegate = delegate;
        [self _checkDelegate];
        
        // setup the parser
        _group = [[IJSVGParser alloc] initWithSVGString:string
                                                  error:&anError
                                               delegate:self];
        
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];
        
        // something went wrong :(
        if(_group == nil) {
            if(error != NULL) {
                *error = anError;
            }
            [self release], self = nil;
            return nil;
        }
    }
    return self;
}

- (void)discardDOM
{
    // if we discard, we can no longer create a tree, so lets create tree
    // upfront before we kill anything
    [self layer];
    
    // now clear memory
    [_group release], _group = nil;
}

- (void)_setupBasicInfoFromGroup
{
    // store the viewbox
    _viewBox = _group.viewBox;
    _proposedViewSize = _group.proposedViewSize;
}

- (void)_setupBasicsFromAnyInitializer
{
    _lastProposedBackingScale = 1.f;
}

- (NSString *)identifier
{
    return _group.identifier;
}

- (void)_checkDelegate
{
    _respondsTo.shouldHandleForeignObject = [_delegate respondsToSelector:@selector(svg:shouldHandleForeignObject:)];
    _respondsTo.handleForeignObject = [_delegate respondsToSelector:@selector(svg:handleForeignObject:document:)];
    _respondsTo.shouldHandleSubSVG = [_delegate respondsToSelector:@selector(svg:foundSubSVG:withSVGString:)];
}

- (NSRect)viewBox
{
    return _viewBox;
}

- (id)initWithData:(NSData *)data
          delegate:(id<IJSVGDelegate>)delegate
{
#ifndef __clang_analyzer__
    /* NOTE: this method does not invoke or take advantage of IJSVGCache. */
    
    if( ( self = [super init] ) != nil )
    {
        _delegate = delegate;
        NSError *error = nil;
        _group = [[IJSVGParser alloc] initWithData:data
                                             error:&error
                                           delegate:delegate];
        
        if (error)
        {
            NSLog(@"Error parsing SVG: %@", error);
        }
    }
#endif
    return self;
}

- (BOOL)isFont
{
    return [_group isFont];
}

- (NSArray *)glyphs
{
    return [_group glyphs];
}

- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive
{
    return [_group subSVGs:recursive];
}

- (NSImage *)imageWithSize:(NSSize)aSize
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:nil];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                     error:(NSError **)error;
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:error];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped
{
    return [self imageWithSize:aSize
                       flipped:flipped
                         error:nil];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped
                     error:(NSError **)error
{
    NSImage * im = [[[NSImage alloc] initWithSize:aSize] autorelease];
    [im lockFocus];
    CGContextRef ref = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ref);
    if(flipped) {
        CGContextTranslateCTM(ref, 0.f, aSize.height);
        CGContextScaleCTM(ref, 1.f, -1.f);
    }
    [self drawAtPoint:NSMakePoint( 0.f, 0.f )
                 size:aSize
                error:error];
    CGContextRestoreGState(ref);
    [im unlockFocus];
    return im;
}

- (NSData *)PDFData
{
    return [self PDFData:nil];
}

- (NSData *)PDFData:(NSError **)error
{
    return [self PDFDataWithRect:(NSRect){
        .origin=NSZeroPoint,
        .size=_viewBox.size
    } error:error];
}

- (NSData *)PDFDataWithRect:(NSRect)rect
{
    return [self PDFDataWithRect:rect
                           error:nil];
}

- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error
{
    // create the data for the PDF
    NSMutableData * data = [[[NSMutableData alloc] init] autorelease];
    
    // assign the data to the consumer
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
    const CGRect box = CGRectMake( rect.origin.x, rect.origin.y,
                                  rect.size.width, rect.size.height );
    
    // create the context
    CGContextRef context = CGPDFContextCreate( dataConsumer, &box, NULL );
    
    CGContextBeginPage( context, &box );
    
    // the context is currently upside down, doh! flip it...
    CGContextScaleCTM( context, 1, -1 );
    CGContextTranslateCTM( context, 0, -box.size.height);
    
    // draw the icon
    [self _drawInRect:(NSRect)box
              context:context
                error:error];
    
    CGContextEndPage(context);
    
    //clean up
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(dataConsumer);
    return data;
}

- (void)prepForDrawingInView:(NSView *)view
{
    // kill the render
    if(view == nil) {
        self.renderingBackingScaleHelper = nil;
        return;
    }
    
    // construct the layer before drawing
    [self layer];
    
    // set the scale
    __block NSView * weakView = view;
    self.renderingBackingScaleHelper = ^CGFloat{
        return weakView.window.screen.backingScaleFactor;
    };
}

- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
{
    return [self drawAtPoint:point
                        size:aSize
                       error:nil];
}

- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError **)error
{
    return [self drawInRect:NSMakeRect( point.x, point.y, aSize.width, aSize.height )
                      error:error];
}

- (BOOL)drawInRect:(NSRect)rect
{
    return [self drawInRect:rect
                     error:nil];
}

- (BOOL)drawInRect:(NSRect)rect
             error:(NSError **)error
{
    return [self _drawInRect:rect
                     context:[[NSGraphicsContext currentContext] graphicsPort]
                       error:error];
}

- (CGFloat)computeBackingScale:(CGFloat)actualScale
{
    return (CGFloat)(_scale + actualScale);
}

- (NSRect)computeRectDrawingInRect:(NSRect)rect
                       isValid:(BOOL *)valid
{
    // we also need to calculate the viewport so we can clip
    // the drawing if needed
    NSRect viewPort = NSZeroRect;
    viewPort.origin.x = round(rect.size.width/2-(_proposedViewSize.width/2)*_clipScale);
    viewPort.origin.y = round(rect.size.height/2-(_proposedViewSize.height/2)*_clipScale);;
    viewPort.size.width = _proposedViewSize.width*_clipScale;
    viewPort.size.height = _proposedViewSize.height*_clipScale;
    
    // check the viewport
    if( NSEqualRects( _viewBox, NSZeroRect )
       || _viewBox.size.width <= 0
       || _viewBox.size.height <= 0
       || NSEqualRects( NSZeroRect, viewPort)
       || CGRectIsEmpty(viewPort)
       || CGRectIsNull(viewPort)
       || viewPort.size.width <= 0
       || viewPort.size.height <= 0 )
    {
        *valid = NO;
        return NSZeroRect;
    }

    *valid = YES;
    return viewPort;
}

- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context
{
    [self _drawInRect:rect
              context:context 
                error:nil];
}

- (BOOL)_drawInRect:(NSRect)rect
            context:(CGContextRef)ref
              error:(NSError **)error
{
    // prep for draw...
    @synchronized (self) {
    CGContextSaveGState(ref);
    @try {
        
        [self _beginDraw:rect];
            
        // scale the whole drawing context, but first, we need
        // to translate the context so its centered
            CGFloat tX = round(rect.size.width/2-(_viewBox.size.width/2)*_scale);
            CGFloat tY = round(rect.size.height/2-(_viewBox.size.height/2)*_scale);
        
            // we also need to calculate the viewport so we can clip
            // the drawing if needed
            BOOL canDraw = NO;
            NSRect viewPort = [self computeRectDrawingInRect:rect
                                                     isValid:&canDraw];
            // check the viewport
            if( !canDraw ) {
                if( error != NULL ) {
                    *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                         code:IJSVGErrorDrawing
                                                     userInfo:nil] autorelease];
                }
                CGContextRestoreGState(ref);
                return NO;
            }
            
        
        	// Respect the input rect origin
        	tX += rect.origin.x;
        	tY -= rect.origin.y;
        
            // clip to mask
            CGContextClipToRect( ref, viewPort);
            
#if IJSVG_USES_FLIPPED_Y_RENDERING
        // Flip our Y coordinate:
        CGContextScaleCTM( ref, 1, -1 );
        CGContextTranslateCTM( ref, 0, -viewPort.size.height);
#endif
        
        // Adjust for viewport origin
            tX -= (_viewBox.origin.x*_scale);
            tY -= (_viewBox.origin.y*_scale);
            
            CGContextTranslateCTM( ref, tX, tY );
            CGContextScaleCTM( ref, _scale, _scale );
            
            // render the layer, its really important we lock
            // the transaction when drawing
            IJSVGBeginTransactionLock();
            // do we need to update the backing scales on the
            // layers?
            if(self.renderingBackingScaleHelper != nil) {
                [self _askHelperForBackingScale];
            }
            
            // render the layers
            [self.layer renderInContext:ref];
            IJSVGEndTransactionLock();
        }
    
        @catch (NSException *exception) {
            // just catch and give back a drawing error to the caller
            if( error != NULL )
                *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                     code:IJSVGErrorDrawing
                                                 userInfo:nil] autorelease];
        }
        @finally {
            CGContextRestoreGState(ref);
        }
    }
    return (error == nil);
}

//// Matts code

- (void)_recursiveColors:(IJSVGGroup *)group
{
    if( group.fillColor != nil && !group.usesDefaultFillColor )
        [self _addColor:group.fillColor];
    if( group.strokeColor != nil )
        [self _addColor:group.strokeColor];
    for( id node in [group children] )
    {
        if( [node isKindOfClass:[IJSVGGroup class]] )
            [self _recursiveColors:node];
        else {
            IJSVGPath * p = (IJSVGPath*)node;
            if( p.fillColor != nil )
                [self _addColor:p.fillColor];
            if( p.strokeColor != nil )
                [self _addColor:p.strokeColor];
        }
    }
}

- (void)_addColor:(NSColor *)color
{
    if( [_colors containsObject:color] || color == [NSColor clearColor] )
        return;
    [_colors addObject:color];
}

- (void)_beginDraw:(NSRect)rect
{
    // in order to correctly fit the the SVG into the
    // rect, we need to work out the ratio scale in order
    // to transform the paths into our viewbox
    NSSize dest = rect.size;
    NSSize source = _viewBox.size;
    _clipScale = MIN(dest.width/_proposedViewSize.width,
                     dest.height/_proposedViewSize.height);

    // work out the actual scale based on the clip scale
    CGFloat w = _proposedViewSize.width*_clipScale;
    CGFloat h = _proposedViewSize.height*_clipScale;
    _scale = MIN(w/source.width,h/source.height);
}


- (NSSize)viewBoxSize
{
    return _group.viewBox.size;
}

- (void)_prepClip:(IJSVGNode *)node
          context:(CGContextRef)context
        drawBlock:(dispatch_block_t)block
             rect:(NSRect)rect
{
    if( node.clipPath != nil )
    {
        for( id clip in node.clipPath.children )
        {
            // save the context
            CGContextSaveGState(context);
            {
                
                if( [clip isKindOfClass:[IJSVGGroup class]] )
                {
                    [self _drawGroup:clip
                                rect:rect
                             context:context];
                } else {
                    
                    // add the clip and draw
                    IJSVGPath * path = (IJSVGPath *)clip;
                    [[IJSVGTransform transformedPath:path] addClip];
                    block();
                }
                
                // restore the context
            }
            CGContextRestoreGState(context);
        }
        return;
    }
    
    // just draw
    block();
}

- (void)_drawGroup:(IJSVGGroup *)group
              rect:(NSRect)rect
           context:(CGContextRef)context
{
    
    if( !group.shouldRender )
        return;
    
    CGContextSaveGState( context );
    {
        
        // perform any transforms
        [self _applyDefaults:context
                        node:group];
        
        dispatch_block_t drawBlock = ^(void)
        {
            // it could be a group or a path
            for( id child in [group children] )
            {
                if( [child isKindOfClass:[IJSVGPath class]] )
                {
                    dispatch_block_t block = ^(void)
                    {
                        IJSVGPath * p = (IJSVGPath *)child;
                        if( p.shouldRender )
                            [self _drawPath:p
                                       rect:rect
                                    context:context];
                    };
                    
                    // draw the clip
                    [self _prepClip:child
                            context:context
                          drawBlock:block
                               rect:rect];
                    
                } else if( [child isKindOfClass:[IJSVGGroup class]] ) {
                    
                    // if its a group, we recursively call this method
                    // to generate the paths required
                    [self _drawGroup:child
                                rect:rect
                             context:context];
                }
            }
            
        };
        
        // main group clipping
        [self _prepClip:group
                context:context
              drawBlock:drawBlock
                   rect:rect];
        
    }
    // restore the context
    CGContextRestoreGState(context);
}

- (void)_applyDefaults:(CGContextRef)context
                  node:(IJSVGNode *)node
{
    // the opacity, if its 0, assume its broken
    // so set it to 1.f
    CGFloat opacity = node.opacity;
    if( opacity == 0.f )
        opacity = 1.f;
    
    // scale it
    CGContextSetAlpha( context, opacity );
    CGContextTranslateCTM( context, node.x, node.y);
    
    // perform any transforms
    for( IJSVGTransform * transform in node.transforms )
    {
        [IJSVGTransform performTransform:transform
                               inContext:context];
    }
    
}

- (void)_drawPath:(IJSVGPath *)path
             rect:(NSRect)rect
          context:(CGContextRef)ref
{
    // there should be a colour on it...
    // defaults to black if not existant
    CGContextSaveGState(ref);
    {
        // there could be transforms per path
        [self _applyDefaults:ref
                        node:path];
        
        // fill the path
        if( path.fillGradient != nil )
        {
            CGContextSaveGState(ref);
            {
                // for this to work, we need to add the clip so when
                // drawing occurs, it doesnt go outside the path bounds
                [path.path addClip];
                [path.fillGradient drawInContextRef:ref
                                               path:path];
            }
            CGContextRestoreGState(ref);
        } else {
            // no gradient specified
            // just use the color instead
            if( path.windingRule != IJSVGWindingRuleInherit )
                [path.path setWindingRule:(NSWindingRule)path.windingRule];
            
            if( path.fillColor != nil )
            {
                [path.fillColor set];
                [path.path fill];
            } else if( _baseColor != nil ) {
                
                // is there a base color?
                // this is basically used whenever no color
                // is set, its also set via [IJSVG setBaseColor],
                // this must be defined!
                
                [_baseColor set];
                [path.path fill];
            } else {
                [path.path fill];
            }
        }
        
        // any stroke?
        if( path.strokeColor != nil )
        {
            // default line width is 1
            // if its defined elsewhere, then
            // use that one instead
            CGFloat lineWidth = 1.f;
            if( path.strokeWidth > 0.f )
                lineWidth = path.strokeWidth;
            
            if( path.lineCapStyle != IJSVGLineCapStyleInherit )
                [path.path setLineCapStyle:(NSLineCapStyle)path.lineCapStyle];
            else
                [path.path setLineCapStyle:NSButtLineCapStyle];
            
            if( path.lineJoinStyle != IJSVGLineJoinStyleInherit )
                [path.path setLineJoinStyle:(NSLineJoinStyle)path.lineJoinStyle];
            
            [path.strokeColor setStroke];
            [path.path setLineWidth:lineWidth];
            
            // any dashed array?
            if( path.strokeDashArrayCount != 0 )
                [path.path setLineDash:path.strokeDashArray
                                 count:path.strokeDashArrayCount
                                 phase:path.strokeDashOffset];
            
            [path.path stroke];
        }
        
        if (_IJSVGrenderingDebugOptions & IJSVGRenderingDebugOptionsOutlineClearFillNoStrokeShapes)
        {
            if ([path isInvisibleFillAndStroke])
            {
                NSBezierPath *pathCopy = [path.path.copy autorelease];
                const CGFloat dashArray[] = {15.0, 5.0};
                [pathCopy setLineDash:dashArray count:2 phase:0];
                [[NSColor redColor] setStroke];
                pathCopy.lineWidth = 4;
                [pathCopy stroke];
            }
        }
    }
    // restore the graphics state
    CGContextRestoreGState(ref);
    
}

#pragma mark - Bounds

- (NSRect)boundingRectFlippedForYCoordinatesIfNeeded:(NSRect)boundingRect
{
#if IJSVG_USES_FLIPPED_Y_RENDERING
    CGFloat newOriginY = self.viewBoxSize.height - (boundingRect.size.height + boundingRect.origin.y);
    boundingRect.origin.y = newOriginY;
#endif
    
    return boundingRect;
}

- (NSRect)visualBoundingBox
{
    return [self boundingRectFlippedForYCoordinatesIfNeeded:_group.calculatedVisualBoundingBox];
}

- (NSRect)boundingBoxIncludingInvisibles
{
    return [self boundingRectFlippedForYCoordinatesIfNeeded:_group.calculatedBoundingBox];
}

#pragma mark - Debug

+ (void)setRenderingDebugOptions:(IJSVGRenderingDebugOptions)renderingDebugOptions
{
    _IJSVGrenderingDebugOptions = renderingDebugOptions;
}

#pragma mark NSPasteboard

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[NSPasteboardTypePDF];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    if( [type isEqualToString:NSPasteboardTypePDF] )
        return [self PDFData];
    return nil;
}

#pragma mark IJSVGParserDelegate

- (BOOL)svgParser:(IJSVGParser *)parser
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject
{
    if( _delegate != nil && _respondsTo.shouldHandleForeignObject == 1 ) {
        return [_delegate svg:self shouldHandleForeignObject:foreignObject];
    }
    return NO;
}

- (void)svgParser:(IJSVGParser *)parser
handleForeignObject:(IJSVGForeignObject *)foreignObject
         document:(NSXMLDocument *)document
{
    if( _delegate != nil && _respondsTo.handleForeignObject == 1 ) {
        [_delegate svg:self
   handleForeignObject:foreignObject
              document:document];
    }
}

- (void)_askHelperForBackingScale
{
    CGFloat scale = (self.renderingBackingScaleHelper)();
    if(scale < 1.f) {
        scale = 1.f;
    }

    // dont do anything, nothing has changed, no point of iterating over
    // every layer for no reason!
    if(scale == _lastProposedBackingScale) {
        return;
    }
    _lastProposedBackingScale = scale;
    [self _recursivelySetScale:scale
                      forLayer:self.layer];
}

- (void)_recursivelySetScale:(CGFloat)scale
                    forLayer:(IJSVGLayer *)layer
{
    // update the backing layer scale
    if(layer.requiresBackingScaleHelp == YES) {
        layer.backingScaleFactor = scale;
    }

    // find the next!
    for(IJSVGLayer * aLayer in layer.sublayers) {
        [self _recursivelySetScale:scale
                          forLayer:aLayer];
    }
}

- (void)setFillColor:(NSColor *)aColor
{
    if(fillColor != nil) {
        [fillColor release], fillColor = nil;
    }
    fillColor = [aColor retain];
    [_layerTree release], _layerTree = nil;
}

- (void)setStrokeColor:(NSColor *)aColor
{
    if(strokeColor != nil) {
        [strokeColor release], strokeColor = nil;
    }
    strokeColor = [aColor retain];
    [_layerTree release], _layerTree = nil;
}

- (IJSVGLayer *)layerWithTree:(IJSVGLayerTree *)tree
{
    // clear memory
    if(_layerTree != nil) {
        [_layerTree release], _layerTree = nil;
    }

    // force rebuild of the tree
    IJSVGBeginTransactionLock();
    _layerTree = [[tree layerForNode:_group] retain];
    IJSVGEndTransactionLock();
    return _layerTree;
}

- (IJSVGLayer *)layer
{
    if(_layerTree != nil) {
        return _layerTree;
    }

    // create the renderer and assign default values
    // from this SVG object
    IJSVGLayerTree * renderer = [[[IJSVGLayerTree alloc] init] autorelease];
    renderer.viewBox = self.viewBox;
    renderer.fillColor = self.fillColor;
    renderer.strokeColor = self.strokeColor;

    // return the rendered layer
    return [self layerWithTree:renderer];
}

#pragma mark IJSVGParserDelegate

- (void)svgParser:(IJSVGParser *)svg
      foundSubSVG:(IJSVG *)subSVG
    withSVGString:(NSString *)string
{
    if(_delegate != nil && _respondsTo.shouldHandleSubSVG == 1) {
        [_delegate svg:self
           foundSubSVG:subSVG
         withSVGString:string];
    }
}

@end
