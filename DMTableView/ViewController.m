//
//  ViewController.m
//  DMTableView
//
//  Created by Dmitry Ponomarev on 13/12/13.
//  Copyright (c) 2013 demdxx. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize table;

- (void)viewDidLoad
{
  table.delegate = self;
  table.dataSource = self;
  table.itemMargin = 2;
  table.tablePadding = 4;
  [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark – DMTableViewDelegate

- (CGFloat)tableView:(DMTableView *)tableView columnWidthAtIndex:(NSInteger)index
{
  return 80;
}

- (CGFloat)tableViewColumnsHeight:(DMTableView *)tableView
{
  return 50;
}

- (CGFloat)tableView:(DMTableView *)tableView rowHeightAtIndex:(NSInteger)index
{
  return 40;
}

// Flags

- (BOOL)tableViewHasFixedColumnRow:(DMTableView *)tableView
{
  return YES;
}

- (BOOL)tableViewHasFixedColumns:(DMTableView *)tableView
{
  return YES;
}

- (BOOL)tableViewHasFixedRows:(DMTableView *)tableView
{
  return YES;
}

- (BOOL)tableView:(DMTableView *)tableView isFixedColumn:(NSInteger)index
{
  return 0 == index;
}

- (BOOL)tableView:(DMTableView *)tableView isFixedRow:(NSInteger)index
{
  return NO;
}

#pragma mark – DMTableViewDataSource

- (NSInteger)tableViewColumnsCount:(DMTableView *)tableView
{
  return 10;
}

- (NSInteger)tableViewRowsCount:(DMTableView *)tableView
{
  return 100;
}

- (NSString *)tableView:(DMTableView *)tableView titleForColumnAtIndex:(NSInteger)index
{
  return [NSString stringWithFormat:@"%ld Column", (long)index];
}

- (NSString *)tableView:(DMTableView *)tableView textForCellAtIndexPath:(NSIndexPath *)indexPath
{
  return [NSString stringWithFormat:@"Cell %ld : %ld", indexPath.column, indexPath.row];
}

@end
