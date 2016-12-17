//
//  BNRItemStore.m
//  HomePwner
//
//  Created by John Gallagher on 1/7/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

// 斯坦福大学的教学视频中，用到了NSFetchedResultsController类，而这个项目没有用到。

#import "BNRItemStore.h"
#import "BNRItem.h"
#import "BNRImageStore.h"

@import CoreData;

@interface BNRItemStore ()

@property (nonatomic) NSMutableArray *privateItems;

@property (nonatomic, strong) NSMutableArray *allAssetTypes;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSManagedObjectModel *model;

@end

@implementation BNRItemStore

+ (instancetype)sharedStore
{
    static BNRItemStore *sharedStore;

    // Do I need to create a sharedStore?
    if (!sharedStore) {
        sharedStore = [[self alloc] initPrivate];
    }

    return sharedStore;
}

// If a programmer calls [[BNRItemStore alloc] init], let him
// know the error of his ways
- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[BNRItemStore sharedStore]"
                                 userInfo:nil];
    return nil;
}

// Here is the real (secret) initializer
- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        // 读取Homepwner.xcdatamodeld
        // NSManagedObjectModel的实例化方法有很多种
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        // 设置SQLite文件路径
        NSString *path = [self itemArchivePath];
        NSURL *storeURL = [NSURL fileURLWithPath:path];
        
        NSError *error = nil;
        
        if (![psc addPersistentStoreWithType:NSSQLiteStoreType
                               configuration:nil
                                         URL:storeURL
                                     options:nil
                                       error:&error]) {
            @throw [NSException exceptionWithName:@"OpenFailure"
                                           reason:[error localizedDescription]
                                         userInfo:nil];
        }
        
        // 创建NSManagedObjectContext对象
        // NSPrivateQueueConcurrencyType: Core Data中的多线程处理
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
//        _context = [[NSManagedObjectContext alloc] init];
        _context.persistentStoreCoordinator = psc;
        
        
        [self loadAllItems];
    }
    return self;
}

- (NSString *)itemArchivePath
{
    // Make sure that the first argument is NSDocumentDirectory
    // and not NSDocumentationDirectory
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    // Get the one document directory from that list
    NSString *documentDirectory = [documentDirectories firstObject];

    return [documentDirectory stringByAppendingPathComponent:@"store.data"];
}

#pragma mark 保存数据
- (BOOL)saveChanges
{
   __block BOOL successful = NO;
    
    #pragma mark 步骤:利用contex的save:方法保存数据
    // performBlock:异步执行？
    // CoreData的多线程：在后台执行保存操作，提高效率？
    [self.context performBlock:^{
    
        NSError *error;
        // 利用contex对象保存数据
        successful = [self.context save:&error];
        if (!successful) {
            NSLog(@"Error saving: %@", [error localizedDescription]);
        }
    }];
    
    [self printDatabaseStatistics];
    NSLog(@"数量已经打印完成");
    
    return successful;
}

// 获取对象数量
- (void)printDatabaseStatistics {
    // 从database中获取数量，也放到非主线程中
    [self.context performBlock:^{
        NSUInteger itemCount = [self.context countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"BNRItem"]
                                                            error:nil];
        
        NSLog(@"总共有%@的BNRItem对象", @(itemCount));
        
        NSUInteger typeCount = [self.context countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"BNRAssetType"] error:nil];
        NSLog(@"总共有%@种Type", @(typeCount));
    }];
}

#pragma mark 载入数据
- (void)loadAllItems {
    if (!self.privateItems) {
        
        // 载入数据-步骤1:先创建NSFetchRequest对象，表示要取回什么数据(可用NSSortDescriptor、NSPredicate排序、过滤数据)
        
        #pragma mark CoreData步骤:取回数据步骤1:创建NSFetchRequest对象，表明要取回什么数据(可用NSSortDescriptor、NSPredicate排序、过滤数据)
        
        // 可以直接传入EntityName创建NSFetchRequest对象吧?(这样就少一步了)
//        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"BNRItem"];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *e = [NSEntityDescription entityForName:@"BNRItem"
                                             inManagedObjectContext:self.context];
        request.entity = e;
        
        // 定义拿回数据的排序
        // 另外，还可以用NSPredicate获取(过滤出)指定的数据
        NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"orderingValue"
                                                             ascending:YES];
        
        request.sortDescriptors = @[sd];
        
        NSError *error;
        
        #pragma mark CoreData步骤:取回数据步骤2:利用NSManagedObjectContext的fetch方法
        // 载入数据-步骤2:执行contex的executeFetchRequest:方法(传入前面创建的NSFetchRequest对象)
        // 主要，返回对象类型是NSArry
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        
        if (!result) {
            [NSException raise:@"Fetch failed"
                        format:@"Reason: %@", [error localizedDescription]];
        }
        
        // 赋值给自定义array
        self.privateItems = [[NSMutableArray alloc] initWithArray:result];
    }
}

- (NSArray *)allItems
{
    return [self.privateItems copy];
}

#pragma mark 增加一条数据
- (BNRItem *)createItem
{
    // 通过context对象插入一个针对BNRItem对象
    
    double order;
    if ([self.allItems count] == 0) {
        order = 1.0;
    }
    else {
        order = [[self.privateItems lastObject] orderingValue] + 1.0;
    }
    NSLog(@"Adding after %@ items, order = %.2f", @(self.privateItems.count), order);
    
#pragma mark CoreData步骤:插入数据:利用NSEntityDescription的insertNewObject
    BNRItem *item = [NSEntityDescription insertNewObjectForEntityForName:@"BNRItem"
                                                  inManagedObjectContext:self.context];
    item.orderingValue = order;
    
    [self.privateItems addObject:item];

    return item;
}

#pragma mark 删除一条数据
- (void)removeItem:(BNRItem *)item
{
    NSString *key = item.itemKey;
    if (key) {
        [[BNRImageStore sharedStore] deleteImageForKey:key];
    }
    [self.context deleteObject:item];
    [self.privateItems removeObjectIdenticalTo:item];
}

#pragma mark 排序功能
- (void)moveItemAtIndex:(NSInteger)fromIndex
                toIndex:(NSInteger)toIndex
{
    if (fromIndex == toIndex) {
        return;
    }
    // Get pointer to object being moved so you can re-insert it
    BNRItem *item = self.privateItems[fromIndex];

    // Remove item from array
    [self.privateItems removeObjectAtIndex:fromIndex];

    // Insert item in array at new location
    [self.privateItems insertObject:item atIndex:toIndex];
    
    double lowerBound = 0.0;
    
    if (toIndex > 0) {
        lowerBound = [self.privateItems[(toIndex - 1)] orderingValue];
    }
    else {
        lowerBound = [self.privateItems[1] orderingValue] - 2.0;
    }
    
    double upperBound = 0.0;
    
    if (toIndex < [self.privateItems count] - 1) {
        upperBound = [self.privateItems[(toIndex + 1)] orderingValue];
    }
    else {
        upperBound = [self.privateItems[(toIndex - 1)] orderingValue] + 2.0;
    }
    
    double newOrderValue = (lowerBound + upperBound) / 2.0;
    
    NSLog(@"moving to order %f", newOrderValue);
    item.orderingValue = newOrderValue;
}

#pragma mark - 默认创建三种类型
- (NSArray *)allAssetTypes {
    if (!_allAssetTypes) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *e = [NSEntityDescription entityForName:@"BNRAssetType"
                                             inManagedObjectContext:self.context];
        request.entity = e;
        
        NSError *error = nil;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        
        if (!result) {
            [NSException raise:@"Fetch failed" format:@"Reason: %@", [error localizedDescription]];
        }
        _allAssetTypes = [result mutableCopy];
    }
    
    // 是否第一次运行
    if (_allAssetTypes.count == 0) {
        NSManagedObject *type;
        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Furniture" forKey:@"label"];
        [_allAssetTypes addObject:type];
        
        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Jewelry" forKey:@"label"];
        [_allAssetTypes addObject:type];
        
        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Electronics" forKey:@"label"];
        [_allAssetTypes addObject:type];
    }
    return _allAssetTypes;
}


@end
