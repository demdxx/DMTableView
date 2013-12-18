//
//  DMTableView.m
//  DMTableView
//
//  Created by Dmitry Ponomarev on 13/12/13.
//  Copyright (c) 2013 demdxx. All rights reserved.
//

#import "DMTableView.h"

#ifndef __has_feature
  #define __has_feature(x) 0
#endif

#if __has_feature(objc_arc)
  #define M_OBJECT_RELEASE(obj) obj = nil
  #define M_OBJECT_AUTORELEASE(obj) obj
  #define M_OBJECT_DEALLOC(obj)
  #define M_OBJECT_RETAIN(obj) obj
  #define M_OBJECT_AUTORELEASE_START @autoreleasepool {
  #define M_OBJECT_AUTORELEASE_END }
#else
  #define M_OBJECT_RELEASE(obj) if (obj!=nil) { [obj release]; obj=nil; }
  #define M_OBJECT_AUTORELEASE(obj) [obj autorelease]
  #define M_OBJECT_DEALLOC(obj) [obj dealloc]
  #define M_OBJECT_RETAIN(obj) [obj retain]
  #define M_OBJECT_AUTORELEASE_START NSAutoreleasePool pool = [[NSAutoreleasePool alloc] init];
  #define M_OBJECT_AUTORELEASE_END [pool release];
#endif


////////////////////////////////////////////////////////////////////////////////
/// Hidden declaration
////////////////////////////////////////////////////////////////////////////////

@interface DMTableView ()

@property (nonatomic, strong) UIView* headerBackgroundView;
@property (nonatomic, strong) UIView* leftBackgroundView;

// Actions

- (void)updateContent;

// Helpers

- (NSInteger)tagForColumnAtIndex:(NSInteger)index;
- (NSInteger)tagForCellAtIndexPath:(NSIndexPath *)indexPath;

@end

////////////////////////////////////////////////////////////////////////////////
/// Implementation
////////////////////////////////////////////////////////////////////////////////

@implementation DMTableView
{
  NSMutableDictionary *_columnsBounds;
  NSMutableSet *_currentColumnsFixed;
  NSMutableSet *_columnsFixed;
  NSMutableDictionary *_rowsBounds;
  NSMutableSet *_currentRowsFixed;
  NSMutableSet *_rowsFixed;
  
  NSRange _fixedColumnsRange;
  NSRange _fixedRowsRange;
}

@synthesize dataSource = _dataSource;
@synthesize tablePadding = _tablePadding;
@synthesize itemMargin = _itemMargin;
@synthesize headerBackgroundView = _headerBackgroundView;
@synthesize leftBackgroundView = _leftBackgroundView;

- (id)initWithCoder:(NSCoder *)aDecoder
{
  if (self = [super initWithCoder:aDecoder]) {
    [self initControl];
  }
  return self;
}

- (id)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    [self initControl];
  }
  return self;
}

- (void)initControl
{
  _columnsBounds = [NSMutableDictionary dictionary];
  _currentColumnsFixed = [NSMutableSet set];
  _columnsFixed = [NSMutableSet set];

  _rowsBounds = [NSMutableDictionary dictionary];
  _currentRowsFixed = [NSMutableSet set];
  _rowsFixed = [NSMutableSet set];

  _fixedColumnsRange = NSMakeRange(NSNotFound, 0);
  _fixedRowsRange = NSMakeRange(NSNotFound, 0);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Actions
////////////////////////////////////////////////////////////////////////////////

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  static bool init = false;
  if (!init) {
    [self updateContentSize];
    [self updateContent];
    init = true;
  } else {
    [self updateContent];
  }
}

- (void)updateContentSize
{
  self.contentSize = [self calculateContentSize];
  self.scrollIndicatorInsets = [self calculateScrollIndicatorInsets];
}

- (void)reloadData
{
  [_columnsBounds removeAllObjects];
  [_columnsFixed removeAllObjects];
  [_rowsBounds removeAllObjects];
  [_rowsFixed removeAllObjects];

  [self updateContentSize];
  [self updateContent];
}

- (void)updateContent
{
  NSRange columns = [self visibleColumnsRange];
  NSRange rows = [self visibleRowsRange];
  NSUInteger endCl = columns.location + columns.length;
  NSUInteger endEl = rows.location + rows.length;
  NSUInteger cI = columns.location;

  //
  // Update column positions and create views if necessary
  //
  for (NSUInteger i = cI ; i <= endCl ; i++) {
    // Update cells in rows
    for (NSUInteger j = rows.location ; j <= endEl ; j++) {
      NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
      [self cellAtIndexPath:path];
    }
    
    // Update column
    [self columnAtIndex:i];
  }
  
  // Move header to front
  [self bringSubviewToFront:self.headerBackgroundView];

  // Update fixed fields
  [self updateFixedColumns:columns rows:rows];
  
  // Columns to front
  [self bringSubviewToFront:self.headerBackgroundView];
  
  // Update layout positions
  [self updateBackgroundViews];
}

- (void)updateFixedColumns:(NSRange)columns rows:(NSRange)rows
{
  NSUInteger cI = columns.location;
  NSUInteger endCl = columns.location + columns.length;
  NSUInteger endEl = rows.location + rows.length;
  bool updateRows = false;
  {
    NSRange nRows = [self fixedRowsRangeForRange:rows unical:NO];
    if (NSNotFound != nRows.location) {
      rows = nRows;
      updateRows = true;
    }
  }
  
  columns = [self fixedColumnsRangeForRange:columns unical:NO];
  
  if (columns.location < 1000) {
    CGFloat xOffset = _tablePadding;
    CGFloat yOffset = _tablePadding;
    endCl = MAX(columns.location + columns.length, endCl);
    
    for (NSInteger i = columns.location ; i <= endCl ; i++) {
      if ([self isFixedColumn:i]) {
        CGRect cframe;
        
        // Update cells in rows
        for (NSUInteger j = rows.location ; j <= endEl ; j++) {
          NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
          UIView *cell = [self cellAtIndexPath:path];
          cframe = [self cellRectAtIndexPath:path xOffset:xOffset yOffset:yOffset];
          cell.frame = cframe;
          yOffset = cframe.origin.y + cframe.size.height + _itemMargin - self.contentOffset.y;
          [self bringSubviewToFront:cell];
        }
        
        // Update collumn
        {
          UIView *coll = [self columnAtIndex:i];
          cframe = [self columnRectAtIndex:i xOffset:xOffset];
          coll.frame = cframe;
          [self.headerBackgroundView bringSubviewToFront:coll];
          xOffset = cframe.origin.x + cframe.size.width + _itemMargin - self.contentOffset.x;
        }
      }
    }
  } else if (updateRows) {
    CGFloat xOffset = _tablePadding;
    CGFloat yOffset = _tablePadding;
    const NSUInteger endEl = rows.location + rows.length;
    
    // Update cells in rows
    for (NSUInteger j = rows.location ; j <= endEl ; j++) {
      if ([self isFixedRow:j]) {
        CGRect cframe;
        for (NSUInteger i = cI ; i <= endCl ; i++) {
          NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
          UIView *cell = [self cellAtIndexPath:path];
          cframe = [self cellRectAtIndexPath:path xOffset:xOffset yOffset:yOffset];
          cell.frame = cframe;
          yOffset = cframe.origin.y;
          [self bringSubviewToFront:cell];
        }
      }
    }
  }
}

- (void)updateBackgroundViews
{
  //
  // Update header view
  //
  {
    // If column row fixed correct vertical position
    const CGFloat yOffset = [self isFixedColumnRow] ? self.contentOffset.y : 0;
    CGRect topColumnsFrame = CGRectMake(0, yOffset, self.contentSize.width,
                                        _tablePadding + self.columnsHeight + _itemMargin);
    self.headerBackgroundView.frame = topColumnsFrame;
  }
  
  //
  // Update left block view
  //
//  if (self.hasFixedColumns)
//  {
//    CGRect leftBarFrame = CGRectMake(0, 0, 0, 0);
//  }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Getters/Setters
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)columnsCount
{
  return [_dataSource tableViewColumnsCount:self];
}

- (NSInteger)rowsCount
{
  return [_dataSource tableViewRowsCount:self];
}

- (UIView *)columnAtIndex:(NSInteger)index
{
  UIView *column;
  if ([self.delegate respondsToSelector:@selector(tableView:columnAtIndex:)]) {
    column = [self.delegate tableView:self columnAtIndex:index];
    [self tableViewColumnPrepare:column atIndex:index];
  } else if ([_dataSource respondsToSelector:@selector(tableView:titleForColumnAtIndex:)]) {
    column = [self dequeueReusableColumnWithIdentifier:@"Cell" index:index];
    if (nil == column) {
      column = [[UILabel alloc] init];
      ((UILabel *)column).text = [_dataSource tableView:self titleForColumnAtIndex:index];
      [self tableViewColumnPrepare:column atIndex:index];
    }
  }
  return column;
}

- (UIView *)cellAtIndexPath:(NSIndexPath *)indexPath
{
  UIView *cell;
  if ([self.delegate respondsToSelector:@selector(tableView:cellAtIndexPath:)]) {
    cell = [self.delegate tableView:self cellAtIndexPath:indexPath];
    if (cell.superview != self) {
      [self tableViewCellPrepare:cell atIndexPath:indexPath];
    }
  } else if ([_dataSource respondsToSelector:@selector(tableView:textForCellAtIndexPath:)]) {
    cell = [self dequeueReusableCellWithIdentifier:@"Cell" indexPath:indexPath];
    if (nil == cell) {
      cell = [[UILabel alloc] init];
      ((UILabel *)cell).text = [_dataSource tableView:self textForCellAtIndexPath:indexPath];
      [self tableViewCellPrepare:cell atIndexPath:indexPath];
    }
  }
  return cell;
}

- (void)setItemBorder:(CGFloat)itemBorder
{
  if (_itemMargin != itemBorder) {
    _itemMargin = itemBorder;
    [self updateContentSize];
    [self updateContent];
  }
}

- (UIView *)headerBackgroundView
{
  if (nil == _headerBackgroundView) {
    _headerBackgroundView = [[UIView alloc] init];
    [self addSubview:_headerBackgroundView];
    _headerBackgroundView.backgroundColor = [UIColor colorWithRed:0.3 green:0.7 blue:0.2 alpha:1];
  }
  return _headerBackgroundView;
}

- (UIView *)leftBackgroundView
{
  if (nil == _leftBackgroundView) {
    _leftBackgroundView = [[UIView alloc] init];
    [self addSubview:_leftBackgroundView];
    _leftBackgroundView.backgroundColor = [UIColor colorWithRed:0.7 green:0.3 blue:0.5 alpha:1];
  }
  return _leftBackgroundView;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Detecting
////////////////////////////////////////////////////////////////////////////////

- (BOOL)isFixedColumnRow
{
  return [self.delegate respondsToSelector:@selector(tableViewHasFixedColumnRow:)]
      || [self.delegate tableViewHasFixedColumnRow:self];
}

- (BOOL)hasFixedColumns
{
  if (self.delegate &&
     [self.delegate respondsToSelector:@selector(tableViewHasFixedColumns:)])
  {
    return [self.delegate tableViewHasFixedColumns:self];
  }
  return NO;
}

- (BOOL)hasFixedRows
{
  if (self.delegate &&
      [self.delegate respondsToSelector:@selector(tableViewHasFixedRows:)])
  {
    return [self.delegate tableViewHasFixedRows:self];
  }
  return NO;
}

- (BOOL)isFixedColumn:(NSInteger)index
{
  if ([_columnsFixed containsObject:@(index)]) {
    return YES;
  }
  if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:isFixedColumn:)]) {
    if ([self.delegate tableView:self isFixedColumn:index]) {
      [_columnsFixed addObject:@(index)];
      return YES;
    }
  }
  return NO;
}

- (BOOL)isFixedRow:(NSInteger)index
{
  if ([_rowsFixed containsObject:@(index)]) {
    return YES;
  }
  if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:isFixedRow:)]) {
    if ([self.delegate tableView:self isFixedRow:index]) {
      [_rowsFixed addObject:@(index)];
      return YES;
    }
  }
  return NO;
}

- (NSRange)fixedColumnsRangeForRange:(NSRange)range unical:(BOOL)unical
{
  if (!self.delegate ||
      ![self.delegate respondsToSelector:@selector(tableViewHasFixedColumns:)] ||
      ![self.delegate tableViewHasFixedColumns:self] ||
      NSNotFound == range.location) {
    return NSMakeRange(NSNotFound, 0);
  }

  NSRange r = NSMakeRange(NSNotFound, 0);
  NSUInteger i = 0;
  NSUInteger count = range.location + range.length;
  
  if (NSNotFound != _fixedColumnsRange.location) {
    i = _fixedColumnsRange.location + 1;
    if (unical) {
      count = _fixedColumnsRange.location + _fixedColumnsRange.length;
    }
  } else if (unical) {
    count = range.location;
    r.location = 0;
  }
  
  for (; i < count ; i++) {
    if ([self isFixedColumn:i]) {
      if (NSNotFound == r.location) {
        r.location = i;
      } else {
        r.length = i - r.location + 1;
      }
    }
  }
  return r;
}

- (NSRange)fixedRowsRangeForRange:(NSRange)range unical:(BOOL)unical
{
  if (!self.delegate ||
      ![self.delegate respondsToSelector:@selector(tableViewHasFixedRows:)] ||
      ![self.delegate tableViewHasFixedRows:self] ||
      NSNotFound == range.location) {
    return NSMakeRange(NSNotFound, 0);
  }
  
  NSRange r = NSMakeRange(NSNotFound, 0);
  NSUInteger i = 0;
  NSUInteger count = range.location + range.length;
  
  if (NSNotFound != _fixedRowsRange.location) {
    i = _fixedRowsRange.location + 1;
    if (unical) {
      count = _fixedRowsRange.location + _fixedRowsRange.length;
    }
  } else if (unical) {
    count = range.location;
    r.location = 0;
  }

  for (; i < count ; i++) {
    if ([self isFixedRow:i]) {
      if (NSNotFound == r.location) {
        r.location = i;
      } else {
        r.length = r.location - i + 2;
      }
    }
  }
  return r;
}

- (NSRange)visibleColumnsRange
{
  NSRange range = NSMakeRange(0, 0);
  const NSInteger maxCount = self.columnsCount;
  const CGFloat scrOffset = self.contentOffset.x - _tablePadding;

  // -+--*---+--+----+-*--+-
  //     XC  |  | DX |
  // -+--*---+--+----+-*--+-
  //         |  |    |
  //         |  |    |
  
  if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)] ) {
    const CGFloat columnWidth = [self columnWidthAtIndex:-1] + _itemMargin;
    const CGFloat divCell = (CGFloat)fmod(scrOffset, columnWidth);

    range.location = divCell < 0 ? 0 : (NSUInteger)floor(scrOffset / columnWidth);
    range.length = (NSUInteger)floor(self.frame.size.width / columnWidth) + (divCell != 0 ? 1 : 0);
    
    // fix count
    if (range.location >= maxCount) {
      range.location = 0;
      range.length = 0;
    } else if (range.location + range.length >= maxCount) {
      range.length = maxCount - range.location - 1;
    }
  } else {
    bool setted = false;
    CGFloat offset = 0;
    range.length = maxCount - 1;
    for (NSUInteger i = 0 ; i < maxCount ; i++) {
      offset += [self columnWidthAtIndex:i] + _itemMargin;
      if (offset > scrOffset && !setted) {
        range.location = i;
        setted = true;
      } else if (offset > scrOffset + self.frame.size.width) {
        range.length = i - range.location;
        break;
      }
    }
    // fix count
    if (range.location + range.length >= maxCount) {
      range.length = maxCount - range.location - 1;
    }
  }
  return range;
}

- (NSRange)visibleRowsRange
{
  NSRange range = NSMakeRange(0, 0);
  const NSInteger maxCount = self.rowsCount;
  const CGFloat scrOffset = self.contentOffset.y - _tablePadding;

  // -+--*---+--+----+-*--+-
  //     XC  |  | DX |
  // -+--*---+--+----+-*--+-
  //     3   |  |    |
  // -+--*---+--+----+-*--+-
  //         |  |    |
  //     4   |  |    |
  //         |  |    |
  // -+--*---+--+----+-*--+-
  //     5   |  |    |
  
  if (![self.delegate respondsToSelector:@selector(tableView:rowHeightAtIndex:)] ) {
    const CGFloat rowHeight = [self rowHeightAtIndex:-1] + _itemMargin;
    const CGFloat divCell = (CGFloat)fmod(self.contentOffset.y, rowHeight);

    range.location = divCell < 0 ? 0 : (NSUInteger)floor(scrOffset / rowHeight);
    range.length = (NSUInteger)floor(self.frame.size.height / rowHeight) + (divCell != 0 ? 1 : 0);
    
    // fix count
    if (range.location >= maxCount) {
      range.location = 0;
      range.length = 0;
    } else if (range.location + range.length >= maxCount) {
      range.length = maxCount - range.location;
    }
  } else {
    bool setted = false;
    CGFloat offset = 0;
    range.length = maxCount;
    for (NSUInteger i = 0 ; i < maxCount ; i++) {
      offset += [self rowHeightAtIndex:i] + _itemMargin;
      if (offset > scrOffset && !setted) {
        range.location = i;
        setted = true;
      } else if (offset > scrOffset + self.frame.size.height) {
        range.length = i - range.location + 1;
        break;
      }
    }
    // fix count
    if (range.location + range.length >= maxCount) {
      range.length = maxCount - range.location - 1;
    }
  }
  return range;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Metrics helpers
////////////////////////////////////////////////////////////////////////////////

- (CGSize)calculateContentSize
{
  CGSize size = CGSizeMake(_tablePadding*2, [self columnsHeight]+_itemMargin+_tablePadding*2);
  
  // Calc width by colums
  if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
    size.width = self.columnsCount * ([self columnWidthAtIndex:-1] + _itemMargin) - _itemMargin;
  } else {
    for (int i=0; i<self.columnsCount; i++) {
      size.width += [self columnWidthAtIndex:i] + _itemMargin;
    }
    size.width -= _itemMargin;
  }
  
  // Calc width by rows
  if (![self.delegate respondsToSelector:@selector(tableView:rowHeightAtIndex:)]) {
    size.height += self.rowsCount * ([self rowHeightAtIndex:-1] + _itemMargin) - _itemMargin;
  } else {
    for (int i = 0; i < self.rowsCount; i++) {
      size.height += [self rowHeightAtIndex:i] + _itemMargin;
    }
    size.height -= _itemMargin;
  }
  
  // Correct content size
  if (size.height < self.frame.size.height) {
    size.height = self.frame.size.height;
  }
  
  if (size.width < self.frame.size.width) {
    size.width = self.frame.size.width;
  }
  
  return size;
}

- (UIEdgeInsets)calculateScrollIndicatorInsets
{
  UIEdgeInsets inserts = UIEdgeInsetsMake(0, 0, 0, 0);
  if (self.delegate) {
    if ([self.delegate respondsToSelector:@selector(tableViewHasFixedColumnRow:)]) {
      inserts.top = [self columnsHeight] + _tablePadding;
    }
  }
  return inserts;
}

/**
 * Get column X position & WIDTH
 *
 * @param index
 * @return {x: X, y: WIDTH}
 */
- (CGPoint)columnBounds:(NSInteger)index
{
  CGPoint point = CGPointMake(0, 0);
  NSString *key = [NSString stringWithFormat:@"%ld", index];
  
  if (nil == _columnsBounds[key]) {
    CGFloat xOff = _tablePadding;
    
    // Calc row "X" position
    if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
      xOff += index * ([self columnWidthAtIndex:-1] + _itemMargin);
    } else {
      for (int i = 0; i < index ; i++) {
        xOff += [self columnWidthAtIndex:i] + _itemMargin;
      }
    }
    point = CGPointMake(xOff, [self columnWidthAtIndex:index]);
    [_columnsBounds setObject:key forKey:[NSValue valueWithCGPoint:point]];
  } else {
    point = [(NSValue *)_columnsBounds[key] CGPointValue];
  }
  
  M_OBJECT_RELEASE(key);
  return point;
}

/**
 * Get row Y position & HEIGH
 *
 * @param index
 * @return {y: Y, x: HEIGHT}
 */
- (CGPoint)rowBounds:(NSInteger)index
{
  CGPoint point = CGPointMake(0, 0);
  NSString *key = [NSString stringWithFormat:@"%ld", index];
  
  if (nil == _rowsBounds[key]) {
    CGFloat yOff = [self columnsHeight] + _itemMargin + _tablePadding;
    
    // Calc row "Y" position
    if (![self.delegate respondsToSelector:@selector(tableView:rowHeightAtIndex:)]) {
      yOff += index * ([self rowHeightAtIndex:-1] + _itemMargin);
    } else {
      for (int i = 0 ; i < index ; i++) {
        yOff += [self rowHeightAtIndex:i] + _itemMargin;
      }
    }
    point = CGPointMake([self rowHeightAtIndex:index], yOff);
    [_rowsBounds setObject:key forKey:[NSValue valueWithCGPoint:point]];
  } else {
    point = [(NSValue *)_rowsBounds[key] CGPointValue];
  }
  
  M_OBJECT_RELEASE(key);
  return point;
}

/**
 * Calculate column rect item at index
 *
 * @param index
 * @return Rect for column
 */
- (CGRect)columnRectAtIndex:(NSInteger)index xOffset:(CGFloat)offset
{
  CGPoint cPoint = [self columnBounds:index];
  CGRect rect = CGRectMake(cPoint.x, _tablePadding, cPoint.y, [self columnsHeight]);
  
  // Post process
  if (self.delegate) {
    // If this column fixed correct horizontal position
    CGFloat xLeft = rect.origin.x - self.contentOffset.x;
    if (xLeft < offset && [self isFixedColumn:index]) {
      rect.origin.x = offset + self.contentOffset.x;
    }
  }
  return rect;
}

- (CGRect)cellRectAtIndexPath:(NSIndexPath *)indexPath xOffset:(CGFloat)xOffset yOffset:(CGFloat)yOffset
{
  CGPoint rPoint = [self rowBounds:indexPath.row];
  CGPoint cPoint = [self columnBounds:indexPath.column];
  CGRect rect = CGRectMake(cPoint.x, rPoint.y, cPoint.y, rPoint.x);
  
  // Post process
  if (self.delegate) {
//    NSLog(@"X: %f => %f O %f", self.contentOffset.x, rect.origin.x, xOffset);
    if (rect.origin.x - self.contentOffset.x < xOffset && [self isFixedColumn:indexPath.column]) {
      rect.origin.x = xOffset + self.contentOffset.x;
    }
    if ([self isFixedRow:indexPath.row]) {
      rect.origin.y = yOffset + self.contentOffset.y;
    }
  }
  return rect;
}

- (CGFloat)columnWidthAtIndex:(NSInteger)index
{
  if (self.delegate) {
    if ([self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
      return [self.delegate tableView:self columnWidthAtIndex:index];
    }
    if ([self.delegate respondsToSelector:@selector(tableViewColumnWidth:)]) {
      return [self.delegate tableViewColumnWidth:self];
    }
  }
  return 44;
}

- (CGFloat)columnsHeight
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewColumnsHeight:)]) {
    return [self.delegate tableViewColumnsHeight:self];
  }
  return 44;
}

- (CGFloat)rowHeightAtIndex:(NSInteger)index
{
  if (self.delegate) {
    if ([self.delegate respondsToSelector:@selector(tableView:rowHeightAtIndex:)]) {
      return [self.delegate tableView:self rowHeightAtIndex:index];
    }
    if ([self.delegate respondsToSelector:@selector(tableViewRowHeight:)]) {
      return [self.delegate tableViewRowHeight:self];
    }
  }
  return 44;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Helpers
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)tagForColumnAtIndex:(NSInteger)index
{
  return 100000000 + index;
}

- (NSInteger)tagForCellAtIndexPath:(NSIndexPath *)indexPath
{
  return 100000 + indexPath.row + (100000 * indexPath.column);
}

- (void)tableViewColumnPrepare:(UIView *)column atIndex:(NSInteger)index
{
  if (column.superview != self.headerBackgroundView) {
    column.tag = [self tagForColumnAtIndex:index];
    column.frame = [self columnRectAtIndex:index xOffset:0];
    // TODO: Add event handler
    [self.headerBackgroundView addSubview:column];
    [self bringSubviewToFront:column];
  }
  column.backgroundColor = 0 == index %2
                         ? [UIColor yellowColor]
                         : [UIColor magentaColor];
}

- (void)tableViewCellPrepare:(UIView *)cell atIndexPath:(NSIndexPath *)indexPath
{
  if (cell.superview != self) {
    cell.tag = [self tagForCellAtIndexPath:indexPath];
    cell.frame = [self cellRectAtIndexPath:indexPath xOffset:0 yOffset:0];
    cell.layer.borderWidth = 2;
    cell.layer.borderColor = [UIColor redColor].CGColor;
    // TODO: Add event handler
    [self addSubview:cell];
    [self sendSubviewToBack:cell];
  }
  cell.backgroundColor = 0 == (indexPath.row + indexPath.column) % 2
                       ? [UIColor orangeColor]
                       : [UIColor cyanColor];
}

- (UIView *)dequeueReusableColumnWithIdentifier:(NSString *)identifier index:(NSInteger)index
{
  return [self viewWithTag:[self tagForColumnAtIndex:index]];
}

- (UIView *)dequeueReusableCellWithIdentifier:(NSString *)identifier indexPath:(NSIndexPath *)indexPath
{
  return [self viewWithTag:[self tagForCellAtIndexPath:indexPath]];
}

@end

////////////////////////////////////////////////////////////////////////////////
/// NSIndexPath Category (DMTableView) Implementation
////////////////////////////////////////////////////////////////////////////////

@implementation NSIndexPath (DMTableView)

+ (instancetype)indexPathForRow:(NSInteger)row column:(NSInteger)column
{
  return [self indexPathForRow:row inSection:column];
}

- (NSInteger)column
{
  return self.section;
}

@end

