//
//  LocationManager.m
//  Location
//
//  Created by Kevin Nguy on 8/17/15.
//  Copyright (c) 2015 Location. All rights reserved.
//

#import "KCNLocationManager.h"

@import CoreLocation;

@interface KCNLocationManager () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) NSMutableArray *locationArray;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) CLLocation *currentLocation;

@property (nonatomic, strong) NSTimer *restartLocationUpdateTimer;
@property (nonatomic, strong) NSTimer *uploadLocationTimer;
//@property (nonatomic, strong) NSTimer *delayTimer;

@property (nonatomic, strong) NSMutableArray *backgroundTaskArray;
@property (nonatomic) UIBackgroundTaskIdentifier masterTask;


@end

NSTimeInterval const kLocationManagerTimerInterval = 60.0f;

@implementation KCNLocationManager

+ (instancetype)sharedManager {
    static KCNLocationManager *sharedManager;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedManager = [self new];
    });
    
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.locationManager = [CLLocationManager new];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.delegate = self;
    
    self.locationArray = [NSMutableArray new];
    
    self.backgroundTaskArray = [NSMutableArray new];
    self.masterTask = UIBackgroundTaskInvalid;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    self.uploadLocationTimer = [NSTimer scheduledTimerWithTimeInterval:kLocationManagerTimerInterval
                                                                target:self
                                                              selector:@selector(uploadLocationTimer)
                                                              userInfo:nil
                                                               repeats:YES];

    return self;
}

#pragma mark - Post update to server
- (void)uploadCurrentLocation:(void (^)(CLLocation *))uploadBlock {
    // Find the best location from the array based on accuracy
    CLLocation *bestLocation = self.locationArray.firstObject;
    for (NSInteger i = 1; i < self.locationArray.count; i++){
        CLLocation *location = [self.locationArray objectAtIndex:i];
        if(location.horizontalAccuracy <= bestLocation.horizontalAccuracy){
            bestLocation = location;
        }
    }
    
    if (self.locationArray.count == 0) {
        // Sometimes due to network issue or unknown reason, you could not get the location during that period
        // The best you can do is sending the last known location to the server
        NSLog(@"Unable to get location, use the last known location");
        self.currentLocation = self.lastLocation;
    } else {
        self.currentLocation = bestLocation;
    }
    
    // Post location to server
    NSLog(@"Best current location: %@", self.currentLocation.description);
    uploadBlock(self.currentLocation);
        
    // Clear unused locations
    [self.locationArray removeAllObjects];
}

#pragma mark - Notifications
- (void)applicationDidEnterBackground {
    [self updateLocation];
    [self beginNewBackgroundTask];
}

#pragma mark - Location updated
- (void)startLocationTracking {
    UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled" message:@"You currently have all location services for this device disabled" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
    if (![CLLocationManager locationServicesEnabled]) {
        NSLog(@"locationServicesEnabled false");
        [servicesDisabledAlert show];
        return;
    }
    
    if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied ||
       [CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        NSLog(@"authorizationStatus failed");
        [servicesDisabledAlert show];
        return;
    }
    
    NSLog(@"authorizationStatus authorized");
    [self updateLocation];
}

- (void)restartLocationUpdates {
    NSLog(@"restartLocationUpdates");
    
    if (self.restartLocationUpdateTimer) {
        [self.restartLocationUpdateTimer invalidate];
        self.restartLocationUpdateTimer = nil;
    }
    
    [self updateLocation];
}

//- (void)stopLocationTracking {
//    NSLog(@"stopLocationTracking");
//    
//    if (self.timer) {
//        [self.timer invalidate];
//        self.timer = nil;
//    }
//    
//    [self.locationManager stopUpdatingLocation];
//}

- (void)updateLocation {
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
    }
    
    [self.locationManager startUpdatingLocation];
}

#pragma mark - Background tasks
- (UIBackgroundTaskIdentifier)beginNewBackgroundTask {
    UIApplication* application = [UIApplication sharedApplication];
    
    UIBackgroundTaskIdentifier backgroundTask = UIBackgroundTaskInvalid;
    if (![application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
        return UIBackgroundTaskInvalid;
    }
    
    backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"background task %lu expired", (unsigned long)backgroundTask);
    }];
    
    if (self.masterTask == UIBackgroundTaskInvalid) {
        self.masterTask = backgroundTask;
        NSLog(@"started master task %lu", (unsigned long)self.masterTask);
    } else {
        NSLog(@"started background task %lu", (unsigned long)backgroundTask);
        [self.backgroundTaskArray addObject:@(backgroundTask)];
        [self endBackgroundTasks];
    }
    
    return backgroundTask;
}

- (void)endBackgroundTasks {
    UIApplication* application = [UIApplication sharedApplication];
    if(![application respondsToSelector:@selector(endBackgroundTask:)]){
        return;
    }

    NSInteger count = self.backgroundTaskArray.count;
    for (NSInteger i = 1; i < count; i++) {
        UIBackgroundTaskIdentifier bgTaskId = [self.backgroundTaskArray.firstObject integerValue];
        NSLog(@"ending background task with id -%lu", (unsigned long)bgTaskId);
        [application endBackgroundTask:bgTaskId];
        [self.backgroundTaskArray removeObjectAtIndex:0];
    }
    
    NSLog(@"kept background task id %@", self.backgroundTaskArray.firstObject);
}

#pragma mark - CLLocationManagerDelegate Methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    NSLog(@"locationManager didUpdateLocations");
    
    for (CLLocation *location in locations) {
        NSTimeInterval locationAge = -[location.timestamp timeIntervalSinceNow];
        if (locationAge > 30.0) {
            continue;
        }
        
        // Select location with good accuracy
        if (location &&
            location.horizontalAccuracy > 0 &&
            location.horizontalAccuracy < 2000 &&
            location.coordinate.latitude != 0.0 &&
            location.coordinate.longitude != 0.0){
            
            self.lastLocation = location;
            [self.locationArray addObject:location];
        }
    }
    
    // If the timer still valid, return it (Will not run the code below)
    if (self.restartLocationUpdateTimer) {
        return;
    }
    
    [self beginNewBackgroundTask];
    
    // Restart the location maanger after 1 minute
    self.restartLocationUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:kLocationManagerTimerInterval
                                                  target:self
                                                selector:@selector(restartLocationUpdates)
                                                userInfo:nil
                                                 repeats:NO];
    
    //Will only stop the locationManager after 10 seconds, so that we can get some accurate locations
    //The location manager will only operate for 10 seconds to save battery
//    if (self.delayTimer) {
//        [self.delayTimer invalidate];
//        self.delayTimer = nil;
//    }
//    
//    self.delayTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self
//                                                     selector:@selector(stopUpdatingLocationDelay)
//                                                     userInfo:nil
//                                                      repeats:NO];
}

// Stop the locationManager
//- (void)stopUpdatingLocationDelay {
//    [self.locationManager stopUpdatingLocation];
//}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"locationManager error:%@", error.description);
    switch (error.code) {
        case kCLErrorNetwork: {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error" message:@"Please check your network connection." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
            break;
        }
    
        case kCLErrorDenied:{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enable Location Service" message:@"You have to enable the Location Service to use this App. To enable, please go to Settings->Privacy->Location Services" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
            break;
        }
            
        default: {
            break;
        }
    }
}

@end





























