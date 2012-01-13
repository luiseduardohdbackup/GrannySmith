//
//  NSString+GSParsingHelper.m
//  -GrannySmith-
//
//  Created by Bao Lei on 7/14/11.
//  Copyright 2011 hulu. All rights reserved.
//

#import "NSString+GSParsingHelper.h"
#import "GSFancyTextDefines.h"

@implementation NSString (GSParsingHelper)

- (NSMutableArray*) linesWithWidth:(CGFloat)width font:(UIFont*)font firstLineWidth:(CGFloat)firstLineWidth limitLineCount:(int)limitLineCount {

//    NSLog(@"LineBreak - The string: %@, 1st line: %f, other lines: %f", self, firstLineWidth, width);
    
    NSMutableString* firstLineBlocked = [NSMutableString string];
    if (firstLineWidth < width) {
        CGFloat spaceWidth = [@" " sizeWithFont:font].width;
        int spacesToStart = (int)ceilf((width - firstLineWidth) / spaceWidth);
        for (int i=0; i<spacesToStart; i++) {
            [firstLineBlocked appendString:@" "];
        }
        // there will always be 1 or 2 space mismatch..
        while ([firstLineBlocked sizeWithFont:font].width < width - firstLineWidth) {
            [firstLineBlocked appendString:@" "];
        }
    }
    
    NSMutableArray* lines = [[NSMutableArray alloc] init];
    NSMutableString* currentLine = [[NSMutableString alloc] init];

    CGFloat charWidth = [[self substringToIndex:1] sizeWithFont:font].width;
    
    // estimate the number of characters for each line
    int step = 0;
    
    for (int i=0; i<self.length; ){  // we control index move in the loop
    
        // if we are already 1 step reached line count limit, just return the whole thing for the next line
        if (limitLineCount>0 && lines.count == limitLineCount-1) {
            [lines addObject:[self substringFromIndex:i]];
            GSRelease(currentLine);
            return GSAutoreleased(lines);
        }
        
        // if the rest of the string begins with \n
        BOOL beginsWithBR = [[self substringWithRange:NSMakeRange(i, 1)] isEqualToString:@"\n"];
                
        // deal with \n first
        if (beginsWithBR){
            NSLog(@"found \\n at [%d]", i);
            
            if (currentLine.length>0) {
                NSLog(@"adding line: %@. i=[%d]",currentLine, i);
                [lines addObject: [NSString stringWithString:currentLine]];
                [currentLine setString:@""];
                
                // before adding the next line, we need to check limitLineCount
                if (limitLineCount>0 && lines.count == limitLineCount-1) {
                    [lines addObject:[self substringFromIndex:i]];
                    GSRelease(currentLine);
                    return GSAutoreleased(lines);
                }
            }
            
            [lines addObject:@""];
            i = i + 1;
            continue;
        }
    
        // read a range of characters.. try to go beyond the line for just a little bit
        CGFloat lineWidth = lines.count? width : firstLineWidth;
        step = (int) (lineWidth*1.4 / charWidth);
        if (i+step > self.length) {
            step = self.length - i;
        }
        
        NSLog(@"i=%d, step=%d, length=%d", i, step, self.length);
        NSString* characters = [self substringWithRange:NSMakeRange(i, step)];
        
        // if we have a \n in the characters read...
        int brPosition = [characters rangeOfString:@"\n"].location;
        if (brPosition != NSNotFound) {
            characters = [characters substringToIndex:brPosition];
            NSLog(@"string before \\n: %@", characters);
            i = i + brPosition; // set the index to the "\n" position, continue and let the next cycle handle the "\n".
        }
        else {
            i = i + step;
        }
        // the next character to be inserted is at i now

        if (!currentLine.length && lines.count && [[lines lastObject] length]) {
            // if it's not the first line, and this is the first character, and the previous line isn't ended by \n
            // we just skip the leading chars
            [currentLine appendFormat:@"%@", [characters stringByTrimmingLeadingWhitespace]];
        }
        else {
            [currentLine appendFormat:@"%@", characters];
        }
        
        NSString* lineToCalcWidth = (lines.count || !firstLineBlocked.length) ? currentLine : [NSString stringWithFormat:@"%@%@", firstLineBlocked, currentLine];
        CGSize appleSize = [ lineToCalcWidth
                            sizeWithFont:font
                            constrainedToSize:CGSizeMake(width,1000.f) 
                            lineBreakMode:UILineBreakModeWordWrap];
        
        NSLog(@"[%d] current line: %@. width to confine: %f, apple width: %f", i, currentLine, width, appleSize.width);
        
        
        // if we unestimated the number of characters need, add until we exceed the line
        while (appleSize.height <= font.lineHeight) {
            
            // if the last character is finished. conclude here.
            if (i>=self.length) {
                [lines addObject: [NSString stringWithString:currentLine]];
                GSRelease(currentLine);
                return GSAutoreleased(lines);
            }
            characters = [self substringWithRange:NSMakeRange(i, 1)];
            
            // if we meet a \n
            if ([characters isEqualToString:@"\n"]) {
                [lines addObject: [NSString stringWithString:currentLine]];
                [currentLine setString:@""]; // let the next cycle handle "\n"
                break;
            }
            [currentLine appendString: characters];
            i++;
            lineToCalcWidth = (lines.count || !firstLineBlocked.length) ? currentLine : [NSString stringWithFormat:@"%@%@", firstLineBlocked, currentLine];
            appleSize = [ lineToCalcWidth
                         sizeWithFont:font
                         constrainedToSize:CGSizeMake(width,1000.f) 
                         lineBreakMode:UILineBreakModeWordWrap];
            NSLog(@"advanced to [%d]: %@ (height=%f, targeting:>%f)", i-1, lineToCalcWidth, appleSize.height, font.lineHeight);
        }
        
        if (appleSize.height > font.lineHeight) {
            
            CGFloat idealWidth = appleSize.width;
            
            int minLength = 1; // a line is at least one char
            // special case
            if (!lines.count && firstLineWidth < width) {
                // if it's the first line, and first line width < rest width, we allow zero character just for this line
                minLength = 0;
            }
            
            // take out characters one by one until the width is idealWidth
            while (currentLine.length > minLength && [lineToCalcWidth sizeWithFont:font].width > idealWidth) {
                [currentLine deleteCharactersInRange:NSMakeRange(currentLine.length-1, 1)];
                lineToCalcWidth = (lines.count || !firstLineBlocked.length) ? currentLine : [NSString stringWithFormat:@"%@%@", firstLineBlocked, currentLine];
                i--;
                NSLog(@"retreat to [%d]: %@ (width=%f, targeting:%f)", i-1, lineToCalcWidth, [lineToCalcWidth sizeWithFont:font].width, idealWidth);
            }
            
            NSLog(@"adding line: %@. i=[%d]",currentLine, i);
            
            [lines addObject: [NSString stringWithString:currentLine]];
            [currentLine setString:@""];
        }
        
    }
    if (currentLine.length>0) {
        NSLog(@"THIS SHOULD NEVER HAPPEN");
        NSLog(@"adding line: %@. (last line)",currentLine);
        [lines addObject: [NSString stringWithString:currentLine]];
    }
 
//    NSLog(@"lines: %@", lines);
    
    GSRelease(currentLine);
    return GSAutoreleased(lines);
}


- (NSMutableArray*) linesWithWidth:(CGFloat)width font:(UIFont*)font {
    return [self linesWithWidth:width font:font firstLineWidth:width limitLineCount:0];
}

-(NSString*)stringByTrimmingLeadingWhitespace {
    if (! trim(self).length) {
        return @"";
    }
    
    int i = 0;
    while ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i++;
    }
    return [self substringFromIndex:i];
}

- (NSString*)stringByTrimmingTrailingWhitespace {
    if (! trim(self).length) {
        return @"";
    }
    
    int i = self.length - 1;
    while ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i--;
    }
    return [self substringToIndex:i+1];
}

- (NSString*)firstNonWhitespaceCharacterSince:(int)location foundAt:(int*)foundLocation {
    if (! trim(self).length) {
        return @"";
    }
    BOOL found = NO;
    int i;
    NSString* character;
    for (i=location; i<self.length; i++) {
        character = [self substringWithRange:NSMakeRange(i, 1)];
        if (trim(character).length) {
            found = YES;
            break;
        }
    }
    if (found) {
        *foundLocation = i;
        return character;
    }
    else {
        *foundLocation = self.length;
        return @"";
    }
}

@end
