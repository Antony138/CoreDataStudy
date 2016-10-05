//
//  BNRImageTransformer.m
//  HomePwner
//
//  Created by SPK_Antony on 2016/10/5.
//  Copyright © 2016年 Big Nerd Ranch. All rights reserved.
//

#import "BNRImageTransformer.h"

// Core Data利用BNRIMageTransformer来处理thumbnail(UIImage对象)
// 难道每个transformable类型都要写一个这个类？

@implementation BNRImageTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

// 将UIImage对象转换为Core Data可以储存的对象
- (id)transformedValue:(id)value {
    if (!value) {
        return nil;
    }

    if ([value isKindOfClass:[NSData class]]) {
        return value;
    }
    
    return UIImagePNGRepresentation(value);
}

// 恢复UIImage对象
- (id)reverseTransformedValue:(id)value {
    return [UIImage imageWithData:value];
}

@end
