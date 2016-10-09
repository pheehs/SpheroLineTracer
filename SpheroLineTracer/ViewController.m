//
//  ViewController.m
//  SpheroLineTracer
//
//  Created by Shuhei Horiguchi on 2016/09/19.
//  Copyright © 2016年 Robohan. All rights reserved.
//

#import "ViewController.h"
#import <RobotKit/RobotKit.h>
#import <CoreMotion/CoreMotion.h>
#import <math.h>
#import "CircleLineSensor.h"

@interface ViewController()

@property (nonatomic, strong) IBOutlet UILabel *yawValueLabel;
@property (strong, nonatomic) IBOutlet UILabel *XValueLabel;
@property (strong, nonatomic) IBOutlet UILabel *YValueLabel;
@property (strong, nonatomic) IBOutlet UILabel *vXValueLabel;
@property (strong, nonatomic) IBOutlet UILabel *vYValueLabel;
@property (strong, nonatomic) IBOutlet UISwitch *stabilizeSwitch;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) IBOutlet UILabel *yawLabel;
@property (strong, nonatomic) IBOutlet GPUImageView *cameraView;
@property (strong, nonatomic) IBOutlet GPUImageView *filterView;

@property (strong, nonatomic) IBOutlet UILabel *XcenterLabel;
@property (strong, nonatomic) IBOutlet UILabel *YcenterLabel;
@property (strong, nonatomic) IBOutlet UILabel *R1Label;
@property (strong, nonatomic) IBOutlet UILabel *R2Label;

@property (strong, nonatomic) IBOutlet UILabel *thetaLabel;
@property (strong, nonatomic) IBOutlet UILabel *thetaLineLabel;
@property (strong, nonatomic) IBOutlet UILabel *velocityLabel;
@property (strong, nonatomic) IBOutlet UISlider *velocitySlider;
@property (strong, nonatomic) IBOutlet UILabel *thresholdLabel;

@property (strong, nonatomic) RKConvenienceRobot *robot;

@end

#define widthImage 480
#define heightImage 640
#define dR 10

@implementation ViewController

- (void)dealloc
{
    // ここに終了コードを書く
    // ARCがONなので[super dealloc]はいらない
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // デバイスのスリープタイマーを無効化
    UIApplication* application = [UIApplication sharedApplication];
    application.idleTimerDisabled = YES;
    
    /*CGAffineTransform trans = CGAffineTransformMakeRotation(-M_PI_2);
    _YcenterSlider.transform = trans;*/
    
    /*Register for application lifecycle notifications so we known when to connect and disconnect from the robot*/
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[RKRobotDiscoveryAgent sharedAgent] addNotificationObserver:self selector:@selector(handleRobotStateChangeNotification:)];
    
    // camera
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480
                                                      cameraPosition:AVCaptureDevicePositionFront];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    
    binaryFilter = [[GPUImageLuminanceThresholdFilter alloc] init];
    [(GPUImageLuminanceThresholdFilter *)binaryFilter setThreshold:0.5];
    filter = [[CircleLineSensorFilter alloc] init];
    filter2 = [[CircleLineSensorFilter alloc] init];
    
    [self startGyro];
    
    velocity =  0.;
    thetaLine = 0;
    renderCount = 0;
    velocity_sphero.x = 0;
    velocity_sphero.y = 0;
    yaw0_iphone = 0;
    rollThetaPrev_sphero = 0;
    isStarted = false;
    
    dispatch_async(dispatch_get_main_queue(), ^{

    CGSize size;
    size.height = heightImage; //指定しないとなぜか0になる
    size.width = widthImage;
    center.x = 0.41;
    center.y = 0.37;
    
    R1 = 0.13;
    R2 = 0.07;
    [(CircleLineSensorFilter *)filter setXcenter:center.x];
    [(CircleLineSensorFilter *)filter2 setXcenter:center.x];
    _XcenterLabel.text = [NSString stringWithFormat:@"%.02f", center.x];
    [(CircleLineSensorFilter *)filter setYcenter:center.y];
    [(CircleLineSensorFilter *)filter2 setYcenter:center.y];
    _YcenterLabel.text = [NSString stringWithFormat:@"%.02f", center.y];
    [(CircleLineSensorFilter *)filter setR1:R1];
    [(CircleLineSensorFilter *)filter2 setR1:R1];
    _R1Label.text = [NSString stringWithFormat:@"%.02f", R1];
    [(CircleLineSensorFilter *)filter setR2:R2];
    [(CircleLineSensorFilter *)filter2 setR2:R2];
    _R2Label.text = [NSString stringWithFormat:@"%.02f", R2];
    
    GPUImageRawDataOutput *rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:size resultsInBGRAFormat:YES];

    __unsafe_unretained GPUImageRawDataOutput * weakOutput = rawDataOutput;
    [rawDataOutput setNewFrameAvailableBlock:^{
        [weakOutput lockFramebufferForReading];
        GLubyte *outputBytes = [weakOutput rawBytesForImage]; // Binarized Image
        NSInteger bytesPerRow = [weakOutput bytesPerRowInOutput];

        for (unsigned int i = 0; i < 360; i++) {
            thetaArray_iphone[i] = 999;
        }
        bool inLine = false;
        unsigned int thetaLineStartArray[dR][180] = {999};
        unsigned int thetaLineEndArray[dR][180] = {999};
        unsigned int thetaArrayIndex[dR] = {0};
        for (unsigned int rIndex = 0; rIndex < dR; rIndex++){
        
            for (unsigned int thetaIndex = 0; thetaIndex < 360; thetaIndex++)
            {
            
                unsigned int xIndex = (center.x*widthImage) + ((R1+rIndex*R2/(dR-1))*widthImage) * sinf(thetaIndex * M_PI / 180.);
                unsigned int yIndex = (center.y*heightImage) - ((R1+rIndex*R2/(dR-1))*heightImage) * cosf(thetaIndex * M_PI / 180.);
                uint32_t color =   outputBytes[yIndex * bytesPerRow + xIndex * 4]; //red (0 or 255)
                if (color > 0) {
                    if(!inLine) {
                        thetaLineStartArray[rIndex][thetaArrayIndex[rIndex]] = thetaIndex;
                    }
                    inLine = true;
                
                }else {
                    if(inLine) {
                        if (thetaLineStartArray[rIndex][thetaArrayIndex[rIndex]] < 180 && thetaIndex > 180) {
                            // exclude Pole
                        } else {
                            thetaLineEndArray[rIndex][thetaArrayIndex[rIndex]] = thetaIndex;
                            thetaArrayIndex[rIndex]++;
                        }
                    }
                    inLine = false;
                }

            }
            if (inLine) {
                if (thetaLineStartArray[rIndex][0] == 0) {
                    thetaLineStartArray[rIndex][0] = thetaLineStartArray[rIndex][thetaArrayIndex[rIndex]];

                }
                thetaLineEndArray[rIndex][thetaArrayIndex[rIndex]] = 360;
                thetaArrayIndex[rIndex]++;
            }
        }
        
        //ラインかどうか判定
        unsigned int _numLine = 0;
        for (unsigned int i = 0; i < thetaArrayIndex[0]; i++) {
            unsigned int i_ = i; //rIndex1のLineのindex
            bool isLine = true;
            for (unsigned int rIndex1 = 0; rIndex1 < dR-1; rIndex1++) {
                unsigned int rIndex2 = rIndex1+1;
                bool foundLine = false;
                for(unsigned int j = 0; j < thetaArrayIndex[rIndex2]; j++) {

                    if ((thetaLineStartArray[rIndex1][i_] < thetaLineEndArray[rIndex1][i_] &&
                         thetaLineEndArray[rIndex1][i_] < thetaLineStartArray[rIndex2][j] &&
                         thetaLineStartArray[rIndex2][j] < thetaLineEndArray[rIndex2][j])||//s1e1s2e2
                        (thetaLineEndArray[rIndex2][j] < thetaLineStartArray[rIndex1][i_] &&
                         thetaLineStartArray[rIndex1][i_] < thetaLineEndArray[rIndex1][i_] &&
                         thetaLineEndArray[rIndex1][i_] < thetaLineStartArray[rIndex2][j])||//e2s1e1s2
                        (thetaLineStartArray[rIndex2][j] < thetaLineEndArray[rIndex2][j] &&
                         thetaLineEndArray[rIndex2][j] < thetaLineStartArray[rIndex1][i_] &&
                         thetaLineStartArray[rIndex1][i_] < thetaLineEndArray[rIndex1][i_])||//s2e2s1e1
                        (thetaLineEndArray[rIndex1][i_] < thetaLineStartArray[rIndex2][j] &&
                         thetaLineStartArray[rIndex2][j] < thetaLineEndArray[rIndex2][j] &&
                         thetaLineEndArray[rIndex2][j] < thetaLineStartArray[rIndex1][i_])){//e1s2e2s1
                            //　つながってない
                        
                        }else {
                            i_ = j;
                            foundLine = true;
                            break;
                        }
                }
                if (!foundLine) {
                    isLine = false;
                    break;
                }
                
            }
            if (isLine) {
                //ラインの中心のθ座標計算
                if (thetaLineStartArray[0][i] > thetaLineEndArray[0][i]) // 360deg と 0 degをまたぐとき
                    thetaArray_iphone[_numLine++] = ((thetaLineStartArray[0][i] + thetaLineEndArray[0][i] + 360) / 2) % 360;
                else
                    thetaArray_iphone[_numLine++] = (thetaLineStartArray[0][i] + thetaLineEndArray[0][i]) / 2;
            }
        }
        numLine = _numLine;
        
        float veloTheta_sphero = atan2f(velocity_sphero.y, velocity_sphero.x) * 180 / M_PI;
        Float32 dThetaVelo_sphero;
        Float32 dThetaVeloMin_sphero = 360;
        Float32 rollTheta_sphero;
        switch(numLine) {
            case 0:
                // Out of Course
                thetaLine = 999;
                NSLog(@"Out of Course: STOP");
                //[_robot sendCommand:[RKRollCommand commandWithHeading:(int)(veloTheta_sphero -180 +360)%360            andVelocity:  velocity]];
                //[_robot stop];
                //[_robot sendCommand:[RKRollCommand commandWithHeading:(int)(veloTheta_sphero -180 +360)%360 andVelocity:0]];
                [_robot setLEDWithRed:0.5f green:0.0f blue:0.0f];
                rollThetaPrev_sphero = -100.; //次はprev使わない
                break;
            case 1: // One Line under Pole
            case 3: // Two Line under Pole
                thetaArray_iphone[numLine++] = 180.;
                
            case 2: // One Line and Pole
            case 4: // Two Line and Pole
            default: // > 5 ERROR
                //速度ベクトルに近い方へ行く
                for(unsigned int i = 0; i < numLine; i++) {
                    rollTheta_sphero = (int)(thetaArray_iphone[i]-yaw_iphone+yaw0_iphone +360)%360;
                    if(rollThetaPrev_sphero < 0)
                        dThetaVelo_sphero = fmin(fabs(rollTheta_sphero - veloTheta_sphero), fabs(360 - rollTheta_sphero + veloTheta_sphero));
                    else
                        dThetaVelo_sphero = fmin(fabs(rollTheta_sphero - rollThetaPrev_sphero), fabs(360 - rollTheta_sphero + rollThetaPrev_sphero));
                    if(dThetaVelo_sphero < dThetaVeloMin_sphero) {
                        dThetaVeloMin_sphero = dThetaVelo_sphero;
                        thetaLine = thetaArray_iphone[i];
                    }
                }
                if (dThetaVeloMin_sphero > 160) { // 向きが大きく変わるときは向き変えずに進む
                    [_robot setLEDWithRed:0.5f green:0.0f blue:0.5f];
                    rollTheta_sphero = rollThetaPrev_sphero;
                } else {
                    [_robot setLEDWithRed:0.0f green:0.5f blue:0.0f];
                    rollTheta_sphero = (int)(thetaLine-yaw_iphone+yaw0_iphone +360)%360;
                }
                [_robot sendCommand:[RKRollCommand commandWithHeading:rollTheta_sphero andVelocity:velocity]];
                rollThetaPrev_sphero = rollTheta_sphero;

                break;

            /*default:
                // Error
                //[_robot stop];
                [_robot setLEDWithRed:0.5f green:0.0f blue:0.0f];
                break;*/
        }
        
        [weakOutput unlockFramebufferAfterReading];
        
        if (renderCount++ % 100 == 0) {
            renderCount = 0;
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSLog(@"thetaLine: %d, roll: %d", thetaLine, (int)(thetaLine-yaw_iphone+yaw0_iphone +360)%360);
                switch (numLine) {
                    case 0:
                        _thetaLabel.text = [NSString stringWithFormat:@"( 0)"];
                        break;
                    case 1:
                        _thetaLabel.text = [NSString stringWithFormat:@"( 1) %3d", thetaArray_iphone[0]];
                        break;
                    case 2:
                        _thetaLabel.text = [NSString stringWithFormat:@"( 2) %3d %3d", thetaArray_iphone[0], thetaArray_iphone[1]];
                        break;
                    case 3:
                        _thetaLabel.text = [NSString stringWithFormat:@"( 3) %3d %3d %3d", thetaArray_iphone[0], thetaArray_iphone[1], thetaArray_iphone[2]];
                        break;
                    case 4:
                        _thetaLabel.text = [NSString stringWithFormat:@"( 4) %3d %3d %3d %3d", thetaArray_iphone[0], thetaArray_iphone[1], thetaArray_iphone[2], thetaArray_iphone[3]];
                        break;
                    default:
                        _thetaLabel.text = [NSString stringWithFormat:@"( %d) %3d %3d %3d %3d ...", numLine, thetaArray_iphone[0], thetaArray_iphone[1], thetaArray_iphone[2], thetaArray_iphone[3]];
                        break;
                }
                _thetaLineLabel.text = [NSString stringWithFormat:@"%3d / %3d / %3d", thetaLine, (int)(thetaLine-yaw_iphone+yaw0_iphone +360)%360, (int)rollThetaPrev_sphero];
                
            });
        }
    }];
    
    [videoCamera addTarget:binaryFilter];
        GPUImageOpeningFilter* openingFilter = [[GPUImageOpeningFilter alloc] init];
        [binaryFilter addTarget:openingFilter];
        [openingFilter addTarget:filter];
        [filter addTarget:(GPUImageView *)_filterView];
        
    [videoCamera addTarget:filter2];
    [filter2 addTarget:(GPUImageView *)_cameraView];
    //[videoCamera addTarget:(GPUImageView *)_cameraView];

    [binaryFilter addTarget:rawDataOutput];
    
    [videoCamera startCameraCapture];
    });

}

- (void)appWillResignActive:(NSNotification*)notification {
    [RKRobotDiscoveryAgent stopDiscovery];
    [RKRobotDiscoveryAgent disconnectAll];
}

- (void)appDidBecomeActive:(NSNotification*)notification {
    [RKRobotDiscoveryAgent startDiscovery];
}

- (void)startGyro {
    _motionManager = [[CMMotionManager alloc] init];
    if (_motionManager.deviceMotionAvailable) {
        
        //__weak MasterViewController *viewController = self;
        _motionManager.deviceMotionUpdateInterval = 0.01;  // 100Hz
        
        // 向きの更新通知を開始する
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *motion, NSError *error)
         {
             //             NSLog(@"%f ",motion.attitude.pitch * 180 / M_PI);
             
             yaw_iphone = motion.attitude.yaw * 180 / M_PI;
             _yawLabel.text
             = [NSString stringWithFormat:@"%.02f", yaw_iphone - yaw0_iphone];
             
         }];
    }
}

- (void)sendSetDataStreamingCommand {
    // Requesting the Accelerometer X, Y, and Z filtered (in Gs)
    //            the IMU Angles roll, pitch, and yaw (in degrees)
    //            the Quaternion data q0, q1, q2, and q3 (in 1/10000) of a Q
    RKDataStreamingMask mask =  RKDataStreamingMaskIMUAnglesFilteredAll | RKDataStreamingMaskLocatorAll;
    [_robot enableSensors:mask atStreamingRate:20];
    
    //    [_robot sendCommand:[RKSetDataStreamingCommand commandWithRate:10 andMask:mask]];
}
- (IBAction)switchStabilize:(id)sender {
    if (_stabilizeSwitch.isOn) {
        [_robot enableStabilization:YES];
        [_robot sendCommand:[RKBackLEDOutputCommand commandWithBrightness:0.0]];
    }else {
        [_robot enableStabilization:NO];
        [_robot sendCommand:[RKBackLEDOutputCommand commandWithBrightness:1.0]];
    }
}

- (void)handleAsyncMessage:(RKAsyncMessage *)message forRobot:(id<RKRobotBase>)robot {
    // Need to check which type of async data is received as this method will be called for
    // data streaming packets and sleep notification packets. We are going to ingnore the sleep
    // notifications.
    if ([message isKindOfClass:[RKDeviceSensorsAsyncData class]]) {
        
        // Received sensor data, so display it to the user.
        RKDeviceSensorsAsyncData *sensorsAsyncData = (RKDeviceSensorsAsyncData *)message;
        RKDeviceSensorsData *sensorsData = [sensorsAsyncData.dataFrames lastObject];
        RKAttitudeData *attitudeData = sensorsData.attitudeData;
        RKLocatorData *locatorData = sensorsData.locatorData;
        
        
        // Print data to the text fields
        _yawValueLabel.text = [NSString stringWithFormat:@"%.0f", attitudeData.yaw];
        _XValueLabel.text = [NSString stringWithFormat:@"%.2f", locatorData.position.x];
        _YValueLabel.text = [NSString stringWithFormat:@"%.2f", locatorData.position.y];
        _vXValueLabel.text = [NSString stringWithFormat:@"%.2f", locatorData.velocity.x];
        _vYValueLabel.text = [NSString stringWithFormat:@"%.2f", locatorData.velocity.y];
        yaw_sphero = attitudeData.yaw;
        velocity_sphero = locatorData.velocity;
    }
}

- (void)handleRobotStateChangeNotification:(RKRobotChangedStateNotification*)n {
    switch(n.type) {
        case RKRobotConnecting:
            [self handleConnecting];
            break;
        case RKRobotOnline: {
            // Do not allow the robot to connect if the application is not running
            RKConvenienceRobot *convenience = [RKConvenienceRobot convenienceWithRobot:n.robot];
            if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
                [convenience disconnect];
                return;
            }
            self.robot = convenience;
            [self handleConnected];
            break;
        }
        case RKRobotDisconnected:
            [self handleDisconnected];
            self.robot = nil;
            [RKRobotDiscoveryAgent startDiscovery];
            break;
        default:
            break;
    }
}

- (void)handleConnecting {
    // Handle robot connecting here
}

- (void)handleConnected {
    [_robot enableStabilization:YES];
    [_robot addResponseObserver:self];
    [self sendSetDataStreamingCommand];
    [_robot setLEDWithRed:0.0f green:0.5f blue:0.0f];
}

- (void)handleDisconnected {
    // Handle robot disconnected here
    [_robot removeResponseObserver:self];
}
- (IBAction)resetPressed:(id)sender {
    [_robot sendCommand:[RKSetHeadingCommand commandWithHeading:0.]];
    [_robot sendCommand:[[RKConfigureLocatorCommand alloc] initForFlag:RKConfigureLocatorRotateWithCalibrateFlagOn newX:0 newY:0 newYaw:0]];
    yaw0_iphone = yaw_iphone;
}
- (IBAction)updateThreshold:(id)sender {
    [(GPUImageLuminanceThresholdFilter *)binaryFilter setThreshold:[(UISlider *)sender value]];
    _thresholdLabel.text = [NSString stringWithFormat:@"%.02f", [(UISlider *)sender value]];
}
- (IBAction)updateR2:(id)sender {
    R2 = [(UISlider *)sender value];
    _R2Label.text = [NSString stringWithFormat:@"%.02f", R2];
    [(CircleLineSensorFilter *)filter setR2:[(UISlider *)sender value]];
    [(CircleLineSensorFilter *)filter2 setR2:[(UISlider *)sender value]];
}
- (IBAction)updateVelocity:(id)sender {
    Float32 _velocity = [(UISlider *)sender value];
    _velocityLabel.text = [NSString stringWithFormat:@"%.02f", _velocity];

    if (isStarted) {
        velocity = _velocity;
    }
}

- (IBAction)updateStartSwitch:(id)sender {
    if (isStarted) {
        isStarted = false;
        [(UIButton *)sender setTitle:@"START" forState:UIControlStateNormal];
        [(UIButton *)sender setBackgroundColor:[UIColor blueColor]];
        velocity = 0;
    }else {
        isStarted = true;
        [(UIButton *)sender setTitle:@"STOP" forState:UIControlStateNormal];
        [(UIButton *)sender setBackgroundColor:[UIColor redColor]];
        velocity = [_velocitySlider value];;
    }
}

- (IBAction)sleepRobot:(id)sender {
    [_robot sleep];
}
- (IBAction)panGesture:(id)sender {
    CGPoint location = [(UIPanGestureRecognizer*) sender translationInView:self.view];
    
    _XcenterLabel.text = [NSString stringWithFormat:@"%.02f", center.x + location.x / 184.5];
    [(CircleLineSensorFilter *)filter setXcenter:center.x + location.x / 184.5];
    [(CircleLineSensorFilter *)filter2 setXcenter:center.x + location.x / 184.5];
    _YcenterLabel.text = [NSString stringWithFormat:@"%.02f", center.y + location.y / 246.0];
    [(CircleLineSensorFilter *)filter setYcenter:center.y + location.y / 246.0];
    [(CircleLineSensorFilter *)filter2 setYcenter:center.y + location.y / 246.0];
    
    if ([(UIPanGestureRecognizer *)sender state] == UIGestureRecognizerStateEnded) {
        center.x += location.x / 184.5;
        center.y += location.y / 246.0;
    }
}
- (IBAction)pinchGesture:(id)sender {
    CGFloat scale = [(UIPinchGestureRecognizer *)sender scale];
    _R1Label.text = [NSString stringWithFormat:@"%.02f", R1*scale];
    [(CircleLineSensorFilter *)filter setR1:R1*scale];
    [(CircleLineSensorFilter *)filter2 setR1:R1*scale];
    if ([(UIPinchGestureRecognizer *)sender state] == UIGestureRecognizerStateEnded ) {
        R1 *= scale;
    }
}
- (IBAction)panGesture2:(id)sender {
    CGPoint location = [(UIPanGestureRecognizer *)sender translationInView:self.view];
    if (fabs(location.x) < 10) { //縦
        if(location.y < -10) {
            thetaLine = 0;
            NSLog(@"swipe Up");
        }else if (location.y > 10) {
            thetaLine = 180;
            NSLog(@"swipe Down");
        }
    }else if (fabs(location.y) < 10) { //横
        if (location.x < -10) {
            thetaLine = 270;
            NSLog(@"swipe Left");
        }else if (location.x > 10) {
            thetaLine = 180;
            NSLog(@"swipe Down");
        }
    }
    Float32 rollTheta_sphero = (int)(thetaLine-yaw_iphone+yaw0_iphone +360)%360;
    [_robot sendCommand:[RKRollCommand commandWithHeading:rollTheta_sphero andVelocity:velocity]];
}

@end
