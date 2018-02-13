//
//  AppDelegate.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/1/29.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "AppDelegate.h"
#import "CJMethodLog.h"
#import "BigBang.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    /*
     * 方案一：利用消息转发，hook指定类的调用方法
     */
    [CJMethodLog forwardingClassMethod:@[
<<<<<<< HEAD
//                                         @"ViewController",
                                         @"TestViewController",
//                                         @"TestTableViewController"
=======
                                         @"ViewController",
                                         @"TestViewController",
                                         @"TestTableViewController"
>>>>>>> origin/master
                                         ]];
    /*
     * 方案二：hook指定类的每一个方法
     */
//    [CJMethodLog hookClassMethod:@[
<<<<<<< HEAD
//                                   @"ViewController",
//                                   @"TestViewController",
//                                   @"TestTableViewController"
//                                   ]];
    
//    [BigBang hookClass:@"ViewController"];
//    [BigBang hookClass:@"TestViewController"];
=======
//                                   @"TestViewController",
//                                   @"TestTableViewController"
//                                   ]];
>>>>>>> origin/master
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
