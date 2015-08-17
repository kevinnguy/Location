//
//  LocationAppDelegate.m
//  Location
//
//  Created by Rick
//  Copyright (c) 2014 Location. All rights reserved.
//

#import "LocationAppDelegate.h"

#import "KCNLocationManager.h"

@import Firebase;


@interface LocationAppDelegate ()

@property (nonatomic, strong) NSTimer *locationUpdateTimer;
@property (nonatomic, strong) Firebase *firebase;

@end

@implementation LocationAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIAlertView * alert;
    
    //We have to make sure that the Background App Refresh is enable for the Location updates to work in the background.
    if([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusDenied){
        
        alert = [[UIAlertView alloc]initWithTitle:@""
                                          message:@"The app doesn't work without the Background App Refresh enabled. To turn it on, go to Settings > General > Background App Refresh"
                                         delegate:nil
                                cancelButtonTitle:@"Ok"
                                otherButtonTitles:nil, nil];
        [alert show];
        
    }else if([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusRestricted){
        
        alert = [[UIAlertView alloc]initWithTitle:@""
                                          message:@"The functions of this app are limited because the Background App Refresh is disable."
                                         delegate:nil
                                cancelButtonTitle:@"Ok"
                                otherButtonTitles:nil, nil];
        [alert show];
        
    } else{
        [[KCNLocationManager sharedManager] startLocationTracking];
        
        //Send the best location to server every 60 seconds
        //You may adjust the time interval depends on the need of your app.

        self.locationUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60.0f
                                                                    target:self
                                                                  selector:@selector(postLocation)
                                                                  userInfo:nil
                                                                   repeats:YES];
    }
    
    return YES;
}

-(void)postLocation {
    [[KCNLocationManager sharedManager] uploadCurrentLocation:^(CLLocation *location) {
        NSDictionary *json = @{@"lat" : [NSString stringWithFormat:@"%f", location.coordinate.latitude],
                               @"long" : [NSString stringWithFormat:@"%f", location.coordinate.longitude]};
        
        Firebase *timestamp = [self.firebase childByAppendingPath:[NSDate date].description];
        [timestamp setValue:json];
    }];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
