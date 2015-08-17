//
//  LocationManager.h
//  Location
//
//  Created by Kevin Nguy on 8/17/15.
//  Copyright (c) 2015 Location. All rights reserved.
//

#import <Foundation/Foundation.h>

@import CoreLocation.CLLocation;

@interface LocationManager : NSObject

+ (instancetype)sharedManager;

- (void)startLocationTracking;
- (void)uploadCurrentLocation:(void (^)(CLLocation *location))uploadBlock;

@end
