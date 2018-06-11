//
//  SchoolCarController.m
//  SchoolCarDemo
//
//  Created by 周杰 on 2018/3/7.
//  Copyright © 2018年 周杰. All rights reserved.
//

#import "SchoolCarController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <AFNetworking.h>
#import "SchoolCarRemindViewController.h"
#import "HWPopTool.h"
#import "SchoolCarModel.h"
#import "ZJWebViewController.h"

#define Screen_width [UIScreen mainScreen].bounds.size.width/375
@interface SchoolCarController ()<MAMapViewDelegate,AMapGeoFenceManagerDelegate,AMapLocationManagerDelegate>
@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) AMapLocationManager *locationManager;
@property (strong, nonatomic) UIButton *locationButton;
@property (assign, nonatomic) double zoomLevelFlag;
@property (strong, nonatomic) AMapGeoFenceManager *geoFenceManager;
@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) NSMutableArray <SchoolCarModel *> *SchoolCarMutableArray;
@property (strong, nonatomic) dispatch_source_t time;
@property (strong, nonatomic) MAPointAnnotation *carAnnotation;
@property (strong, nonatomic) MAPointAnnotation *carAnnotation1;
@property (nonatomic, assign) CGPoint tempCenter;//保存旋转前的中心点//因为车头旋转会触发aotulatoutview方法
@property (assign, nonatomic) CLLocationCoordinate2D coor1;
@property (assign) CLLocationCoordinate2D startLocation0;
@property (assign) CLLocationCoordinate2D endLocation0;
@property (assign) CLLocationCoordinate2D startLocation1;
@property (assign) CLLocationCoordinate2D endLocation1;
@property (assign) CLLocationCoordinate2D startLocation2;
@property (assign) CLLocationCoordinate2D endLocation2;
@property (strong, nonatomic) NSArray *locationArray;
//@property (strong, nonatomic) MAPolyline *schoolLine;
//@property (strong, nonatomic) MAPolyline *schoolLine1;
@property (assign) int statue;
@property (assign) int statue1;
@end
@implementation SchoolCarController
#pragma mark - Initialization
//自定义定位小蓝点
- (void)initSchoolCarAnnotationView:(CLLocationCoordinate2D) coor AndCarID:(double) id{
  
    if(id == 1 && _startLocation0.latitude){
        _startLocation0 = coor;
        _carAnnotation.coordinate = coor;
        [self.mapView addAnnotation:_carAnnotation];
        _endLocation0 = _startLocation0;
    }
    else if (id == 2 && _startLocation1.latitude){
        _carAnnotation1.coordinate = coor;
        [self.mapView addAnnotation:_carAnnotation1];
    }
}

//定时器 每秒请求一次
- (void)timer{
    //获得队列
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    //创建一个定时器
    self.time = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    //设置开始时间
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC));
    //设置时间间隔
    uint64_t interval = (uint64_t)(2.0* NSEC_PER_SEC);
    //设置定时器
    dispatch_source_set_timer(self.time, start, interval, 0);
    //设置回调
    dispatch_source_set_event_handler(self.time, ^{
        [self getSchoolLocation];
    });
    //启动定时器、、、由于定时器是暂停的
    dispatch_resume(self.time);
}

//得到校车数据
- (void)getSchoolLocation{
    NSString *str = @"https://wx.idsbllp.cn/extension/test";
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager GET:str parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        {
           NSArray *dicResult = [responseObject objectForKey:@"data"];
            for (NSDictionary *dic in dicResult) {
                SchoolCarModel *model = [[SchoolCarModel alloc]initWithDic:dic];
                [_SchoolCarMutableArray addObject:model];
            }
            _startLocation0.latitude = _SchoolCarMutableArray[0].latitude;
            _startLocation0.longitude = _SchoolCarMutableArray[0].lonitude;
            _startLocation1.latitude = _SchoolCarMutableArray[1].latitude;
            _startLocation1.longitude = _SchoolCarMutableArray[1].lonitude;
            [self initSchoolCarAnnotationView:_startLocation0 AndCarID:1];
            [self initSchoolCarAnnotationView:_startLocation1 AndCarID:2];
            _SchoolCarMutableArray = [NSMutableArray array];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        {
            NSLog(@"校车不在线");
            [self popSchoolOffView];
            dispatch_cancel(self.time);
        }
    }];
    
}
//初始化地图
- (void)initMapView{
    if (self.mapView == nil) {
        self.mapView = [[MAMapView alloc]initWithFrame:self.view.bounds];
    UIButton *logo = [UIButton buttonWithType:UIButtonTypeCustom];
    logo.frame = CGRectMake(Screen_width*20, Screen_width*30, 30, 30);
    [logo setImage:[UIImage imageNamed:@"数理学院logo"] forState:0];
    [logo addTarget:self action:@selector(skipHTML) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *and = [[UIImageView alloc]initWithFrame:CGRectMake(Screen_width *60, Screen_width*30, 20, 20)];
    UIImageView *redRock = [[UIImageView alloc]initWithFrame:CGRectMake(Screen_width *90, Screen_width*30, 60, 20)];
    UIImageView *cqupt = [[UIImageView alloc]initWithFrame:CGRectMake(CGRectGetWidth(self.mapView.bounds)-70, Screen_width+30, 50, 50)];
    
    and.image = [UIImage imageNamed:@"&"];
    redRock.image = [UIImage imageNamed:@"网校logo"];
    cqupt.image = [UIImage imageNamed:@"全校"];
    
    [self.mapView addSubview:logo];
    [self.mapView addSubview:and];
    [self.mapView addSubview:redRock];
    [self.mapView addSubview:cqupt];
        [self configeLocationManager];
    self.mapView.showsCompass = NO;//设置不显示罗盘
    _zoomLevelFlag = 16;
    self.mapView.zoomLevel = 16;//设置地图缩放级别
    [self.locationManager startUpdatingLocation];
    _mapView.delegate = self;
    [self.view addSubview:self.mapView];
    }
}
- (void)configeLocationManager{
    self.locationManager = [[AMapLocationManager alloc]init];
    self.locationManager.delegate = self;
    //设置期望定位精度
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    
    //设置不允许系统暂停定位
    [self.locationManager setPausesLocationUpdatesAutomatically:NO];
    
}
- (void) initControls{
    //添加放大按钮
    UIButton *zoomOut = [UIButton buttonWithType:UIButtonTypeCustom];
    zoomOut.frame = CGRectMake(CGRectGetWidth(self.mapView.bounds)-60, CGRectGetHeight(self.mapView.bounds)-160, 40, 40);
    zoomOut.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;//自动调整View与父视图的上边距，以保持下边距不变
    [zoomOut setImage:[UIImage imageNamed:@"放大"] forState:UIControlStateNormal];
    [zoomOut addTarget:self action:@selector(zoom) forControlEvents:UIControlEventTouchUpInside];
    [self.mapView addSubview:zoomOut];
    
    //添加缩小按钮
    UIButton *shrink = [UIButton buttonWithType:UIButtonTypeCustom];
    shrink.frame = CGRectMake(CGRectGetWidth(self.mapView.bounds)-60, CGRectGetHeight(_mapView.bounds)-110, 40, 40);
    shrink.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [shrink setImage:[UIImage imageNamed:@"缩小"] forState:0];
    [shrink addTarget:self action:@selector(shrink) forControlEvents:UIControlEventTouchUpInside];
    [self.mapView addSubview:shrink];
    
    _locationButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _locationButton.frame = CGRectMake(20, CGRectGetHeight(_mapView.bounds)-80, 40, 40);
    [_locationButton setImage:[UIImage imageNamed:@"location"] forState:UIControlStateNormal];
    _locationButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_locationButton addTarget:self action:@selector(locate) forControlEvents:UIControlEventTouchUpInside];
    [self.mapView addSubview:_locationButton];
                              
}
#pragma mark Action Handle

- (void)skipHTML{
    
    ZJWebViewController *webVC = [[ZJWebViewController alloc]init];
    [self.navigationController pushViewController:webVC animated:YES];
    
}
//校车运行时间弹窗
- (void)SchoolCarRunTimeView{
    _contentView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 270, 300)];
    _contentView.backgroundColor = [UIColor clearColor];
    UIImageView *imgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"弹窗部分"]];
    [_contentView addSubview:imgView];
    [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
    
    [HWPopTool sharedInstance].shadeBackgroundType = ShadeBackgroundTypeSolid;
    [HWPopTool sharedInstance].closeButtonType = ButtonPositionTypeRight;
    [[HWPopTool sharedInstance] showWithPresentView:_contentView animated:YES];
}

////校车定位弹窗
//- (void)popCarLocateView{
//    _contentView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 270, 300)];
//    _contentView.backgroundColor = [UIColor clearColor];
//    UIImageView *imgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"定位弹窗"]];
//    [_contentView addSubview:imgView];
//
//    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
//    [cancelButton setImage:[UIImage imageNamed:@"取消按钮"] forState:UIControlStateNormal];
//    cancelButton.frame = CGRectMake(20, 270, 100, 60);
//    [cancelButton addTarget:self action:@selector(schoolLocation) forControlEvents:UIControlEventTouchUpInside];
//    [_contentView addSubview:cancelButton];
//
//    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
//    [confirmButton setImage:[UIImage imageNamed:@"确定按钮"] forState:0];
//    confirmButton.frame = CGRectMake(140, 270, 100, 60);
//    [confirmButton addTarget:self action:@selector(userLocations) forControlEvents:UIControlEventTouchUpInside];
//    [_contentView addSubview:confirmButton];
//
//    [HWPopTool sharedInstance].shadeBackgroundType = ShadeBackgroundTypeSolid;
//    [HWPopTool sharedInstance].closeButtonType = ButtonPositionTypeRight;
//    [[HWPopTool sharedInstance] showWithPresentView:_contentView animated:YES];
//}1

////取消按钮 显示校车位置
//- (void)schoolLocation{
//    [self.mapView setCenterCoordinate:_coor1];
//    [self closeAndBack];
//}

//确定按钮，显示用户位置
- (void) userLocations{
    [self closeAndBack];
    [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
}
//校车失联弹窗
- (void)popSchoolOffView{
    _contentView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 270,240)];
    _contentView.backgroundColor = [UIColor clearColor];
    UIImageView *imgView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"失联弹窗"]];
    [_contentView addSubview:imgView];
    
    [HWPopTool sharedInstance].shadeBackgroundType = ShadeBackgroundTypeSolid;
    [HWPopTool sharedInstance].closeButtonType = ButtonPositionTypeRight;
    [[HWPopTool sharedInstance] showWithPresentView:_contentView animated:YES];
}

- (void)closeAndBack{
    [[HWPopTool sharedInstance]closeWithBlcok:nil];
}

- (void)zoom{
    _zoomLevelFlag  += 0.3;//每次放大0.3
//    NSLog(@"%d",_zoomLevelFlag );
    self.mapView.zoomLevel = _zoomLevelFlag;
}

- (void)shrink{
    _zoomLevelFlag -=0.3;//每次缩小0.3
//    NSLog(@"%d",_zoomLevelFlag);
    self.mapView.zoomLevel = _zoomLevelFlag ;
}

- (void)locate{
    if (_mapView.userTrackingMode != MAUserTrackingModeFollow) {
        //追踪用户的位置更新
        [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
    }
}
//提示页面
- (void)tip{
    SchoolCarRemindViewController *remindVC = [[SchoolCarRemindViewController alloc]init];
    [self.navigationController pushViewController:remindVC animated:YES];
}

- (void)schoolRunTime{
    //获取当前时间
    NSDate *now = [NSDate date];
    NSLog(@"now date is: %@", now);
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:now];
    int hour = [dateComponent hour];
    if ((0<=hour&&hour<11)||(14<=hour&&hour<17)||(22<hour&&hour<=24)) {
        [self SchoolCarRunTimeView];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [AMapServices sharedServices].apiKey = @"aaddaff606ec29b9367bafbe9551e0e3";
    [AMapServices sharedServices].enableHTTPS = YES;
    [self initMapView];
    _statue = 1;
    _statue1 = 1;
    _SchoolCarMutableArray = [NSMutableArray array];
    _carAnnotation = [[MAPointAnnotation alloc]init];
    _carAnnotation1 = [[MAPointAnnotation alloc]init];
    //点击提示按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"tip_item"]style:UIBarButtonItemStylePlain target:self action:@selector(tip)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"back_item"] style:UIBarButtonItemStylePlain target:self action:@selector(back)];
    [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
    [self initControls];
    [self timer];

}
- (void)back{
    [self.navigationController popToRootViewControllerAnimated:YES];
}
- (void)viewWillAppear:(BOOL)animated{
    [self schoolRunTime];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark MAMapViewDelegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation{
    if ([annotation isKindOfClass:[MAUserLocation class]]) {
       
        static NSString *userLocationStyleReuseIndentifier = @"userLocationStyleReuseIndentifier";
        MAAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:userLocationStyleReuseIndentifier];
        if (annotationView == nil) {
            annotationView = [[MAPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:userLocationStyleReuseIndentifier];
        }
        annotationView.canShowCallout = NO;//点击不可弹出气泡
        annotationView.enabled = NO;//不可点击
        annotationView.image = [UIImage imageNamed:@"男生"];
        annotationView.contentMode = UIViewContentModeScaleToFill;
        annotationView.layer.masksToBounds = YES;
        return annotationView;
    }
    else if ([annotation isKindOfClass:[MAPointAnnotation class]]){
        static NSString *pointReuseIndentifier = @"pointReuseIndentifier";
        MAPinAnnotationView *annotationView  = [[MAPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
        
        if (annotationView == nil) {
            annotationView = [[MAPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
        }
        annotationView.image = [UIImage imageNamed:@"校车"];
        self.tempCenter = CGPointMake(annotationView.frame.size.width/2, annotationView.frame.size.height/2);
        annotationView.backgroundColor = [UIColor clearColor];
         annotationView.frame =CGRectMake(0, 0, 30,45);
        annotationView.canShowCallout = YES;//设置气泡是否可以弹出，默认为No
        annotationView.draggable = NO;//设置标注是否可以拖动
        annotationView.enabled = NO;//不可点击
        annotationView.contentMode = UIViewContentModeScaleToFill;
        annotationView.layer.masksToBounds = YES;
        annotation.title = @"校车";
        return annotationView;
    }
    return nil;

}
//
-(MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay{
    if ([overlay isKindOfClass:[MAPolyline class] ]) {
        MAPolylineRenderer *poly = [[MAPolylineRenderer alloc]initWithPolyline:overlay];
        poly.lineWidth = 5.f;
        poly.strokeColor = [UIColor redColor];
        return poly;
    }
    return nil;
}

@end
