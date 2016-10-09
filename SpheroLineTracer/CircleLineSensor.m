//
//  CircleLineSensor.m
//  SpheroLineTracer
//
//  Created by Shuhei Horiguchi on 2016/09/28.
//  Copyright © 2016年 Robohan. All rights reserved.
//

#import "CircleLineSensor.h"

NSString *const kCircleLineSensorVertexShaderString = SHADER_STRING
(
 precision highp float;
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;

 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );
NSString *const kCircleLineSensorFragmentShaderString = SHADER_STRING
(
 precision highp float;
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float Xcenter;
 uniform float Ycenter;
 uniform float R1;
 uniform float R2;
 
 void main()
 {
     float x = textureCoordinate.x - Xcenter;
     float y = textureCoordinate.y - Ycenter;
     //vec2 vecR = textureCoordinate - vec2(Xcenter, Ycenter);
     //float R = length(vecR);
     float R = sqrt(x*x + y*y);
     
     /*if (R >= R1 && R <= R2) {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
     } else {
         gl_FragColor = vec4(0);
     }*/
     vec4 color = texture2D(inputImageTexture, textureCoordinate);
     if (R > R1 && R < R1+R2) {
         gl_FragColor = vec4(color.r, 0, 1.-color.r, 1.);
     }else {
         gl_FragColor = color;
     }
     
 }
);




@implementation CircleLineSensorFilter

@synthesize Xcenter = _Xcenter;
@synthesize Ycenter = _Ycenter;
@synthesize R1 = _R1;
@synthesize R2 = _R2;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kCircleLineSensorVertexShaderString fragmentShaderFromString:kCircleLineSensorFragmentShaderString]))
    {
        return nil;
    }
    runSynchronouslyOnVideoProcessingQueue(^{
        XcenterUniform = [filterProgram uniformIndex:@"Xcenter"];
        YcenterUniform = [filterProgram uniformIndex:@"Ycenter"];
        R1Uniform = [filterProgram uniformIndex:@"R1"];
        R2Uniform = [filterProgram uniformIndex:@"R2"];

        self.Xcenter = 0.5;
        self.Ycenter = 0.5;
        self.R1 = 0.2;
        self.R2 = 0.1;
    });
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setXcenter:(CGFloat)Xcenter
{
    _Xcenter = Xcenter;
    
    [self setFloat:_Xcenter forUniform:XcenterUniform program:filterProgram];
}

- (void)setYcenter:(CGFloat)Ycenter
{
    _Ycenter = Ycenter;
    
    [self setFloat:_Ycenter forUniform:YcenterUniform program:filterProgram];
}

- (void)setR1:(CGFloat)R1
{
    _R1 = R1;
    
    [self setFloat:_R1 forUniform:R1Uniform program:filterProgram];
}

- (void)setR2:(CGFloat)R2
{
    _R2 = R2;
    
    [self setFloat:_R2 forUniform:R2Uniform program:filterProgram];
}
@end

