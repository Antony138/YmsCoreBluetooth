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

#import <Foundation/Foundation.h>

// >> #if是条件编译，满足条件才参与编译
// >> 这里的意思是:如果是iOS系统，就导入CoreBluetooth框架，否则如果是Mac系统，就导入IOBluetooth框架
#if TARGET_OS_IPHONE
#import <CoreBluetooth/CoreBluetooth.h>
#elif TARGET_OS_MAC
#import <IOBluetooth/IOBluetooth.h>
#endif

#import "YMSCBUtils.h"

// iOS7
#define kYMSCBVersionNumber 1090
#define kYMSCBVersion "1.090"
extern NSString *const YMSCBVersion;

@class YMSCBPeripheral;
@class YMSCBCentralManager;

// >> 用typedef给Block起别名
typedef void (^YMSCBDiscoverCallbackBlockType)(CBPeripheral *, NSDictionary *, NSNumber *, NSError *);
typedef void (^YMSCBRetrieveCallbackBlockType)(CBPeripheral *);

// >> 这个框架是基于Block回调的框架(官方框架是基于「代理」进行回调的)
/**
 Base class for defining a Bluetooth LE central.
 
 YMSCBCentralManager holds an instance of CBCentralManager (manager) and implements the
 CBCentralManagerDelgate messages sent by manager.
 
 This class provides ObjectiveC block-based callback support for peripheral
 scanning and retrieval.
 
 YMSCBCentralManager is intended to be subclassed: the subclass would in turn be written to 
 handle the set of BLE peripherals of interest to the application.
 
 The subclass is typically implemented (though not necessarily) as a singleton, so that there 
 is only one instance of CBCentralManager that is used by the application.

 All discovered BLE peripherals are stored in the array ymsPeripherals.

 Legacy Note: This class was previously named YMSCBAppService.
 */
@interface YMSCBCentralManager : NSObject <CBCentralManagerDelegate>

// >> 被委托的对象将收到从这里发出的信息
/** @name Properties */
/**
 Pointer to delegate.
 
 The delegate object will be sent CBCentralManagerDelegate messages received by manager.
 */
@property (nonatomic, weak) id<CBCentralManagerDelegate> delegate;

// >> CBCentralManager单例
/**
 The CBCentralManager object.
 
 In typical practice, there is only one instance of CBCentralManager and it is located in a singleton instance of YMSCBCentralManager.
 This class listens to CBCentralManagerDelegate messages sent by manager, which in turn forwards those messages to delegate.
 */
@property (atomic, strong) CBCentralManager *manager;

/**
 Array of NSStrings to search to match CBPeripheral instances.
 
 Used in conjunction with isKnownPeripheral:.  
 This value is typically initialized using initWithKnownPeripheralNames:queue:.
 */
@property (atomic, strong) NSArray *knownPeripheralNames;

// >> 用于判断manager是否在扫描中
/// Flag to determine if manager is scanning.
@property (atomic, assign) BOOL isScanning;

// >> 保存发现和重新找回的硬件(外围设备)
/**
 Array of YMSCBPeripheral instances.
 
 This array holds all YMSCBPeripheral instances discovered or retrieved by manager.
 */
@property (atomic, readonly, strong) NSArray *ymsPeripherals;

// >> 找到的硬件数量
/// Count of ymsPeripherals.
@property (atomic, readonly, assign) NSUInteger count;

/// API version.
@property (atomic, readonly, assign) NSString *version;

// >> 发现硬件的回调
/// Peripheral Discovered Callback
@property (atomic, copy) YMSCBDiscoverCallbackBlockType discoveredCallback;

// >> 重新找回硬件的回调
/// Peripheral Retreived Callback
@property (atomic, copy) YMSCBRetrieveCallbackBlockType retrievedCallback;

// >> 是否要将硬件保存到沙盒？（保存起来有什么用？）
/// If YES, then discovered peripheral UUIDs are stored in standardUserDefaults.
@property (atomic, assign) BOOL useStoredPeripherals;

#pragma mark - Constructors
/** @name Initializing YMSCBCentralManager */
/**
 Constructor with array of known peripheral names.
 
 By default, this constructor will not use stored peripherals from standardUserDefaults.
 
 @param nameList Array of peripheral names of type NSString.
 @param queue The dispatch queue to use to dispatch the central role events. 
 If its value is nil, the central manager dispatches central role events using the main queue.
 @param delegate Delegate of this class instance.
 */
- (instancetype)initWithKnownPeripheralNames:(NSArray *)nameList queue:(dispatch_queue_t)queue delegate:(id<CBCentralManagerDelegate>) delegate;

/**
 Constructor with array of known peripheral names.
 @param nameList Array of peripheral names of type NSString.
 @param queue The dispatch queue to use to dispatch the central role events.
 If its value is nil, the central manager dispatches central role events using the main queue.
 @param useStore If YES, then discovered peripheral UUIDs are stored in standardUserDefaults.
 @param delegate Delegate of this class instance.
 */
- (instancetype)initWithKnownPeripheralNames:(NSArray *)nameList queue:(dispatch_queue_t)queue useStoredPeripherals:(BOOL)useStore delegate:(id<CBCentralManagerDelegate>) delegate;

#pragma mark - Peripheral Management
// >> 判断是不是我们的硬件？
/** @name Peripheral Management */
/**
 Determines if peripheral is known by this app service.

 Used in conjunction with knownPeripheralNames. 
 
 @param peripheral found or retrieved peripheral
 @return YES is peripheral is to be managed by this app service.
 */

- (BOOL)isKnownPeripheral:(CBPeripheral *)peripheral;


/**
 Handler for discovered or found peripheral. This method is to be overridden.

 @param peripheral CoreBluetooth peripheral instance
 */
- (void)handleFoundPeripheral:(CBPeripheral *)peripheral;

// >> 根据索引返回硬件对象
/**
 Returns the YSMCBPeripheral instance from ymsPeripherals at index.
 @param index An index within the bounds of ymsPeripherals.
 */
- (YMSCBPeripheral *)peripheralAtIndex:(NSUInteger)index;

// >> 往ymsPeripherals数组增加一个硬件对象
/**
 Add YMSCBPeripheral instance to ymsPeripherals.
 @param yperipheral Instance of YMSCBPeripheral
 */
- (void)addPeripheral:(YMSCBPeripheral *)yperipheral;

// >> 从ymsPeripherals数组中删除一个硬件对象
/**
 Remove yperipheral in ymsPeripherals and from standardUserDefaults if stored.
 
 @param yperipheral Instance of YMSCBPeripheral
 */
- (void)removePeripheral:(YMSCBPeripheral *)yperipheral;

// >> 根据索引从ymsPeripherals数组中删除一个硬件对象
/**
 Remove YMSCBPeripheral instance at index
 @param index The index from which to remove the object in ymsPeripherals. The value must not exceed the bounds of the array.
 */
- (void)removePeripheralAtIndex:(NSUInteger)index;

// >> 删除ymsPeripherals数组中所以硬件对象
/**
 Remove all YMSCBPeripheral instances
 */
- (void)removeAllPeripherals;

/**
 Find YMSCBPeripheral instance matching peripheral
 @param peripheral peripheral corresponding with YMSCBPeripheral
 @return instance of YMSCBPeripheral
 */
- (YMSCBPeripheral *)findPeripheral:(CBPeripheral *)peripheral;

#pragma mark - Scan Methods
// >> 扫描的接口方法
/** @name Scanning for Peripherals */
/**
 Start CoreBluetooth scan for peripherals. This method is to be overridden.
 
 The implementation of this method in a subclass must include the call to
 scanForPeripheralsWithServices:options:
 
 */
- (void)startScan;

// >> 根据UUID进行扫描的接口方法
/**
 Wrapper around the method scanForPeripheralWithServices:options: in CBCentralManager.
 
 If this method is invoked without involving a callback block, you must implement handleFoundPeripheral:.
 
 @param serviceUUIDs An array of CBUUIDs the app is interested in.
 @param options A dictionary to customize the scan, see CBCentralManagerScanOptionAllowDuplicatesKey.
 */
- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs options:(NSDictionary *)options;

// >> 根据UUID进行扫描的接口方法，并有扫描到设备的回调(回调的是硬件对象、广播信息, RSSI值)
/**
 Scans for peripherals that are advertising service(s), invoking a callback block for each peripheral
 that is discovered.

 @param serviceUUIDs An array of CBUUIDs the app is interested in.
 @param options A dictionary to customize the scan, see CBCentralManagerScanOptionAllowDuplicatesKey.
 @param discoverCallback Callback block to execute upon discovery of a peripheral. 
 The parameters of discoverCallback are:
 
 * `peripheral` - the discovered peripheral.
 * `advertisementData` - A dictionary containing any advertisement data.
 * `RSSI` - The current received signal strength indicator (RSSI) of the peripheral, in decibels.
 * `error` - The cause of a failure, if any.
 
 */
- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs options:(NSDictionary *)options withBlock:(void (^)(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI, NSError *error))discoverCallback;

// >> 停止扫描的接口方法
/**
 Stop CoreBluetooth scan for peripherals.
 */
- (void)stopScan;


#pragma mark - Retrieve Methods
/** @name Retrieve Peripherals */

// >> 这个是重新连接设备的方法吗？
/**
 Retrieves a list of known peripherals by their UUIDs.
 
 @param identifiers A list of NSUUID objects.
 @return A list of peripherals.
 */
- (NSArray *)retrievePeripheralsWithIdentifiers:(NSArray *)identifiers;

/**
 Retrieves a list of the peripherals currently connected to the system and handles them using
 handleFoundPeripheral:
 

 Retrieves all peripherals that are connected to the system and implement 
 any of the services listed in <i>serviceUUIDs</i>.
 Note that this set can include peripherals which were connected by other 
 applications, which will need to be connected locally
 via connectPeripheral:options: before they can be used.

 @param serviceUUIDS A list of NSUUID services
 @return A list of CBPeripheral objects.
 */
- (NSArray *)retrieveConnectedPeripheralsWithServices:(NSArray *)serviceUUIDS;


#pragma mark - CBCentralManager state handling methods
/** @name CBCentralManager manager state handling methods */

 // >> 手机的蓝牙状态
/**
 Handler for when manager state is powered on.
 */
- (void)managerPoweredOnHandler;

/**
 Handler for when manager state is unknown.
 */
- (void)managerUnknownHandler;

/**
 Handler for when manager state is powered off
 */
- (void)managerPoweredOffHandler;

/**
 Handler for when manager state is resetting.
 */
- (void)managerResettingHandler;

/**
 Handler for when manager state is unauthorized.
 */
- (void)managerUnauthorizedHandler;

/**
 Handler for when manager state is unsupported.
 */
- (void)managerUnsupportedHandler;

@end

