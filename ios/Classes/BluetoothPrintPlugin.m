#import "BluetoothPrintPlugin.h"
#import "ConnecterManager.h"
#import "EscCommand.h"
#import "TscCommand.h"

@interface BluetoothPrintPlugin ()
@property(nonatomic, retain) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, retain) FlutterMethodChannel *channel;
@property(nonatomic, retain) BluetoothPrintStreamHandler *stateStreamHandler;
@property(nonatomic, assign) int stateID;
@property(nonatomic) NSMutableDictionary *scannedPeripherals;
@end

@implementation BluetoothPrintPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:NAMESPACE @"/methods"
            binaryMessenger:[registrar messenger]];
  FlutterEventChannel* stateChannel = [FlutterEventChannel eventChannelWithName:NAMESPACE @"/state" binaryMessenger:[registrar messenger]];
  BluetoothPrintPlugin* instance = [[BluetoothPrintPlugin alloc] init];

  instance.channel = channel;
  instance.scannedPeripherals = [NSMutableDictionary new];
    
  // STATE
  BluetoothPrintStreamHandler* stateStreamHandler = [[BluetoothPrintStreamHandler alloc] init];
  [stateChannel setStreamHandler:stateStreamHandler];
  instance.stateStreamHandler = stateStreamHandler;

  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"call method -> %@", call.method);
    
  if ([@"state" isEqualToString:call.method]) {
    result([NSNumber numberWithInt:self.stateID]);
  } else if([@"isAvailable" isEqualToString:call.method]) {
    
    result(@(YES));
  } else if([@"isConnected" isEqualToString:call.method]) {
    
    bool isConnected = self.stateID == 1;

    result(@(isConnected));
  } else if([@"isOn" isEqualToString:call.method]) {
    result(@(YES));
  }else if([@"startScan" isEqualToString:call.method]) {
      NSLog(@"getDevices method -> %@", call.method);
      [self.scannedPeripherals removeAllObjects];
      
      if (Manager.bleConnecter == nil) {
          [Manager didUpdateState:^(NSInteger state) {
              switch (state) {
                  case CBCentralManagerStateUnsupported:
                      NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
                      break;
                  case CBCentralManagerStateUnauthorized:
                      NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
                      break;
                  case CBCentralManagerStatePoweredOff:
                      NSLog(@"Bluetooth is currently powered off.");
                      self.stateID = -1;
                      break;
                  case CBCentralManagerStatePoweredOn:
                      [self startScan];
                      NSLog(@"Bluetooth power on");
                      self.stateID = -1;
                      break;
                  case CBCentralManagerStateUnknown:
                  default:
                      self.stateID = -1;
                      break;
              }
          }];
      } else {
          [self startScan];
      }
      
    result(nil);
  } else if([@"stopScan" isEqualToString:call.method]) {
    [Manager stopScan];
    result(nil);
  } else if([@"connect" isEqualToString:call.method]) {
    NSDictionary *device = [call arguments];
    @try {
      NSLog(@"connect device begin -> %@", [device objectForKey:@"name"]);
      CBPeripheral *peripheral = [_scannedPeripherals objectForKey:[device objectForKey:@"address"]];
        
      self.state = ^(ConnectState state) {
        [self updateConnectState:state];
      };
      [Manager connectPeripheral:peripheral options:nil timeout:2 connectBlack: self.state];
      
      result(nil);
    } @catch(FlutterError *e) {
      result(e);
    }
  } else if([@"disconnect" isEqualToString:call.method]) {
    @try {
      [Manager close];
      result(nil);
    } @catch(FlutterError *e) {
      result(e);
    }
  } else if([@"print" isEqualToString:call.method]) {
     @try {
       
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  } else if([@"printReceipt" isEqualToString:call.method]) {
       @try {
         NSDictionary *args = [call arguments];
         [Manager write:[self mapToEscCommand:args]];
         result(nil);
       } @catch(FlutterError *e) {
         result(e);
       }
  } else if([@"rawBytes" isEqualToString:call.method]) {
      @try {
        NSDictionary *args = [call arguments];
        NSDictionary *config = [args objectForKey:@"config"];
        FlutterStandardTypedData *list = [args objectForKey:@"data"];
        [Manager write:list.data];
        result(nil);
      } @catch(FlutterError *e) {
        result(e);
      }
  } else if([@"printLabel" isEqualToString:call.method]) {
     @try {
       NSDictionary *args = [call arguments];
       [Manager write:[self mapToTscCommand:args]];
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  }else if([@"printTest" isEqualToString:call.method]) {
     @try {
       
       result(nil);
     } @catch(FlutterError *e) {
       result(e);
     }
  }
}

-(NSData *)mapToTscCommand:(NSDictionary *) args {
    NSDictionary *config = [args objectForKey:@"config"];
    NSMutableArray *list = [args objectForKey:@"data"];
    
    NSNumber *width = ![config objectForKey:@"width"]?@"48" : [config objectForKey:@"width"];
    NSNumber *height = ![config objectForKey:@"height"]?@"80" : [config objectForKey:@"height"];
    NSNumber *gap = ![config objectForKey:@"gap"]?@"2" : [config objectForKey:@"gap"];
    
    TscCommand *command = [[TscCommand alloc]init];
    // 设置标签尺寸宽高，按照实际尺寸设置 单位mm
    [command addSize:[width intValue] :[height intValue]];
    // 设置标签间隙，按照实际尺寸设置，如果为无间隙纸则设置为0 单位mm
    [command addGapWithM:[gap intValue] withN:0];
    // 设置原点坐标
    [command addReference:0 :0];
    // 撕纸模式开启
    [command addTear:@"ON"];
    // 开启带Response的打印，用于连续打印
    [command addQueryPrinterStatus:ON];
    // 清除打印缓冲区
    [command addCls];
    
    for(NSDictionary *m in list){
        
        NSString *type = [m objectForKey:@"type"];
        NSString *content = [m objectForKey:@"content"];
        NSNumber *x = ![m objectForKey:@"x"]?@0 : [m objectForKey:@"x"];
        NSNumber *y = ![m objectForKey:@"y"]?@0 : [m objectForKey:@"y"];
        
        if([@"text" isEqualToString:type]){
            [command addTextwithX:[x intValue] withY:[y intValue] withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:content];
        }else if([@"barcode" isEqualToString:type]){
            [command add1DBarcode:[x intValue] :[y intValue] :@"CODE128" :100 :1 :0 :2 :2 :content];
        }else if([@"qrcode" isEqualToString:type]){
            [command addQRCode:[x intValue] :[y intValue] :@"L" :5 :@"A" :0 :content];
        }else if([@"image" isEqualToString:type]){
            NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:content options:0];
            UIImage *image = [UIImage imageWithData:decodeData];
            [command addBitmapwithX:[x intValue] withY:[y intValue] withMode:0 withWidth:300 withImage:image];
        }
       
    }
    
    [command addPrint:1 :1];
    return [command getCommand];
}

-(NSData *)mapToEscCommand:(NSDictionary *) args {
    NSDictionary *config = [args objectForKey:@"config"];
    NSMutableArray *list = [args objectForKey:@"data"];
    
    EscCommand *command = [[EscCommand alloc]init];
    [command addInitializePrinter];
    [command addPrintAndFeedLines:3];

    for(NSDictionary *m in list){
        
        NSString *type = [m objectForKey:@"type"];
        NSString *content = [m objectForKey:@"content"];
        NSNumber *align = ![m objectForKey:@"align"]?@0 : [m objectForKey:@"align"];
        NSNumber *size = ![m objectForKey:@"size"]?@4 : [m objectForKey:@"size"];
        NSNumber *weight = ![m objectForKey:@"weight"]?@0 : [m objectForKey:@"weight"];
        NSNumber *width = ![m objectForKey:@"width"]?@0 : [m objectForKey:@"width"];
        NSNumber *height = ![m objectForKey:@"height"]?@0 : [m objectForKey:@"height"];
        NSNumber *underline = ![m objectForKey:@"underline"]?@0 : [m objectForKey:@"underline"];
        NSNumber *linefeed = ![m objectForKey:@"linefeed"]?@0 : [m objectForKey:@"linefeed"];
        
        //内容居左（默认居左）
        [command addSetJustification:[align intValue]];
        
        if([@"text" isEqualToString:type]){
            [command addPrintMode: [weight intValue] ==0?0:0|8|16|32];
            [command addText:content];
            [command addPrintMode: 0];
        }else if([@"barcode" isEqualToString:type]){
            [command addSetBarcodeWidth:2];
            [command addSetBarcodeHeight:60];
            [command addSetBarcodeHRPosition:2];
            [command addCODE128:'B' : content];
        }else if([@"qrcode" isEqualToString:type]){
            //二维码
            [command addQRCodeSizewithpL:0 withpH:0 withcn:0 withyfn:0 withn:[size intValue]];
            [command addQRCodeSavewithpL:0x0b withpH:0 withcn:0x31 withyfn:0x50 withm:0x30 withData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [command addQRCodePrintwithpL:0 withpH:0 withcn:0 withyfn:0 withm:0];
        }else if([@"image" isEqualToString:type]){
            NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:content options:0];
            UIImage *image = [UIImage imageWithData:decodeData];
            [command addOriginrastBitImage:image width:576];
        }
        
        if([linefeed isEqualToNumber:@1]){
            [command addPrintAndLineFeed];
        }
       
    }
    
    [command addPrintAndFeedLines:4];
    return [command getCommand];
}


-(void)startScan {
    [Manager scanForPeripheralsWithServices:nil options:nil discover:^(CBPeripheral * _Nullable peripheral, NSDictionary<NSString *,id> * _Nullable advertisementData, NSNumber * _Nullable RSSI) {
        if (peripheral.name != nil) {
            
            NSLog(@"find device -> %@", peripheral.name);
            [self.scannedPeripherals setObject:peripheral forKey:[[peripheral identifier] UUIDString]];
            
            NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:peripheral.identifier.UUIDString,@"address",peripheral.name,@"name",nil,@"type",nil];
            [_channel invokeMethod:@"ScanResult" arguments:device];
        }
    }];
    
}

-(void)updateConnectState:(ConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNumber *ret = @0;
        switch (state) {
            case CONNECT_STATE_CONNECTING:
                NSLog(@"status -> %@", @"Connection status: Connecting....");
                ret = @0;
                self.stateID = 0;
                break;
            case CONNECT_STATE_CONNECTED:
                NSLog(@"status -> %@", @"Connection status: successfully connected");
                ret = @1;
                self.stateID = 1;
                break;
            case CONNECT_STATE_FAILT:
                NSLog(@"status -> %@", @"Connection status: connection failed");
                ret = @0;
                break;
            case CONNECT_STATE_DISCONNECT:
                NSLog(@"status -> %@", @"Connection status: disconnected");
                ret = @0;
                self.stateID = -1;
                break;
            default:
                NSLog(@"status -> %@", @"Connection status: connection timed out");
                ret = @0;
                self.stateID = -1;
                break;
        }
        
         NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:ret,@"id",nil];
        if(_stateStreamHandler.sink != nil) {
          self.stateStreamHandler.sink([dict objectForKey:@"id"]);
        }
    });
}

@end

@implementation BluetoothPrintStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
  self.sink = eventSink;
  return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  self.sink = nil;
  return nil;
}

@end
