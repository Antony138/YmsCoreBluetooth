// 
// Copyright 2013-2015 Yummy Melon Software LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Author: Charles Y. Choi <charles.choi@yummymelon.com>
//

#import "YMSCBCentralManager.h"
#import "YMSCBPeripheral.h"
#import "YMSCBService.h"
#import "YMSCBCharacteristic.h"
#import "YMSCBStoredPeripherals.h"


NSString *const YMSCBVersion = @"" kYMSCBVersion;

@interface YMSCBCentralManager ()
{
    // >> 声明为变量和声明为属性有什么区别? 什么时候声明为「变量」，什么时候声明为「属性」。
    // >> 属性会自动生成get/set方法，并会生成带下划线的变量。那是否意味着：在这里声明「变量」，单纯的就是变量，没有get/set方法？
    NSMutableArray *_ymsPeripherals;
}

// >> 这里又声明一个同名的属性，什么情况？？
@property (atomic, strong) NSMutableArray *ymsPeripherals;

@end


@implementation YMSCBCentralManager

// >> 返回这个框架的版本？（又弄宏定义，又弄const，搞得那么复杂，就是为了返回一个「1.090」）
- (NSString *)version {
    return YMSCBVersion;
}


#pragma mark - Constructors

- (instancetype)initWithKnownPeripheralNames:(NSArray *)nameList queue:(dispatch_queue_t)queue delegate:(id<CBCentralManagerDelegate>) delegate; {
    self = [super init];
    
    if (self) {
        _ymsPeripherals = [NSMutableArray new];
        _delegate = delegate;
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
        _knownPeripheralNames = nameList;
        _discoveredCallback = nil;
        _retrievedCallback = nil;
        _useStoredPeripherals = NO;
    }
    
    return self;
}

- (instancetype)initWithKnownPeripheralNames:(NSArray *)nameList queue:(dispatch_queue_t)queue useStoredPeripherals:(BOOL)useStore delegate:(id<CBCentralManagerDelegate>)delegate {

    self = [super init];
    
    if (self) {
        _ymsPeripherals = [NSMutableArray new];
        _delegate = delegate;
        // >> 这里用到的就是官方框架了
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
        _knownPeripheralNames = nameList;
        _discoveredCallback = nil;
        _retrievedCallback = nil;
        _useStoredPeripherals = useStore;
    }
    
    // >> 如果需要存储，初始化一个保存的地方(利用NSUserDefaults)
    if (useStore) {
        [YMSCBStoredPeripherals initializeStorage];
    }
    
    return self;
}

#pragma mark - Peripheral Management

- (NSUInteger)count {
    // >> 这些方法有必要再写一个方法？用意是何？直接返回_ymsPeripherals.count不也很直观吗？
    // >> 难道下面有些方法太复杂，统一再写到其他方法，会更统一？
    return  [self countOfYmsPeripherals];
}

- (YMSCBPeripheral *)peripheralAtIndex:(NSUInteger)index {
    return [self objectInYmsPeripheralsAtIndex:index];
}

- (void)addPeripheral:(YMSCBPeripheral *)yperipheral {
    // >> 这里没有直接用数组的addObject:方法，而是用insertObject:atIndex:，直接插到最后
    [self insertObject:yperipheral inYmsPeripheralsAtIndex:self.countOfYmsPeripherals];
}

- (void)removePeripheral:(YMSCBPeripheral *)yperipheral {
    // >> 这个方法和下面的方法，就统一用了removeObjectFromYmsPeripheralsAtIndex:方法，减少了代码
    [self removeObjectFromYmsPeripheralsAtIndex:[self.ymsPeripherals indexOfObject:yperipheral]];
}

- (void)removePeripheralAtIndex:(NSUInteger)index {
    [self removeObjectFromYmsPeripheralsAtIndex:index];
}

- (void)removeAllPeripherals {
    // >> 删除所有硬件对象，用的是一个while循环, 和removePeripheral:、removePeripheralAtIndex:方法调用的是同一个方法进行删除
    while ([self countOfYmsPeripherals] > 0) {
        [self removePeripheralAtIndex:0];
    }
}

// >> 下面4个都是Helper methods
- (NSUInteger)countOfYmsPeripherals {
    return _ymsPeripherals.count;
}

- (id)objectInYmsPeripheralsAtIndex:(NSUInteger)index {
    return [_ymsPeripherals objectAtIndex:index];
}

- (void)insertObject:(YMSCBPeripheral *)object inYmsPeripheralsAtIndex:(NSUInteger)index {
    [_ymsPeripherals insertObject:object atIndex:index];
}

- (void)removeObjectFromYmsPeripheralsAtIndex:(NSUInteger)index {
    if (self.useStoredPeripherals) {
        YMSCBPeripheral *yperipheral = [self.ymsPeripherals objectAtIndex:index];
        if (yperipheral.cbPeripheral.identifier != nil) {
            // >> 删除保存在沙盒中的数据?
            [YMSCBStoredPeripherals deleteUUID:yperipheral.cbPeripheral.identifier];
        }
    }
    // >> 删除硬件对象
    [_ymsPeripherals removeObjectAtIndex:index];
}



- (BOOL)isKnownPeripheral:(CBPeripheral *)peripheral {
    BOOL result = NO;
    
    for (NSString *key in self.knownPeripheralNames) {
        result = result || [peripheral.name isEqualToString:key];
        if (result) {
            break;
        }
    }
    
    return result;
}

#pragma mark - Scan Methods

- (void)startScan {
    // >> 这个方法需要被重写，是什么意思呢？
    /*
     * THIS METHOD IS TO BE OVERRIDDEN
     */
    
    NSAssert(NO, @"[YMSCBCentralManager startScan] must be be overridden and include call to [self scanForPeripherals:options:]");
    
    //[self scanForPeripheralsWithServices:nil options:nil];
}

// >> 根据UUID进行扫描的实现方法（这里就是直接调用官方的方法了）
- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs options:(NSDictionary *)options {
    [self.manager scanForPeripheralsWithServices:serviceUUIDs options:options];
    self.isScanning = YES;
}

// >> 根据UUID进行扫描的实现方法，并有扫描到设备的回调(回调的是硬件对象、广播信息, RSSI值)
- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs options:(NSDictionary *)options withBlock:(void (^)(CBPeripheral *, NSDictionary *, NSNumber *, NSError *))discoverCallback {
    
    // >> 赋值(之前用CoreData，想用Block拿到数据后再回调，但是不回调，是不是因为没有写这个？)
    self.discoveredCallback = discoverCallback;
    
    // >> 调用的是上面的方法
    [self scanForPeripheralsWithServices:serviceUUIDs options:options];
}


- (void)stopScan {
    [self.manager stopScan];
    self.isScanning = NO;
}


- (YMSCBPeripheral *)findPeripheral:(CBPeripheral *)peripheral {
    
    YMSCBPeripheral *result = nil;
    NSArray *peripheralsCopy = [NSArray arrayWithArray:self.ymsPeripherals];
    
    for (YMSCBPeripheral *yPeripheral in peripheralsCopy) {
        if (yPeripheral.cbPeripheral == peripheral) {
            result = yPeripheral;
            break;
        }
    }
    
    return result;
}



- (void)handleFoundPeripheral:(CBPeripheral *)peripheral {
    /*
     * THIS METHOD IS TO BE OVERRIDDEN
     */
    
    NSAssert(NO, @"[YMSCBCentralManager handleFoundPeripheral:] must be be overridden.");

}


#pragma mark - Retrieve Methods

- (NSArray *)retrieveConnectedPeripheralsWithServices:(NSArray *)serviceUUIDs {
    NSArray *result = [self.manager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
    return result;
}

- (NSArray *)retrievePeripheralsWithIdentifiers:(NSArray *)identifiers {
    NSArray *result = [self.manager retrievePeripheralsWithIdentifiers:identifiers];
    return result;
}


#pragma mark - CBCentralManger state handler methods.

- (void)managerPoweredOnHandler {
    // THIS METHOD IS TO BE OVERRIDDEN
}

- (void)managerUnknownHandler {
    // THIS METHOD IS TO BE OVERRIDDEN
}

- (void)managerPoweredOffHandler {
    // THIS METHOD IS TO BE OVERRIDDEN
}

- (void)managerResettingHandler {
    // CALL SUPER METHOD
    // THIS METHOD MUST BE INVOKED BY SUBCLASSES THAT OVERRIDE THIS METHOD
    [_ymsPeripherals removeAllObjects];
}

- (void)managerUnauthorizedHandler {
    // THIS METHOD IS TO BE OVERRIDDEN
}

- (void)managerUnsupportedHandler {
    // THIS METHOD IS TO BE OVERRIDDEN
}

#pragma mark - CBCentralManagerDelegate Protocol Methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    __weak YMSCBCentralManager *this = self;
    
    // >> _YMS_PERFORM_ON_MAIN_THREAD是一个关于GCD的宏，表示将操作放到主线程中执行（难道原来不是在主线程吗？）
    _YMS_PERFORM_ON_MAIN_THREAD(^{
        switch (central.state) {
            case CBCentralManagerStatePoweredOn:
                // 这样执行方法，有什么用？相当于一种回调吗？
                [this managerPoweredOnHandler];
                break;
                
            case CBCentralManagerStateUnknown:
                [this managerUnknownHandler];
                break;
                
            case CBCentralManagerStatePoweredOff:
                [this managerPoweredOffHandler];
                break;
                
            case CBCentralManagerStateResetting:
                [this managerResettingHandler];
                break;
                
            case CBCentralManagerStateUnauthorized:
                [this managerUnauthorizedHandler];
                break;
                
            case CBCentralManagerStateUnsupported: {
                [this managerUnsupportedHandler];
                break;
            }
        }

        // 回调？
        if ([this.delegate respondsToSelector:@selector(centralManagerDidUpdateState:)]) {
            [this.delegate centralManagerDidUpdateState:central];

        }
    });
}


// >> 发现设备的回调
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    __weak YMSCBCentralManager *this = self;
    _YMS_PERFORM_ON_MAIN_THREAD(^{
        if (this.useStoredPeripherals) {
            if (peripheral.identifier) {
                // >> 如果是要保存到沙盒的，就利用NSUserDefaults保存
                [YMSCBStoredPeripherals saveUUID:peripheral.identifier];
            }
        }
        
        // 将advertisementData这些信息回调出去
        if (this.discoveredCallback) {
            this.discoveredCallback(peripheral, advertisementData, RSSI, nil);
        } else {
            // >> 如果没有Block还可以进一步处理？这个处理有什么用？
            [this handleFoundPeripheral:peripheral];
        }
        
        // >> 代理的回调方法
        if ([this.delegate respondsToSelector:@selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)]) {
            // >> 因为YMSCBCentralManager遵守了CBCentralManagerDelegate协议，所以这里可以回调数据出去
            [this.delegate centralManager:central
                    didDiscoverPeripheral:peripheral
                        advertisementData:advertisementData
                                     RSSI:RSSI];
        }
    });
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    __weak YMSCBCentralManager *this = self;
    _YMS_PERFORM_ON_MAIN_THREAD(^{
        YMSCBPeripheral *yp = [this findPeripheral:peripheral];
        
        [yp handleConnectionResponse:nil];
        
        if ([this.delegate respondsToSelector:@selector(centralManager:didConnectPeripheral:)]) {
            [this.delegate centralManager:central didConnectPeripheral:peripheral];
        }
    });
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    __weak YMSCBCentralManager *this = self;
    _YMS_PERFORM_ON_MAIN_THREAD(^{
        YMSCBPeripheral *yp = [this findPeripheral:peripheral];
        
        for (id key in yp.serviceDict) {
            YMSCBService *service = yp.serviceDict[key];
            service.cbService = nil;
            service.isOn = NO;
            service.isEnabled = NO;
        }
        
        if ([this.delegate respondsToSelector:@selector(centralManager:didDisconnectPeripheral:error:)]) {
            [this.delegate centralManager:central didDisconnectPeripheral:peripheral error:error];
        }
    });
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    __weak YMSCBCentralManager *this = self;
    _YMS_PERFORM_ON_MAIN_THREAD(^{
        YMSCBPeripheral *yp = [this findPeripheral:peripheral];
        [yp handleConnectionResponse:error];
        if ([this.delegate respondsToSelector:@selector(centralManager:didFailToConnectPeripheral:error:)]) {
            [this.delegate centralManager:central didFailToConnectPeripheral:peripheral error:error];
        }
    });
}

@end
