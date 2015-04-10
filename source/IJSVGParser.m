//
//  IJSVGParser.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGParser.h"

@implementation IJSVGParser

@synthesize viewBox;

+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
{
    return [[self class] groupForFileURL:aURL
                                delegate:nil];
}

+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                        delegate:(id<IJSVGParserDelegate>)delegate
{
    return [[[[self class] alloc] initWithFileURL:aURL
                                         delegate:delegate] autorelease];
}

- (void)dealloc
{
    [super dealloc];
}

- (id)initWithFileURL:(NSURL *)aURL
             delegate:(id<IJSVGParserDelegate>)delegate
{
    if( ( self = [self initWithFileURL:aURL
                              encoding:NSUTF8StringEncoding
                              delegate:delegate] ) != nil )
    {
    }
    return self;
}

- (id)initWithFileURL:(NSURL *)aURL
             encoding:(NSStringEncoding)encoding
             delegate:(id<IJSVGParserDelegate>)delegate
{
    NSData *data = [[[NSData alloc] initWithContentsOfURL:aURL] autorelease];
    return [self initWithData:data encoding:encoding delegate:delegate];
}

- (id)initWithData:(NSData *)data
          encoding:(NSStringEncoding)encoding
          delegate:(id<IJSVGParserDelegate>)delegate
{
    if( ( self = [super init] ) != nil )
    {
        _delegate = delegate;
        
        // load the document / file, assume its UTF8
        NSError * error = nil;
        NSString * str = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
        
        // use NSXMLDocument as its the easiest thing to do on OSX
        _document = [[NSXMLDocument alloc] initWithXMLString:str
                                                     options:0
                                                       error:&error];
        
        // where the fun begin...
        [self _parse];
        
        // we have actually finished with the document at this point
        // so just get rid of it
        [_document release], _document = nil;
        
    }
    return self;
}

- (NSSize)size
{
    return viewBox.size;
}

- (void)_parse
{
    NSXMLElement * svgElement = [_document rootElement];
    
    // find the sizebox!
    NSXMLNode * attribute = nil;
    if( ( attribute = [svgElement attributeForName:@"viewBox"] ) != nil )
    {
        
        // we have a viewbox...
        CGFloat * box = [IJSVGUtils parseViewBox:[attribute stringValue]];
        viewBox = NSMakeRect( box[0], box[1], box[2], box[3]);
        free(box);
        
    } else {
        
        // there is no view box so find the width and height
        CGFloat w = [[[svgElement attributeForName:@"width"] stringValue] floatValue];
        CGFloat h = [[[svgElement attributeForName:@"height"] stringValue] floatValue];
        viewBox = NSMakeRect( 0.f, 0.f, w, h );
    }
    
    // find foreign objects...
    NSXMLElement * switchElement = nil;
    NSArray * switchElements = [svgElement nodesForXPath:@"switch"
                                                   error:nil];
    if( [switchElements count] != 0 )
    {
        // for performance reasons, ask for this once!
        BOOL handlesShouldHandle = [_delegate respondsToSelector:@selector(svgParser:shouldHandleForeignObject:)];
        BOOL handlesHandle = [_delegate respondsToSelector:@selector(svgParser:handleForeignObject:document:)];
        
        // we have a switch, work out what the objects are...
        switchElement = switchElements[0];
        NSXMLElement * child = nil;
        if( _delegate != nil )
        {
            for( child in [switchElement children] )
            {
                if( [[child name] isEqualToString:@"foreignObject"] )
                {
                    // create the temp foreign object
                    IJSVGForeignObject * foreignObject = [[[IJSVGForeignObject alloc] init] autorelease];
                    
                    // grab the common attributes
                    [self _parseElementForCommonAttributes:child
                                                      node:foreignObject];
                    foreignObject.requiredExtension = [[child attributeForName:@"requiredExtensions"] stringValue];
                    
                    // ask the delegate
                    if( handlesShouldHandle && [_delegate svgParser:self
                                          shouldHandleForeignObject:foreignObject] && handlesHandle )
                    {
                        [_delegate svgParser:self
                         handleForeignObject:foreignObject
                                    document:_document];
                        break;
                    }
                }
            }
        }
        // set the main element to the switch
        svgElement = switchElement;
    }
    
    // the root element is SVG, so iterate over its children
    // recursively
    self.name = svgElement.name;
    [self _parseBlock:svgElement
            intoGroup:self
                  def:NO];
    
}

- (void)_parseElementForCommonAttributes:(NSXMLElement *)element
                                    node:(IJSVGNode *)node
{
    
    // x and y
    NSXMLNode * xAttribute = [element attributeForName:@"x"];
    if( xAttribute != nil )
        node.x = [[xAttribute stringValue] floatValue];
    
    NSXMLNode * yAttribute = [element attributeForName:@"y"];
    if( yAttribute )
        node.y = [[yAttribute stringValue] floatValue];
    
    // any clippath?
    NSXMLNode * clipPathAttribute = [element attributeForName:@"clip-path"];
    if( clipPathAttribute != nil )
    {
        NSString * clipID = [IJSVGUtils defURL:[clipPathAttribute stringValue]];
        if( clipID )
            node.clipPath = (IJSVGGroup *)[node defForID:clipID];
    }
    
    // any line cap style?
    NSXMLNode * lineCapAttribute = [element attributeForName:@"stroke-linecap"];
    if( lineCapAttribute != nil )
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:[lineCapAttribute stringValue]];
    
    // any line join style?
    NSXMLNode * lineJoinAttribute = [element attributeForName:@"stroke-linejoin"];
    if( lineJoinAttribute != nil )
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:[lineCapAttribute stringValue]];
    
    // work out any extra attributes
    // opacity
    NSXMLNode * opacityAttribute = [element attributeForName:@"opacity"];
    if( opacityAttribute != nil )
        node.opacity = [IJSVGUtils floatValue:[opacityAttribute stringValue]];
    
    NSXMLNode * strokeOpacityAttribute = [element attributeForName:@"stroke-opacity"];
    if( strokeOpacityAttribute != nil )
        node.strokeOpacity = [IJSVGUtils floatValue:[strokeOpacityAttribute stringValue]];
    
    // stroke color
    NSXMLNode * strokeAttribute = [element attributeForName:@"stroke"];
    if( strokeAttribute != nil )
    {
        node.strokeColor = [IJSVGColor colorFromString:[strokeAttribute stringValue]];
        if( node.strokeOpacity != 1.f )
            node.strokeColor = [IJSVGColor changeAlphaOnColor:node.strokeColor
                                                           to:node.strokeOpacity];
    }
    
    // dash node
    NSXMLNode * dashArrayAttribute = [element attributeForName:@"stroke-dasharray"];
    if( dashArrayAttribute != nil )
    {
        NSInteger paramCount = 0;
        CGFloat * params = [IJSVGUtils commandParameters:[dashArrayAttribute stringValue]
                                                   count:&paramCount];
        node.strokeDashArray = params;
        node.strokeDashArrayCount = paramCount;
    }
    
    // dash offset
    NSXMLNode * dashOffsetAttribute = [element attributeForName:@"stroke-dashoffset"];
    if( dashOffsetAttribute != nil )
        node.strokeDashOffset = [[dashOffsetAttribute stringValue] floatValue];
    
    // fill opacity
    NSXMLNode * fillOpacityAttribute = [element attributeForName:@"fill-opacity"];
    if( fillOpacityAttribute != nil )
        node.fillOpacity = [IJSVGUtils floatValue:[fillOpacityAttribute stringValue]];
    
    // fill color
    NSXMLNode * fillAttribute = [element attributeForName:@"fill"];
    if( fillAttribute != nil )
    {
        NSString * defID = [IJSVGUtils defURL:[fillAttribute stringValue]];
        if( defID != nil )
            node.fillGradient = (IJSVGGradient *)[node defForID:defID];
        else {
            // change the fill color over if its allowed
            node.fillColor = [IJSVGColor colorFromString:[fillAttribute stringValue]];
            if( node.fillOpacity != 1.f )
                node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                             to:node.fillOpacity];
        }
    }
    
    // stroke width
    NSXMLNode * strokeWidthAttribute = [element attributeForName:@"stroke-width"];
    if( strokeWidthAttribute != nil )
        node.strokeWidth = [IJSVGUtils floatValue:[strokeWidthAttribute stringValue]];
    
    // ID
    NSXMLNode * idAttribute = [element attributeForName:@"id"];
    if( idAttribute != nil )
        node.identifier = [idAttribute stringValue];
    
    // transforms
    NSXMLNode * transformAttribute = [element attributeForName:@"transform"];
    if( transformAttribute != nil )
    {
        NSMutableArray * tran = [[[NSMutableArray alloc] init] autorelease];
        [tran addObjectsFromArray:[IJSVGTransform transformsForString:[transformAttribute stringValue]]];
        if( node.transforms != nil )
            [tran addObjectsFromArray:node.transforms];
        node.transforms = tran;
    }
    
    // winding rule
    NSXMLNode * windingRuleAttribute = [element attributeForName:@"fill-rule"];
    if( windingRuleAttribute != nil )
    {
        node.windingRule = [IJSVGUtils windingRuleForString:[windingRuleAttribute stringValue]];
    } else
        node.windingRule = IJSVGWindingRuleInherit;
    
    // width
    NSXMLNode * widthAttribute = [element attributeForName:@"width"];
    if( widthAttribute != nil )
    {
        if( [[widthAttribute stringValue] isEqualToString:@"100%"] )
            node.width = self.viewBox.size.width;
        else
            node.width = [IJSVGUtils floatValue:[widthAttribute stringValue]];
    }
    
    // height
    NSXMLNode * heightAttribute = [element attributeForName:@"height"];
    if( heightAttribute != nil )
    {
        if( [[heightAttribute stringValue] isEqualToString:@"100%"] )
            node.height = self.viewBox.size.height;
        else
            node.height = [IJSVGUtils floatValue:[heightAttribute stringValue]];
    }
    
    // now we need to work out if there is any style...apparently this is a thing now,
    // people use the style attribute... -_-
    // style
    NSXMLNode * styleNode = [element attributeForName:@"style"];
    if( styleNode != nil )
    {
        IJSVGStyle * style = [IJSVGStyle parseStyleString:[styleNode stringValue]];
        
        // fill color
        NSColor * fill = nil;
        if( ( fill = [style property:@"fill"] ) != nil )
        {
            if( [fill isKindOfClass:[NSString class]] )
            {
                NSString * defID = [IJSVGUtils defURL:(NSString *)fill];
                if( defID != nil )
                    node.fillGradient = (IJSVGGradient *)[node defForID:defID];
            } else {
                if( [IJSVGColor computeColor:fill] != nil )
                    node.fillColor = fill;
            }
        }
        
        // fill opacity
        NSNumber * num = nil;
        if( ( num = [style property:@"fill-opacity"] ) != nil )
            node.fillOpacity = num.floatValue;
        
        // stroke colour
        NSColor * stroke = nil;
        if( ( stroke = [style property:@"stroke"] ) != nil )
        {
            if( [IJSVGColor computeColor:stroke] )
                node.strokeColor = stroke;
        }
        
        // stroke width
        if( [style property:@"stroke-width"] != 0 )
            node.strokeWidth = [[style property:@"stroke-width"] floatValue];
        
        // line cap style
        if( [style property:@"stroke-linecap"] != nil )
            node.lineCapStyle = [IJSVGUtils lineCapStyleForString:[style property:@"stroke-linecap"]];
        
        // line join style
        if( [style property:@"stroke-linejoin"] != nil )
            node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:[style property:@"stroke-linejoin"]];
        
        // opacity
        if( [style property:@"opacity"] != nil )
            node.opacity = [[style property:@"opacity"] floatValue];
        
        // stroke opacity
        if( [style property:@"stroke-opacity"] != nil )
            node.strokeOpacity = [[style property:@"stroke-opacity"] floatValue];
        
        // dash
        if( [style property:@"stroke-dasharray"] != nil )
        {
            NSInteger paramCount = 0;
            CGFloat * params = [IJSVGUtils commandParameters:[style property:@"stroke-dasharray"]
                                                       count:&paramCount];
            node.strokeDashArray = params;
            node.strokeDashArrayCount = paramCount;
        }
        
        // dash offset
        if( [style property:@"stroke-dashoffset"] != nil )
            node.strokeDashOffset = [[style property:@"stroke-dashoffset"] floatValue];
        
        // winding rule
        if( [style property:@"fill-rule"] != nil )
            node.windingRule = [IJSVGUtils windingRuleForString:[style property:@"fill-rule"]];
        
    }
    
}

- (void)_parseBlock:(NSXMLElement *)anElement
          intoGroup:(IJSVGGroup*)parentGroup
                def:(BOOL)flag
{
    for( NSXMLElement * element in [anElement children] )
    {
        NSString * subName = element.name;
        IJSVGNodeType aType = [IJSVGNode typeForString:subName];
        switch( aType )
        {
            default:
            case IJSVGNodeTypeNotFound:
                continue;
                
                // def
            case IJSVGNodeTypeDef: {
                [self _parseBlock:element
                        intoGroup:parentGroup
                              def:YES];
                continue;
            }
                
                // group
            case IJSVGNodeTypeGroup: {
                IJSVGGroup * group = [[[IJSVGGroup alloc] init] autorelease];
                group.type = aType;
                group.name = subName;
                group.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:group];
                
                if( !flag )
                    [parentGroup addChild:group];
                
                // recursively parse blocks
                [self _parseBlock:element
                        intoGroup:group
                              def:NO];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:group];
                continue;
            }
                
                // path
            case IJSVGNodeTypePath: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parsePathCommandData:[[element attributeForName:@"d"] stringValue]
                                   intoPath:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // polygon
            case IJSVGNodeTypePolygon: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parsePolygon:element
                           intoPath:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // polyline
            case IJSVGNodeTypePolyline: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parsePolyline:element
                            intoPath:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // rect
            case IJSVGNodeTypeRect: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseRect:element
                        intoPath:path];
                
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // line
            case IJSVGNodeTypeLine: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parseLine:element
                        intoPath:path];
                [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // circle
            case IJSVGNodeTypeCircle: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parseCircle:element
                          intoPath:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil)
                    [parentGroup addDef:path];
                continue;
            }
                
                // ellipse
            case IJSVGNodeTypeEllipse: {
                IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
                path.type = aType;
                path.name = subName;
                path.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:path];
                [self _parseEllipse:element
                           intoPath:path];
                
                if( !flag )
                    [parentGroup addChild:path];
                
                // could be defined
                if( flag || [element attributeForName:@"id"] != nil )
                    [parentGroup addDef:path];
                continue;
            }
                
                // use
            case IJSVGNodeTypeUse: {
                
                NSString * xlink = [[element attributeForName:@"xlink:href"] stringValue];
                NSString * xlinkID = [xlink substringFromIndex:1];
                IJSVGNode * node = [parentGroup defForID:xlinkID];
                
                // could be an alias, aswell as a def...
                if( [element attributeForName:@"id"] != nil )
                {
                    IJSVGNode * theNode = [[node copy] autorelease];
                    theNode.parentNode = parentGroup;
                    
                    // grab common attributes
                    [self _parseElementForCommonAttributes:element
                                                      node:theNode];
                    
                    // add them
                    [parentGroup addDef:theNode];
                    [parentGroup addChild:theNode];
                    continue;
                }
                
                if( node != nil )
                {
                    // copy the node
                    node = [[node copy] autorelease];
                    node.parentNode = parentGroup;
                    
                    // grab the common attributes
                    [self _parseElementForCommonAttributes:element
                                                      node:node];
                    [parentGroup addChild:node];
                }
                continue;
            }
                
                // linear gradient
            case IJSVGNodeTypeLinearGradient: {
                
                IJSVGLinearGradient * gradient = [[[IJSVGLinearGradient alloc] init] autorelease];
                gradient.type = aType;
                gradient.gradient = [IJSVGLinearGradient parseGradient:element
                                                              gradient:gradient];
                [self _parseElementForCommonAttributes:element
                                                  node:gradient];
                [parentGroup addDef:gradient];
                continue;
            }
                
                // radial gradient
            case IJSVGNodeTypeRadialGradient: {
                IJSVGRadialGradient * gradient = [[[IJSVGRadialGradient alloc] init] autorelease];
                gradient.type = aType;
                gradient.gradient = [IJSVGRadialGradient parseGradient:element
                                                              gradient:gradient];
                [self _parseElementForCommonAttributes:element
                                                  node:gradient];
                [parentGroup addDef:gradient];
                continue;
            }
                
                // clippath
            case IJSVGNodeTypeClipPath: {
                
                IJSVGGroup * group = [[[IJSVGGroup alloc] init] autorelease];
                group.type = aType;
                group.name = subName;
                group.parentNode = parentGroup;
                
                // find common attributes
                [self _parseElementForCommonAttributes:element
                                                  node:group];
                
                // recursively parse blocks
                [self _parseBlock:element
                        intoGroup:group
                              def:NO];
                
                // add it as a def
                [parentGroup addDef:group];
            }
                
        }
    }
}

#pragma mark Parser stuff!

- (void)_parsePathCommandData:(NSString *)command
                     intoPath:(IJSVGPath *)path
{
    // invalid command
    if( command == nil || command.length == 0 )
        return;
    NSRegularExpression * exp = [IJSVGUtils commandNameRegex];
    __block NSString * previousCommand = nil;
    __block NSTextCheckingResult * previousMatch = nil;
    
    [exp enumerateMatchesInString:command
                          options:0
                            range:NSMakeRange( 0, command.length )
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
     {
         @autoreleasepool {
             if( previousMatch != nil )
             {
                 NSUInteger length = result.range.location - previousMatch.range.location;
                 NSString * commandString = [command substringWithRange:NSMakeRange(previousMatch.range.location,length)];
                 [self _parseCommandString:commandString
                           previousCommand:previousCommand
                                  intoPath:path];
                 [previousCommand release], previousCommand = nil;
                 previousCommand = [commandString copy];
                 [previousMatch release], previousMatch = nil;
             }
         }
         previousMatch = [result retain];
     }];
    
    NSRange range = NSMakeRange(previousMatch.range.location, command.length-previousMatch.range.location);
    [self _parseCommandString:[command substringWithRange:range]
              previousCommand:previousCommand
                     intoPath:path];
    
    // memory clean up
    [previousMatch release], previousMatch = nil;
    [previousCommand release], previousCommand = nil;
}

- (void)_parseCommandString:(NSString *)string
            previousCommand:(NSString *)previous
                   intoPath:(IJSVGPath *)path
{
    // work out the last command - the reason this is so long is because the command
    // could be a series of the same commands, so work it out by the number of parameters
    // there is per command string
    @autoreleasepool {
        IJSVGCommand * preCommand = nil;
        if( previous != nil )
        {
            IJSVGCommand * pre = [[[IJSVGCommand alloc] initWithCommandString:previous] autorelease];
            preCommand = (IJSVGCommand *)[[pre subCommands] lastObject];
        }
        
        // main commands
        IJSVGCommand * command = [[[IJSVGCommand alloc] initWithCommandString:string] autorelease];
        for( IJSVGCommand * subCommand in [command subCommands] )
        {
            [subCommand.commandClass runWithParams:subCommand.parameters
                                        paramCount:subCommand.parameterCount
                                   previousCommand:preCommand
                                              type:subCommand.type
                                              path:path];
            preCommand = subCommand;
        }
    }
}

- (void)_parseLine:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
{
    // convert a line into a command,
    // basically MX1 Y1LX2 Y2
    CGFloat x1 = [[[element attributeForName:@"x1"] stringValue] floatValue];
    CGFloat y1 = [[[element attributeForName:@"y1"] stringValue] floatValue];
    CGFloat x2 = [[[element attributeForName:@"x2"] stringValue] floatValue];
    CGFloat y2 = [[[element attributeForName:@"y2"] stringValue] floatValue];
    NSString * command = [NSString stringWithFormat:@"M%f %fL%f %f",x1,y1,x2,y2];
    [self _parsePathCommandData:command
                       intoPath:path];
}

- (void)_parseCircle:(NSXMLElement *)element
            intoPath:(IJSVGPath *)path
{
    CGFloat cX = [[[element attributeForName:@"cx"] stringValue] floatValue];
    CGFloat cY = [[[element attributeForName:@"cy"] stringValue] floatValue];
    CGFloat r = [[[element attributeForName:@"r"] stringValue] floatValue];
    NSRect rect = NSMakeRect( cX - r, cY - r, r*2, r*2);
    [path overwritePath:[NSBezierPath bezierPathWithOvalInRect:rect]];
}

- (void)_parseEllipse:(NSXMLElement *)element
             intoPath:(IJSVGPath *)path
{
    CGFloat cX = [[[element attributeForName:@"cx"] stringValue] floatValue];
    CGFloat cY = [[[element attributeForName:@"cy"] stringValue] floatValue];
    CGFloat rX = [[[element attributeForName:@"rx"] stringValue] floatValue];
    CGFloat rY = [[[element attributeForName:@"ry"] stringValue] floatValue];
    NSRect rect = NSMakeRect( cX-rX, cY-rY, rX*2, rY*2);
    [path overwritePath:[NSBezierPath bezierPathWithOvalInRect:rect]];
}

- (void)_parsePolyline:(NSXMLElement *)element
              intoPath:(IJSVGPath *)path
{
    [self _parsePoly:element
            intoPath:path
           closePath:NO];
}

- (void)_parsePolygon:(NSXMLElement *)element
             intoPath:(IJSVGPath *)path
{
    [self _parsePoly:element
            intoPath:path
           closePath:YES];
}

- (void)_parsePoly:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
         closePath:(BOOL)closePath
{
    NSString * points = [[element attributeForName:@"points"] stringValue];
    NSInteger count = 0;
    CGFloat * params = [IJSVGUtils commandParameters:points
                                               count:&count];
    if( (count % 2) != 0 )
    {
        // error occured, free the params
        free(params);
        return;
    }
    
    // construct a command
    NSMutableString * str = [[[NSMutableString alloc] init] autorelease];
    [str appendFormat:@"M%f %f L",params[0],params[1]];
    for( NSInteger i = 2; i < count; i+=2 )
    {
        [str appendFormat:@"%f %f ",params[i],params[i+1]];
    }
    if( closePath )
        [str appendString:@"z"];
    [self _parsePathCommandData:str
                       intoPath:path];
    free(params);
    
}

- (void)_parseRect:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
{
    
    CGFloat aX = [[[element attributeForName:@"x"] stringValue] floatValue];
    CGFloat aY = [[[element attributeForName:@"y"] stringValue] floatValue];
    
    CGFloat aWidth = [IJSVGUtils floatValue:[[element attributeForName:@"width"] stringValue]
                         fallBackForPercent:self.viewBox.size.width];
    CGFloat aHeight = [IJSVGUtils floatValue:[[element attributeForName:@"height"] stringValue]
                          fallBackForPercent:self.viewBox.size.width];
    
    CGFloat rX = [[[element attributeForName:@"rx"] stringValue] floatValue];
    CGFloat rY = [[[element attributeForName:@"ry"] stringValue] floatValue];
    
    [element removeAttributeForName:@"x"];
    [element removeAttributeForName:@"y"];
    [element removeAttributeForName:@"width"];
    [element removeAttributeForName:@"height"];
    [path overwritePath:[NSBezierPath bezierPathWithRoundedRect:NSMakeRect( aX, aY, aWidth, aHeight)
                                                        xRadius:rX
                                                        yRadius:rY]];
}

@end
