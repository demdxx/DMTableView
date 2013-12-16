//
//  ViewController.h
//  DMTableView
//
//  Created by Dmitry Ponomarev on 13/12/13.
//  Copyright (c) 2013 demdxx. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DMTableView.h"

@interface ViewController : UIViewController <DMTableViewDataSource, DMTableViewDelegate>

@property (weak, nonatomic) IBOutlet DMTableView *table;

@end
