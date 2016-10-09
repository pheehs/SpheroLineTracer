//
//  CircleLineSensor.h
//  SpheroLineTracer
//
//  Created by Shuhei Horiguchi on 2016/09/28.
//  Copyright © 2016年 Robohan. All rights reserved.
//

#ifndef CircleLineSensor_h
#define CircleLineSensor_h

#import "GPUImageFilter.h"

@interface CircleLineSensorFilter : GPUImageFilter
{
    GLint XcenterUniform;
    GLint YcenterUniform;
    GLint R1Uniform;
    GLint R2Uniform;
    GLfloat *circleCoordinates;
}

@property(readwrite, nonatomic) CGFloat Xcenter;
@property(readwrite, nonatomic) CGFloat Ycenter;
@property(readwrite, nonatomic) CGFloat R1;
@property(readwrite, nonatomic) CGFloat R2;

@end


#endif /* CircleLineSensor_h */
