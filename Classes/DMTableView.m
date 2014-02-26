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


static inline UIColor *prepareBackgroundPadding(UIColor *bg)
{
  if (nil == bg || bg == [UIColor clearColor]) {
    return [UIColor whiteColor];
  }
  return bg;
}


////////////////////////////////////////////////////////////////////////////////
/// Hidden declaration
////////////////////////////////////////////////////////////////////////////////

@interface DMTableView ()

@property (nonatomic, strong) UIView* leftBackgroundView;

// Actions

- (void)updateContent:(BOOL)updateAll;

// Helpers

- (NSInteger)tagForColumnAtIndex:(NSInteger)index;
- (NSInteger)tagForCellAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)indexForColumn:(UIView *)column;
- (CGPoint)positionForCell:(UIView *)column;

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
  
  // Additional size for every column
  CGFloat _columnStreatchComponent;
  
  BOOL _isUpdateContentSize;
}

@synthesize containerView = _containerView;
@synthesize dataSource = _dataSource;
@synthesize tablePadding = _tablePadding;
@synthesize itemMargin = _itemMargin;
@synthesize headerBackgroundView = _headerBackgroundView;
@synthesize leftBackgroundView = _leftBackgroundView;
@synthesize paddingViewLeft = _paddingViewLeft;
@synthesize paddingViewTop = _paddingViewTop;

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
    init = true;
  } else if (!_isUpdateContentSize) {
    [self updateContent:NO];
  }
}

- (void) setFrame:(CGRect)frame
{
  _isUpdateContentSize = YES;

  const bool sizeChanged = !CGSizeEqualToSize(frame.size, self.frame.size);
  [super setFrame:frame];
  
  if (sizeChanged) {
    [self updateContentSize];
  }
  _isUpdateContentSize = NO;
}

- (void)updateContentSize
{
  CGSize cSize = [self calculateContentSize];
  
  if (self.hideColumnsIfEmpty && self.rowsCount < 1) {
    CGRect frame = self.frame;
    frame.size.height += 1;
    cSize = frame.size;
    self.containerView.frame = frame;
  } else {
    if (cSize.height * self.zoomScale <= self.bounds.size.height) {
      cSize.height = self.bounds.size.height + 1;
    } else {
      cSize.height *= self.zoomScale;
    }
    self.containerView.frame = CGRectMake(self.tablePadding, self.tablePadding, cSize.width-self.tablePadding*2, cSize.height-self.tablePadding*2);
  }

  cSize.width *= self.zoomScale;

  self.contentSize = cSize;
  self.scrollIndicatorInsets = [self calculateScrollIndicatorInsets];
  [self updateContent:YES];
}

- (void)reloadData
{
  [self clear]; // Clear views
  
  [_columnsBounds removeAllObjects];
  [_columnsFixed removeAllObjects];
  [_rowsBounds removeAllObjects];
  [_rowsFixed removeAllObjects];
  
  _fixedColumnsRange = NSMakeRange(NSNotFound, 0);
  _fixedRowsRange = NSMakeRange(NSNotFound, 0);

  [self updateContentSize];
  [self updateContent:NO];
}

- (void)clear
{
  @synchronized (self) {
    if (_paddingViewTop) {
      [_paddingViewTop removeFromSuperview];
      M_OBJECT_RELEASE(_paddingViewTop);
    }
    if (_paddingViewLeft) {
      [_paddingViewLeft removeFromSuperview];
      M_OBJECT_RELEASE(_paddingViewLeft);
    }
    if (_leftBackgroundView) {
      [_leftBackgroundView removeFromSuperview];
      M_OBJECT_RELEASE(_leftBackgroundView);
    }
    if (_headerBackgroundView) {
      [_headerBackgroundView removeFromSuperview];
      M_OBJECT_RELEASE(_headerBackgroundView);
    }
    
    [self.containerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

//    for (UIView *it in self.subviews) {
//      if (![it isKindOfClass:[UIRefreshControl class]]) {
//        [it removeFromSuperview];
//      }
//    }
    
    // Complete clear event
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewClear:)]) {
      [self.delegate tableViewClear:self];
    }
  }
}

- (void)updateContent:(BOOL)updateAll
{
  if (self.hideColumnsIfEmpty && self.rowsCount < 1) {
    // Complete update event
    if (self.delegate
        && [self.delegate respondsToSelector:@selector(tableViewUpdateContentComplete:updateAll:)]) {
      [self.delegate tableViewUpdateContentComplete:self updateAll:updateAll];
    }
    return;
  }
  
  NSRange columns = updateAll ? NSMakeRange(0, self.columnsCount) : [self visibleColumnsRange];
  NSRange rows = updateAll ? NSMakeRange(0, self.rowsCount) : [self visibleRowsRange];
  NSUInteger endCl = columns.location + columns.length;
  NSUInteger endEl = rows.location + rows.length;
  NSUInteger cI = columns.location;

  //
  // Update column positions and create views if necessary
  //
  if (endCl > 0) {
    for (NSUInteger i = cI ; i < endCl ; i++) {
      // Update cells in rows
      for (NSUInteger j = rows.location ; j < endEl ; j++) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
        UIView *cell = [self cellAtIndexPath:path];
        if (updateAll) {
          [cell setFrame:[self cellRectAtIndexPath:path xOffset:0 yOffset:0]];
        }
        
        // Prepare row
        if (i == cI) {
          if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:prepareRowAtIndex:)]) {
            [self.delegate tableView:self prepareRowAtIndex:j];
          }
        }
      }
      
      // Update column
      UIView *coll = [self columnAtIndex:i];
      if (updateAll) {
        [coll setFrame:[self columnRectAtIndex:i xOffset:0]];
      }
      
      // Prepare column
      if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:prepareColumnAtIndex:)]) {
        [self.delegate tableView:self prepareColumnAtIndex:i];
      }
    }
  }
  
  // Move header to front
  [self bringSubviewToFront:self.headerBackgroundView];

  // Update fixed fields
  if (self.isFixedColumnRow) {
    [self updateFixedColumns:columns rows:rows];
  }
  
  // Columns to front
  [self bringSubviewToFront:self.headerBackgroundView];
  
  // Update layout positions
  [self updateBackgroundViews];
  
  // Update left&top border
  if (_tablePadding > 0.f) {
    const CGFloat top = self.contentOffset.y;
    UIView *padding = self.paddingViewLeft;
    if (padding) {
      const CGFloat left = self.contentOffset.x;
      padding.frame = CGRectMake(0, top, (left > 0 ? left : 0)+_tablePadding, self.contentSize.height);
      padding.alpha = 1.f;
      [self bringSubviewToFront:padding];
    }
    
    padding = self.paddingViewTop;
    if (padding) {
      padding.frame = CGRectMake(0, top, self.contentSize.width, _tablePadding);
      padding.alpha = 1.f;
      [self bringSubviewToFront:padding];
    }
  } else {
    self.paddingViewLeft.alpha = 0;
    self.paddingViewTop.alpha = 0;
  }
  
  // Complete update event
  if (self.delegate
  && [self.delegate respondsToSelector:@selector(tableViewUpdateContentComplete:updateAll:)]) {
    [self.delegate tableViewUpdateContentComplete:self updateAll:updateAll];
  }
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
    CGFloat xOffset = 0; // ADCV: _tablePadding;
    CGFloat yOffset = 0; // ADCV: _tablePadding;
    endCl = MAX(columns.location + columns.length, endCl);
    
    for (NSInteger i = columns.location ; i < endCl ; i++) {
      if ([self isFixedColumn:i]) {
        CGRect cframe;
        
        // Update cells in rows
        for (NSUInteger j = rows.location ; j < endEl ; j++) {
          NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
          UIView *cell = [self cellAtIndexPath:path];
          cframe = [self cellRectAtIndexPath:path xOffset:xOffset yOffset:yOffset];
          cell.frame = cframe;
          yOffset = cframe.origin.y + cframe.size.height + _itemMargin - self.contentOffset.y;
          [self bringSubviewToFront:cell];
        }
        
        // Update column
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
    CGFloat xOffset = 0; // ADCV: _tablePadding;
    CGFloat yOffset = 0; // ADCV: _tablePadding;
    const NSUInteger endEl = rows.location + rows.length;
    
    // Update cells in rows
    for (NSUInteger j = rows.location ; j < endEl ; j++) {
      if ([self isFixedRow:j]) {
        CGRect cframe;
        for (NSUInteger i = cI ; i < endCl ; i++) {
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
    CGFloat yOffset = 0;
    if (self.isStrictFixedColumnRow) {
      yOffset = self.contentOffset.y;
    } else if (self.isFixedColumnRow) {
      yOffset = self.contentOffset.y < 0.f ? 0 : self.contentOffset.y;
    }
    CGRect topColumnsFrame = CGRectMake(0, yOffset, self.contentSize.width,
                                        _tablePadding + self.columnsHeight + _itemMargin);
    if (self.zoomScale != 1.f) {
      topColumnsFrame.origin.y /= self.zoomScale;
      topColumnsFrame.size.width *= self.zoomScale;
    }
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
  UIView *cell = [self dequeueReusableCellWithIdentifier:@"Cell" indexPath:indexPath];
  if (nil == cell) {
    if ([self.delegate respondsToSelector:@selector(tableView:cellAtIndexPath:)]) {
      cell = [self.delegate tableView:self cellAtIndexPath:indexPath];
      if (cell.superview != self) {
        [self tableViewCellPrepare:cell atIndexPath:indexPath];
      }
    } else if ([_dataSource respondsToSelector:@selector(tableView:textForCellAtIndexPath:)]) {
      cell = [[UILabel alloc] init];
      id value = [_dataSource tableView:self textForCellAtIndexPath:indexPath];
      if ([value isKindOfClass:[NSString class]]) {
        ((UILabel *)cell).text = value;
      } else {
        ((UILabel *)cell).text = [NSString stringWithFormat:@"%@", value];
      }
      [self tableViewCellPrepare:cell atIndexPath:indexPath];
    }
  }
  return cell;
}

- (void)setItemMargin:(CGFloat)itemMargin
{
  if (_itemMargin != itemMargin) {
    _itemMargin = itemMargin;
    [self updateContentSize];
    [self updateContent:YES];
  }
}

- (void)setTablePadding:(CGFloat)tablePadding
{
  if (_tablePadding != tablePadding) {
    _tablePadding = tablePadding;
    [self updateContentSize];
    [self updateContent:YES];
  }
}

- (UIView *)containerView
{
  if (nil == _containerView) {
    _containerView = [[UIView alloc] initWithFrame:self.frame];
    _containerView.clipsToBounds = YES;
    _containerView.backgroundColor = [UIColor clearColor];
    [self addSubview:_containerView];
  }
  return _containerView;
}

- (UIView *)headerBackgroundView
{
  if (nil == _headerBackgroundView) {
    _headerBackgroundView = [[UIView alloc] init];
    [self.containerView addSubview:_headerBackgroundView];
  }
  return _headerBackgroundView;
}

- (UIView *)leftBackgroundView
{
  if (nil == _leftBackgroundView) {
    _leftBackgroundView = [[UIView alloc] init];
    [self.containerView addSubview:_leftBackgroundView];
  }
  return _leftBackgroundView;
}

- (UIView *)paddingViewLeft
{
  if (_tablePadding > 0.f && self.hasFixedColumns && [self isFixedColumn:0]) {
    if (nil == _paddingViewLeft) {
      _paddingViewLeft = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tablePadding, self.frame.size.height)];
      _paddingViewLeft.autoresizingMask = UIViewAutoresizingFlexibleHeight;
      _paddingViewLeft.backgroundColor = prepareBackgroundPadding(self.backgroundColor);
      [self addSubview:_paddingViewLeft];
      [self bringSubviewToFront:_paddingViewLeft];
    }
  } else if (_paddingViewLeft) {
    _paddingViewLeft.alpha = 0.f;
    return nil;
  }
  return _paddingViewLeft;
}

- (UIView *)paddingViewTop
{
  if (_tablePadding > 0.f && self.isFixedColumnRow) {
    if (nil == _paddingViewTop) {
      _paddingViewTop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, _tablePadding)];
      _paddingViewTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      _paddingViewTop.backgroundColor = prepareBackgroundPadding(self.backgroundColor);
      [self addSubview:_paddingViewTop];
      [self bringSubviewToFront:_paddingViewTop];
    }
  } else if (_paddingViewTop) {
    _paddingViewTop.alpha = 0.f;
    return nil;
  }
  return _paddingViewTop;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  [super setBackgroundColor:backgroundColor];
  self.paddingViewLeft.backgroundColor = prepareBackgroundPadding(backgroundColor);
  self.paddingViewTop.backgroundColor = prepareBackgroundPadding(backgroundColor);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Detecting
////////////////////////////////////////////////////////////////////////////////

- (BOOL)isFixedColumnRow
{
  if ([self.delegate respondsToSelector:@selector(tableViewHasFixedColumnRow:)]) {
    return [self.delegate tableViewHasFixedColumnRow:self];
  }
  return [self isStrictFixedColumnRow];
}

- (BOOL)isStrictFixedColumnRow
{
  return [self.delegate respondsToSelector:@selector(tableViewHasStrictFixedColumnRow:)]
      && [self.delegate tableViewHasStrictFixedColumnRow:self];
}

- (BOOL)hasFixedColumns
{
  if (self.delegate
  && [self.delegate respondsToSelector:@selector(tableViewHasFixedColumns:)]) {
    return [self.delegate tableViewHasFixedColumns:self];
  }
  return NO;
}

- (BOOL)hasFixedRows
{
  if (self.delegate &&
      [self.delegate respondsToSelector:@selector(tableViewHasFixedRows:)]) {
    return [self.delegate tableViewHasFixedRows:self];
  }
  return NO;
}

- (BOOL)isFixedColumn:(NSInteger)index
{
  if (_columnsFixed && [_columnsFixed containsObject:@(index)]) {
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
  if (_rowsFixed && [_rowsFixed containsObject:@(index)]) {
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
  if (!self.hasFixedColumns || NSNotFound == range.location) {
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
  
  if (maxCount < 1) {
    return range;
  }
  
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
    range.length = (NSUInteger)ceil(self.frame.size.width / columnWidth) + (divCell != 0 ? 1 : 0);
    
    // fix count
    if (range.location > maxCount) {
      range.location = 0;
      range.length = 0;
    } else if (range.location + range.length > maxCount) {
      range.length = maxCount - range.location;
    }
  } else {
    bool setted = false;
    CGFloat offset = 0;
    range.length = maxCount;
    for (NSUInteger i = 0 ; i < maxCount ; i++) {
      offset += [self columnWidthAtIndex:i] + _itemMargin;
      if (offset > scrOffset && !setted) {
        range.location = i;
        setted = true;
      } else if (offset > scrOffset + self.frame.size.width) {
        range.length = i - range.location + 1;
        break;
      }
    }
    // fix count
    if (range.location + range.length >= maxCount) {
      range.length = maxCount - range.location;
    }
  }
  return range;
}

- (NSRange)visibleRowsRange
{
  NSRange range = NSMakeRange(0, 0);
  const NSInteger maxCount = self.rowsCount;
  
  if (maxCount < 1) {
    return range;
  }
  
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
    range.length = (NSUInteger)ceil(self.frame.size.height / rowHeight) + (divCell != 0 ? 1 : 0);
    
    // fix count
    if (range.location > maxCount) {
      range.location = 0;
      range.length = 0;
    } else if (range.location + range.length > maxCount) {
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
    if (range.location + range.length > maxCount) {
      range.length = maxCount - range.location;
    }
  }
  return range;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Events
////////////////////////////////////////////////////////////////////////////////

- (void)columnViewTapped:(id)sender
{
  UIView *view = ((UIGestureRecognizer *)sender).view;
  [self tableViewTapColumn:view index:[self indexForColumn:view]];
}

- (void)tableViewTapColumn:(UIView *)column index:(NSInteger)index
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:tapColumn:index:)]) {
    [self.delegate tableView:self tapColumn:column index:index];
  }
}

- (void)cellViewTapped:(id)sender
{
  UIView *view = ((UIGestureRecognizer *)sender).view;
  CGPoint point = [self positionForCell:view];
  [self tableViewTapCell:view indexPath:[NSIndexPath indexPathForRow:point.x column:point.y]];
}

- (void)tableViewTapCell:(UIView *)cell indexPath:(NSIndexPath *)indexPath
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:tapCell:indexPath:)]) {
    [self.delegate tableView:self tapCell:cell indexPath:indexPath];
  }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Metrics helpers
////////////////////////////////////////////////////////////////////////////////

- (CGSize)calculateContentSize
{
  CGSize size = CGSizeMake(_tablePadding*2, [self columnsHeight]+_itemMargin+_tablePadding*2);
  _columnStreatchComponent = 0.f;
  
  // Calc width by colums
  if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
    size.width = self.columnsCount * ([self columnWidthAtIndex:-1] + _itemMargin) - _itemMargin;
  } else {
    for (int i=0; i<self.columnsCount; i++) {
      size.width += [self columnWidthAtIndex:i] + _itemMargin;
    }
    size.width -= _itemMargin;
  }
  
  // Calculate additional size
  if (self.stretchTable && self.bounds.size.width > size.width) {
    _columnStreatchComponent = (self.bounds.size.width - size.width) / self.columnsCount;
    size.width = self.bounds.size.width;
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
//  if (size.height < self.frame.size.height) {
//    size.height = self.frame.size.height;
//  }
  
  if (size.width < self.frame.size.width) {
    size.width = self.frame.size.width;
  }
    
  return self.contentSizeCache = size;
}

- (UIEdgeInsets)calculateScrollIndicatorInsets
{
  UIEdgeInsets inserts = UIEdgeInsetsMake(0, 0, 0, 0);
  if ([self isStrictFixedColumnRow]) {
    inserts.top = [self columnsHeight] + _tablePadding;
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
  CGPoint point;
  NSString *key = [NSString stringWithFormat:@"%ld", (long)index];
  
  if (nil == _columnsBounds[key]) {
    CGFloat xOff = 0; // ADCV: _tablePadding;
    
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

- (CGPoint)columnBoundsAbs:(NSInteger)index
{
  CGPoint p = [self columnBounds:index];
  p.x += _tablePadding;
  return p;
}

/**
 * Get row Y position & HEIGH
 *
 * @param index
 * @return {y: Y, x: HEIGHT}
 */
- (CGPoint)rowBounds:(NSInteger)index
{
  CGPoint point;
  NSString *key = [NSString stringWithFormat:@"%ld", (long)index];
  
  if (nil == _rowsBounds[key]) {
    CGFloat yOff = [self columnsHeight] + _itemMargin; // ADCV: + _tablePadding;
    
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
  CGRect rect = CGRectMake(cPoint.x, 0/* ADCV: _tablePadding */, cPoint.y, [self columnsHeight]);
  
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

- (CGRect)columnRectAtIndexAbs:(NSInteger)index xOffset:(CGFloat)offset
{
  CGRect r = [self columnRectAtIndex:index xOffset:offset];
  r.origin.y += _tablePadding;
  return r;
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

- (CGRect)cellRectAtIndexPathAbs:(NSIndexPath *)indexPath xOffset:(CGFloat)xOffset yOffset:(CGFloat)yOffset
{
  CGRect r = [self cellRectAtIndexPath:indexPath xOffset:xOffset yOffset:yOffset];
  r.origin.y += _tablePadding;
  return r;
}

- (CGFloat)columnWidthAtIndex:(NSInteger)index
{
  CGFloat width = 44.f;
  if (self.delegate) {
    if ([self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
      width = [self.delegate tableView:self columnWidthAtIndex:index];
    }
    if ([self.delegate respondsToSelector:@selector(tableViewColumnWidth:)]) {
      width = [self.delegate tableViewColumnWidth:self];
    }
  }
  return width + _columnStreatchComponent;
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

- (NSInteger)indexForColumn:(UIView *)column
{
  return column.tag - 100000000;
}

- (CGPoint)positionForCell:(UIView *)cell
{
  const NSInteger start = cell.tag - 100000;
  return CGPointMake(start % 100000, floor(start / 100000));
}

- (void)tableViewColumnPrepare:(UIView *)column atIndex:(NSInteger)index
{
  if (column.superview != self.headerBackgroundView) {
    column.tag = [self tagForColumnAtIndex:index];
    column.frame = [self columnRectAtIndex:index xOffset:0];
    
    // TODO: Add event handler
    [self.headerBackgroundView addSubview:column];
    [self bringSubviewToFront:column];
    
    // Prepare column view at index
    if (self.delegate &&
       [self.delegate respondsToSelector:@selector(tableView:prepareColumnView:atIndex:)])
    {
      [self.delegate tableView:self prepareColumnView:column atIndex:index];
    }
    
    // Bind tap event
    column.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(columnViewTapped:)];
    tap.cancelsTouchesInView = YES;
    [column addGestureRecognizer:tap];
  }
}

- (void)tableViewCellPrepare:(UIView *)cell atIndexPath:(NSIndexPath *)indexPath
{
  if (cell.superview != self) {
    cell.tag = [self tagForCellAtIndexPath:indexPath];
    cell.frame = [self cellRectAtIndexPath:indexPath xOffset:0 yOffset:0];
    // TODO: Add event handler
    [self.containerView addSubview:cell];
    [self.containerView sendSubviewToBack:cell];
    
    // Prepare column view at index
    if (self.delegate &&
       [self.delegate respondsToSelector:@selector(tableView:prepareCellView:atIndexPath:)])
    {
      [self.delegate tableView:self prepareCellView:cell atIndexPath:indexPath];
    }
    
    // Bind tap event
    cell.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellViewTapped:)];
    tap.cancelsTouchesInView = YES;
    [cell addGestureRecognizer:tap];
  }
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

