//
//  DMTableView.m
//  DMTableView
//
//  Created by Dmitry Ponomarev on 13/12/13.
//  Copyright (c) 2013 demdxx. All rights reserved.
//

#import "DMTableView.h"


////////////////////////////////////////////////////////////////////////////////
/// Hidden declaration
////////////////////////////////////////////////////////////////////////////////

@interface DMTableView ()

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
  NSMutableArray *_columnsPosition;
  NSMutableArray *_columnsFixed;
  NSMutableArray *_rowsPosition;
  NSMutableArray *_rowsFixed;
}

@synthesize dataSource = _dataSource;
@synthesize tablePadding = _tablePadding;
@synthesize itemMargin = _itemMargin;

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
  _columnsPosition = [NSMutableArray array];
  _columnsFixed = [NSMutableArray array];
  _rowsPosition = [NSMutableArray array];
  _rowsFixed = [NSMutableArray array];
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
  [_columnsPosition removeAllObjects];
  [_columnsFixed removeAllObjects];
  [_rowsPosition removeAllObjects];
  [_rowsFixed removeAllObjects];

  [self updateContentSize];
  [self updateContent];
}

- (void)updateContent
{
  NSRange colums = [self visibleColumnsRange];
  NSRange rows = [self visibleRowsRange];
  const NSUInteger endEl = rows.location + rows.length;
  const NSUInteger endCl = colums.location + colums.length;

  // Update column positions and create views if necessary
  for (int i = (int)colums.location ; i < endCl ; i++) {
    [[self columnAtIndex:i] setFrame:[self columnRectAtIndex:i]];
    // Update cells in rows
    for (int j = (int)rows.location ; j < endEl ; j++) {
      NSIndexPath *path = [NSIndexPath indexPathForRow:j column:i];
      [[self cellAtIndexPath:path] setFrame:[self cellRectAtIndexPath:path]];
    }
  }
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
    [self tableViewCellPrepare:cell atIndexPath:indexPath];
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark – Scroll Event
////////////////////////////////////////////////////////////////////////////////

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (
      ([self.delegate respondsToSelector:@selector(tableViewHasFixedColumns:)] && [self.delegate tableViewHasFixedColumns:self]) ||
      ([self.delegate respondsToSelector:@selector(tableViewHasFixedRows:)] && [self.delegate tableViewHasFixedRows:self])
      ) {
    // Recalc position
  }
  [self updateContent];
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark – Detecting
////////////////////////////////////////////////////////////////////////////////

- (NSRange)fixedColumnsRangeForRange:(NSRange)range
{
  return NSMakeRange(0, 0);
}

- (NSRange)fixedRpwsRangeForRange:(NSRange)range
{
  return NSMakeRange(0, 0);
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
    if (range.length > 0 && maxCount == range.length) {
      range.length = maxCount - range.location;
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
    if (range.length > 0 && maxCount == range.length) {
      range.length = maxCount - range.location;
    }
  }
  return range;
}

// Fixed fields range

- (NSRange)doCheckColumnsRange
{
  if (nil == self.delegate ||
      ![self.delegate respondsToSelector:@selector(tableView:isFixedColumn:)] ||
      (
        [self.delegate respondsToSelector:@selector(tableViewHasFixedColumns:)] &&
       ![self.delegate tableViewHasFixedColumns:self]
      ))
  {
    return NSMakeRange(0, 0);
  }

  NSRange range = [self visibleColumnsRange];
  for (int i = 0 ; i < range.location + range.length ; i++) {
    if ([self.delegate tableView:self isFixedColumn:i]) {
      range.location = (CGFloat)i;
      break;
    }
  }
  return range;
}

- (NSRange)doCheckRowsRange
{
  if (nil == self.delegate ||
      ![self.delegate respondsToSelector:@selector(tableView:isFixedRow:)] ||
      (
        [self.delegate respondsToSelector:@selector(tableViewHasFixedRows:)] &&
       ![self.delegate tableViewHasFixedColumns:self]
      ))
  {
    return NSMakeRange(0, 0);
  }
  
  NSRange range = [self visibleRowsRange];
  for (int i = 0 ; i < range.location + range.length ; i++) {
    if ([self.delegate tableView:self isFixedRow:i]) {
      range.location = (CGFloat)i;
      break;
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

- (CGRect)columnRectAtIndex:(NSInteger)index
{
  CGFloat wOffset = _tablePadding;
  CGFloat hOffset = _tablePadding;
  
  // Calc row "X" position
  if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
    wOffset += index * ([self columnWidthAtIndex:-1] + _itemMargin);
  } else {
    for (int i = 0; i < index ; i++) {
      wOffset += [self columnWidthAtIndex:i] + _itemMargin;
    }
  }
  
  if (self.delegate) {
    if ([self.delegate respondsToSelector:@selector(tableViewHasFixedColumnRow:)]) {
      hOffset += self.contentOffset.y;
    }
  }
  
  return CGRectMake(wOffset, hOffset, [self columnWidthAtIndex:index], [self columnsHeight]);
}

- (CGRect)cellRectAtIndexPath:(NSIndexPath *)indexPath
{
  CGFloat wOffset = _tablePadding;
  CGFloat hOffset = [self columnsHeight] + _itemMargin + _tablePadding;
  
  // Calc row "X" position
  if (![self.delegate respondsToSelector:@selector(tableView:columnWidthAtIndex:)]) {
    wOffset += indexPath.column * ([self columnWidthAtIndex:-1] + _itemMargin);
  } else {
    for (int i=0; i < indexPath.column ; i++) {
      wOffset += [self columnWidthAtIndex:i] + _itemMargin;
    }
  }
  
  // Calc row "Y" position
  if (![self.delegate respondsToSelector:@selector(tableView:rowHeightAtIndex:)]) {
    hOffset += indexPath.row * ([self rowHeightAtIndex:-1] + _itemMargin);
  } else {
    for (int i = 0 ; i < indexPath.row ; i++) {
      hOffset += [self rowHeightAtIndex:i] + _itemMargin;
    }
  }
  
  return CGRectMake(wOffset, hOffset, [self columnWidthAtIndex:indexPath.column], [self rowHeightAtIndex:indexPath.row]);
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
  if (column.superview != self) {
    column.tag = [self tagForColumnAtIndex:index];
    // TODO: Add event handler
    [self addSubview:column];
  }
  column.backgroundColor = 0 == index %2
                         ? [UIColor yellowColor]
                         : [UIColor magentaColor];
}

- (void)tableViewCellPrepare:(UIView *)cell atIndexPath:(NSIndexPath *)indexPath
{
  if (cell.superview != self) {
    cell.tag = [self tagForCellAtIndexPath:indexPath];
    // TODO: Add event handler
    [self addSubview:cell];
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

