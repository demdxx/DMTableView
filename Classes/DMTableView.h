//
//  DMTableView.h
//  DMTableView
//
//  Created by Dmitry Ponomarev on 13/12/13.
//  Copyright (c) 2013 demdxx. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DMTableView;

////////////////////////////////////////////////////////////////////////////////
/// Declare table view protocol
////////////////////////////////////////////////////////////////////////////////

@protocol DMTableViewDelegate <NSObject, UIScrollViewDelegate>

@optional

- (UIView *)tableView:(DMTableView *)tableView columnAtIndex:(NSInteger)index;
- (UIView *)tableView:(DMTableView *)tableView cellAtIndexPath:(NSIndexPath *)indexPath;

// Flags

- (BOOL)tableViewHasFixedColumnRow:(DMTableView *)tableView;
- (BOOL)tableViewHasFixedColumns:(DMTableView *)tableView;
- (BOOL)tableViewHasFixedRows:(DMTableView *)tableView;

- (BOOL)tableView:(DMTableView *)tableView isFixedColumn:(NSInteger)index;
- (BOOL)tableView:(DMTableView *)tableView isFixedRow:(NSInteger)index;

// Accelerated helpers

- (CGFloat)tableViewColumnWidth:(DMTableView *)tableView;
- (CGFloat)tableView:(DMTableView *)tableView columnWidthAtIndex:(NSInteger)index;
- (CGFloat)tableViewColumnsHeight:(DMTableView *)tableView;
- (CGFloat)tableViewRowHeight:(DMTableView *)tableView;
- (CGFloat)tableView:(DMTableView *)tableView rowHeightAtIndex:(NSInteger)index;

// Events

- (void)tableViewClick:(DMTableView *)tableView cell:(UIView *)cell indexPath:(NSIndexPath *)indexPath;

@end

////////////////////////////////////////////////////////////////////////////////
/// Declare table data source protocol
////////////////////////////////////////////////////////////////////////////////

@protocol DMTableViewDataSource <NSObject>

- (NSInteger)tableViewColumnsCount:(DMTableView *)tableView;
- (NSInteger)tableViewRowsCount:(DMTableView *)tableView;

@optional

- (NSString *)tableView:(DMTableView *)tableView titleForColumnAtIndex:(NSInteger)index;
- (NSString *)tableView:(DMTableView *)tableView textForCellAtIndexPath:(NSIndexPath *)indexPath;

@end

////////////////////////////////////////////////////////////////////////////////
/// Table View Declaration
////////////////////////////////////////////////////////////////////////////////

@interface DMTableView : UIScrollView <NSCoding>

@property (nonatomic, assign) id<DMTableViewDelegate> delegate;
@property (nonatomic, assign) id<DMTableViewDataSource> dataSource;

@property (nonatomic, assign) CGFloat tablePadding;
@property (nonatomic, assign) CGFloat itemMargin;

- (void)initControl;

// Getters/Setters

- (NSInteger)columnsCount;
- (NSInteger)rowsCount;

- (UIView *)columnAtIndex:(NSInteger)index;
- (UIView *)cellAtIndexPath:(NSIndexPath *)indexPath;

// Actions

- (void)updateContentSize;
- (void)updateBackgroundViews;
- (void)reloadData;

// Detecting

- (BOOL)isFixedColumn:(NSInteger)index;
- (BOOL)isFixedRow:(NSInteger)index;

- (NSRange)fixedColumnsRangeForRange:(NSRange)range unical:(BOOL)unical;
- (NSRange)fixedRowsRangeForRange:(NSRange)range unical:(BOOL)unical;

- (NSRange)visibleColumnsRange;
- (NSRange)visibleRowsRange;

// Metrics helpers

- (CGSize)calculateContentSize;
- (UIEdgeInsets)calculateScrollIndicatorInsets;

/**
 * Get column X position & WIDTH
 *
 * @param index
 * @return {x: X, y: WIDTH}
 */
- (CGPoint)columnBounds:(NSInteger)index;

/**
 * Get row Y position & HEIGH
 *
 * @param index
 * @return {y: Y, x: HEIGHT}
 */
- (CGPoint)rowBounds:(NSInteger)index;

- (CGRect)columnRectAtIndex:(NSInteger)index xOffset:(CGFloat)offset;
- (CGRect)cellRectAtIndexPath:(NSIndexPath *)indexPath xOffset:(CGFloat)xOffset yOffset:(CGFloat)yOffset;

- (CGFloat)columnWidthAtIndex:(NSInteger)index;
- (CGFloat)columnsHeight;
- (CGFloat)rowHeightAtIndex:(NSInteger)index;

// Helpers

- (void)tableViewColumnPrepare:(UIView *)column atIndex:(NSInteger)index;
- (void)tableViewCellPrepare:(UIView *)cell atIndexPath:(NSIndexPath *)indexPath;
- (UIView *)dequeueReusableColumnWithIdentifier:(NSString *)identifier index:(NSInteger)index;
- (UIView *)dequeueReusableCellWithIdentifier:(NSString *)identifier indexPath:(NSIndexPath *)indexPath;

@end

////////////////////////////////////////////////////////////////////////////////
/// Extend index path
////////////////////////////////////////////////////////////////////////////////

@interface NSIndexPath (DMTableView)

@property (nonatomic, readonly) NSInteger column;

+ (instancetype)indexPathForRow:(NSInteger)row column:(NSInteger)column;

@end

