//
//  DBCameraMacros.h
//  DBCamera
//
//  Created by iBo on 17/02/14.
//  Copyright (c) 2014 PSSD - Daniele Bogo. All rights reserved.
//

#ifndef DBCamera_DBCameraMacros_h
#define DBCamera_DBCameraMacros_h

/**
 *  Use HEX color value with 0x000000 format
 */
#define RGBColor(rgbValue, alphaValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:alphaValue]
/**
 *  Check if UIScreen is retina
 */
#define IS_RETINA_4 ( [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2 && [[UIScreen mainScreen] bounds].size.height > 480)


#ifndef CGFLOAT_CEIL
#ifdef CGFLOAT_IS_DOUBLE
#define CGFLOAT_CEIL(value) ceil(value)
#else
#define CGFLOAT_CEIL(value) ceilf(value)
#endif
#endif

#define kAspectRatio (9.0f/11.0f)
#endif