import 'package:dartnative/dartnative.dart';

import 'paged_child_builder_delegate.dart';
import 'paged_layout.dart';
import 'paged_rows.dart';
import 'paging_controller.dart';

/// A paged list on DartNative's `FastList` (native cell recycling).
///
/// Shows [builderDelegate]'s status builders and asks [pagingController] for
/// the next page once the last visible item is within
/// [invisibleItemsThreshold] (default 5) of the end.
class PagedFastList<PageKeyType, ItemType> extends StatefulWidget {
  const PagedFastList({
    super.key,
    required this.pagingController,
    required this.builderDelegate,
    this.controller,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.showScrollBar = false,
    this.keepAliveCount,
    this.stableItems = false,
    this.invisibleItemsThreshold,
    this.onScroll,
    this.onVisibleRange,
  }) : separatorBuilder = null;

  /// Puts [separatorBuilder]'s widget between neighbouring items.
  const PagedFastList.separated({
    super.key,
    required this.pagingController,
    required this.builderDelegate,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.controller,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.showScrollBar = false,
    this.keepAliveCount,
    this.stableItems = false,
    this.invisibleItemsThreshold,
    this.onScroll,
    this.onVisibleRange,
  });

  final PagingController<PageKeyType, ItemType> pagingController;
  final PagedChildBuilderDelegate<ItemType> builderDelegate;

  /// Builds the separator after the item at `index`.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Passed to `FastList.controller` for `jumpToItem` / `scrollToItem`.
  /// Indexes count rows, so with separators item `i` is row `2 * i`.
  final FastListController? controller;

  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool showScrollBar;

  /// See `FastList.keepAliveCount`.
  final int? keepAliveCount;

  /// See `FastList.stableItems`. Leave it off if items change in place or
  /// the footer switches between loading and error.
  final bool stableItems;

  /// Overrides `PagingController.invisibleItemsThreshold`.
  final int? invisibleItemsThreshold;

  /// Passed through to `FastList.onScroll` (closing swipe actions, hiding
  /// a FAB). Paging doesn't need it.
  final FastScrollCallback? onScroll;

  /// Passed through to `FastList.onVisibleRange`, in row indexes.
  final void Function(int firstVisible, int lastVisible)? onVisibleRange;

  @override
  State<PagedFastList<PageKeyType, ItemType>> createState() =>
      _PagedFastListState<PageKeyType, ItemType>();
}

class _PagedFastListState<PageKeyType, ItemType>
    extends
        PagedLayoutState<
          PagedFastList<PageKeyType, ItemType>,
          PageKeyType,
          ItemType
        > {
  int _lastVisibleRow = -1;

  @override
  PagingController<PageKeyType, ItemType> get pagingController =>
      widget.pagingController;
  @override
  PagedChildBuilderDelegate<ItemType> get builderDelegate =>
      widget.builderDelegate;
  @override
  IndexedWidgetBuilder? get separatorBuilder => widget.separatorBuilder;
  @override
  int? get invisibleItemsThreshold => widget.invisibleItemsThreshold;
  @override
  EdgeInsetsGeometry? get padding => widget.padding;

  @override
  void didUpdateWidget(covariant PagedFastList<PageKeyType, ItemType> old) {
    super.didUpdateWidget(old);
    updatePagingController(old.pagingController);
  }

  // onVisibleRange fires on a range change only, so a page that lands while
  // the end is already on screen is followed up from the last known range.
  @override
  void didChangePages() {
    if (pagingController.itemList == null) _lastVisibleRow = -1;
    requestIfNear(_lastVisibleRow);
  }

  void _onVisibleRange(int first, int last) {
    _lastVisibleRow = last;
    requestIfNear(last);
    widget.onVisibleRange?.call(first, last);
  }

  @override
  Widget buildList(
    BuildContext context,
    PagedRows rows,
    IndexedWidgetBuilder buildRow,
  ) {
    return FastList(
      itemCount: rows.rowCount,
      itemBuilder: buildRow,
      controller: widget.controller,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      showScrollBar: widget.showScrollBar,
      keepAliveCount: widget.keepAliveCount,
      stableItems: widget.stableItems,
      onScroll: widget.onScroll,
      onVisibleRange: _onVisibleRange,
    );
  }
}
