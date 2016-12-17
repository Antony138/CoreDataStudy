//
//  BNRItem.h
//  HomePwner
//
//  Created by SPK_Antony on 2016/10/5.
//  Copyright © 2016年 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface BNRItem : NSManagedObject

@property (nonatomic, strong) NSDate *dateCreated;
@property (nonatomic, strong) NSString *itemKey;
@property (nonatomic, strong) NSString *itemName;
@property (nonatomic) double orderingValue;
@property (nonatomic, strong) NSString *serialNumber;
@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, strong) NSData *thumbnailData;
@property (nonatomic) int valueInDollars;
// 不是自定义对象，就无需要实作为NSManagedObject的子类，直接是NSManagedObject类型就可以了
@property (nonatomic, strong) NSManagedObject *assetType;

- (void)setThumbnailFromImage:(UIImage *)image;

@end
