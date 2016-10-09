//
//  ViewController.h
//  SpheroLineTracer
//
//  Created by Shuhei Horiguchi on 2016/09/19.
//  Copyright © 2016年 Robohan. All rights reserved.
//

#import "GPUImage.h"
#import <UIKit/UIKit.h>
#import <RobotKit/RobotKit.h>


@interface ViewController : UIViewController
{
    GPUImageVideoCamera *videoCamera;
    GPUImageOutput<GPUImageInput> *binaryFilter;
    GPUImageOutput<GPUImageInput> *filter;
    GPUImageOutput<GPUImageInput> *filter2;
    Float32 yaw_sphero;
    Float32 yaw_iphone;
    Float32 yaw0_iphone;
    Float32 R1, R2;
    CGPoint center;
    uint32_t thetaLine;
    uint32_t renderCount;
    Float32 velocity;
    RKLocatorVelocity velocity_sphero;
    unsigned int thetaArray_iphone[360];
    unsigned int numLine;
    Float32 rollThetaPrev_sphero;
    bool isStarted;
}

@end

