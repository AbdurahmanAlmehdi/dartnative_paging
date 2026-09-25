import 'package:dartnative/dartnative.dart';

import 'paged_child_builder_delegate.dart';
import 'paged_layout.dart';
import 'paged_rows.dart';
import 'paging_controller.dart';

/// A paged list on DartNative's `ListView.builder`, for short lists or
/// layouts `FastList` can't host. `ListView.builder` builds every row
/// eagerly, so prefer `PagedFastList` for long lists.
///
/// With no visible-range callback here, the next page is requested when less
/// than one viewport of content remains below the scroll offset, or when the
/// content doesn't fill the viewport.
class PagedListView<PageKeyType, ItemType> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.pagingController,
    required this.builderDelegate,
    this.scrollController,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.showScrollBar = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  }) : separatorBuilder = null;

  /// Puts [separatorBuilder]'s widget between neighbouring items.
  const PagedListView.separated({
    super.key,
    required this.pagingController,
    required this.builderDelegate,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.scrollController,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.showScrollBar = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final PagingController<PageKeyType, ItemType> pagingController;
  final PagedChildBuilderDelegate<ItemType> builderDelegate;

  /// Builds the separator after the item at `index`.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Your own controller, e.g. to close swipe actions on scroll. One is
  /// created when null.
  final ScrollController? scrollController;

  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final bool showScrollBar;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  State<PagedListView<PageKeyType, ItemType>> createState() =>
      _PagedListViewState<PageKeyType, ItemType>();
}

class _PagedListViewState<PageKeyType, ItemType>
    extends
        PagedLayoutState<
          PagedListView<PageKeyType, ItemType>,
          PageKeyType,
          ItemType
        > {
  ScrollController? _ownScrollController;

  ScrollController get _scrollController =>
      widget.scrollController ??
      (_ownScrollController ??= ScrollController());

  @override
  PagingController<PageKeyType, ItemType> get pagingController =>
      widget.pagingController;
  @override
  PagedChildBuilderDelegate<ItemType> get builderDelegate =>
      widget.builderDelegate;
  @override
  IndexedWidgetBuilder? get separatorBuilder => widget.separatorBuilder;
  @override
  int? get invisibleItemsThreshold => null;
  @override
  EdgeInsetsGeometry? get padding => widget.padding;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PagedListView<PageKeyType, ItemType> old) {
    super.didUpdateWidget(old);
    updatePagingController(old.pagingController);
    final oldScroll = old.scrollController ?? _ownScrollController;
    if (!identical(oldScroll, _scrollController)) {
      oldScroll?.removeListener(_onScroll);
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _ownScrollController?.dispose();
    super.dispose();
  }

  @override
  void didChangePages() => _onScroll();

  void _onScroll() {
    final scroll = _scrollController;
    if (!scroll.hasClients || rows.rowCount == 0) return;
    final position = scroll.position;
    // Before the first layout the extents are all zero; wait for real ones.
    if (position.viewportDimension <= 0) return;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= position.viewportDimension) {
      pagingController.requestNextPage();
    }
  }

  @override
  Widget buildList(
    BuildContext context,
    PagedRows rows,
    IndexedWidgetBuilder buildRow,
  ) {
    return ListView.builder(
      itemCount: rows.rowCount,
      itemBuilder: buildRow,
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      shrinkWrap: widget.shrinkWrap,
      showScrollBar: widget.showScrollBar,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
    );
  }
}
