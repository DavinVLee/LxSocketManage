//
//  ViewController.m
//  LxSocketManage
//
//  Created by 李翔 on 16/10/31.
//  Copyright © 2016年 李翔. All rights reserved.
//

#import "ViewController.h"
#import "IPAddressManage.h"
#import "LxSocketConfig.h"
#import "LxSocketManage.h"

@interface ViewController ()<LxSocketManageDelegate>
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[LxSocketManage sharedInstance] createConnectWithHost:LxSocketHost];
    [LxSocketManage sharedInstance].delegate = self;
    // Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - Delegate
- (void)didReceiveMsg:(NSString *)msg
{
    self.label.text = msg;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)btnPressed:(id)sender {
    static int count = 1;
    NSString *msg = [NSString stringWithFormat:@"发送信息%d",count];
    self.label.text = msg;
    [[LxSocketManage sharedInstance] sendMessage:msg type:SocketSendMsgNormal];
    count ++;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self btnPressed:nil];
}


@end
