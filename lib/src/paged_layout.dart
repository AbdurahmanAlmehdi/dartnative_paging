import 'package:dartnative/dartnative.dart';

import 'default_indicators.dart';
import 'next_page_trigger.dart';
import 'paged_child_builder_delegate.dart';
import 'paged_rows.dart';
import 'paging_controller.dart';
import 'paging_status.dart';

/// What the paged widgets share: rebuild on controller changes, show the
/// status builders, and lay loaded items out as rows for a concrete list.
abstract class PagedLayoutState<W extends StatefulWidget, PageKeyType, ItemType>
    extends State<W> {
  PagingController<PageKeyType, ItemType> get pagingController;
  PagedChildBuilderDelegate<ItemType> get builderDelegate;
  IndexedWidgetBuilder? get separatorBuilder;
  int? get invisibleItemsThreshold;
  EdgeInsetsGeometry? get padding;

  /// Builds the scrolling list for [rows]; [buildRow] builds any row.
  Widget buildList(
    BuildContext context,
    PagedRows rows,
    IndexedWidgetBuilder buildRow,
  );

  /// Called after every controller change, once the frame is built.
  void didChangePages() {}

  /// The rows of the list as last built.
  PagedRows get rows => _rows;
  PagedRows _rows = const PagedRows(
    itemCount: 0,
    separated: false,
    hasFooter: false,
  );

  int get threshold =>
      invisibleItemsThreshold ??
      pagingController.invisibleItemsThreshold ??
      defaultInvisibleItemsThreshold;

  /// Requests the next page if the row [lastVisibleRow] is close enough to
  /// the end. Double requests are dropped by the controller.
  void requestIfNear(int lastVisibleRow) {
    if (lastVisibleRow < 0 || _rows.rowCount == 0) return;
    final row = lastVisibleRow >= _rows.rowCount
        ? _rows.rowCount - 1
        : lastVisibleRow;
    final itemIndex = _rows.itemIndexOf(row);
    if (shouldRequestNextPage(itemIndex, _rows.itemCount, threshold)) {
      pagingController.requestNextPage();
    }
  }

  @override
  void initState() {
    super.initState();
    pagingController.addListener(_onPagesChanged);
  }

  void updatePagingController(PagingController<PageKeyType, ItemType> old) {
    if (identical(old, pagingController)) return;
    old.removeListener(_onPagesChanged);
    pagingController.addListener(_onPagesChanged);
  }

  @override
  void dispose() {
    pagingController.removeListener(_onPagesChanged);
    super.dispose();
  }

  void _onPagesChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) didChangePages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = pagingController;
    final delegate = builderDelegate;
    switch (controller.status) {
      case PagingStatus.loadingFirstPage:
        // The first page is asked for by being shown, as in v4.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) pagingController.requestNextPage();
        });
        return _padded(
          (delegate.firstPageProgressIndicatorBuilder ??
              defaultFirstPageProgress)(context),
        );
      case PagingStatus.firstPageError:
        final builder = delegate.firstPageErrorIndicatorBuilder;
        return _padded(
          builder != null
              ? builder(context)
              : defaultFirstPageError(
                  context,
                  controller.retryLastFailedRequest,
                ),
        );
      case PagingStatus.noItemsFound:
        return _padded(
          (delegate.noItemsFoundIndicatorBuilder ?? defaultNoItemsFound)(
            context,
          ),
        );
      case PagingStatus.ongoing:
      case PagingStatus.completed:
      case PagingStatus.subsequentPageError:
        return _buildItems(context, controller.itemList ?? const []);
    }
  }

  Widget _buildItems(BuildContext context, List<ItemType> items) {
    final footer = _footerBuilder();
    final separator = separatorBuilder;
    _rows = PagedRows(
      itemCount: items.length,
      separated: separator != null,
      hasFooter: footer != null,
    );
    final rows = _rows;
    return buildList(context, rows, (context, row) {
      switch (rows.kindOf(row)) {
        case PagedRowKind.footer:
          return footer!(context);
        case PagedRowKind.separator:
          return separator!(context, rows.itemIndexOf(row));
        case PagedRowKind.item:
          final index = rows.itemIndexOf(row);
          return builderDelegate.itemBuilder(context, items[index], index);
      }
    });
  }

  WidgetBuilder? _footerBuilder() {
    final delegate = builderDelegate;
    switch (pagingController.status) {
      case PagingStatus.ongoing:
        return delegate.newPageProgressIndicatorBuilder ??
            defaultNewPageProgress;
      case PagingStatus.subsequentPageError:
        return delegate.newPageErrorIndicatorBuilder ??
            (context) => defaultNewPageError(
              context,
              pagingController.retryLastFailedRequest,
            );
      case PagingStatus.completed:
        return delegate.noMoreItemsIndicatorBuilder;
      case PagingStatus.loadingFirstPage:
      case PagingStatus.firstPageError:
      case PagingStatus.noItemsFound:
        return null;
    }
  }

  Widget _padded(Widget child) {
    final insets = padding;
    return insets == null ? child : Padding(padding: insets, child: child);
  }
}
