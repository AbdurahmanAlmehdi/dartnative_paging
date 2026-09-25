import 'package:dartnative/dartnative.dart';

/// Builds one item of a paged list.
typedef ItemWidgetBuilder<ItemType> =
    Widget Function(BuildContext context, ItemType item, int index);

/// The builders of a paged list: one for items and one per status.
///
/// Same names as `infinite_scroll_pagination` 4. Each status builder falls
/// back to a plain default when null.
class PagedChildBuilderDelegate<ItemType> {
  const PagedChildBuilderDelegate({
    required this.itemBuilder,
    this.firstPageErrorIndicatorBuilder,
    this.newPageErrorIndicatorBuilder,
    this.firstPageProgressIndicatorBuilder,
    this.newPageProgressIndicatorBuilder,
    this.noItemsFoundIndicatorBuilder,
    this.noMoreItemsIndicatorBuilder,
  });

  /// Builds the item at `index`.
  final ItemWidgetBuilder<ItemType> itemBuilder;

  /// Shown in place of the list when the first page fails.
  final WidgetBuilder? firstPageErrorIndicatorBuilder;

  /// Shown below the items when a later page fails.
  final WidgetBuilder? newPageErrorIndicatorBuilder;

  /// Shown in place of the list while the first page loads.
  final WidgetBuilder? firstPageProgressIndicatorBuilder;

  /// Shown below the items while a later page loads.
  final WidgetBuilder? newPageProgressIndicatorBuilder;

  /// Shown in place of the list when the first page is empty.
  final WidgetBuilder? noItemsFoundIndicatorBuilder;

  /// Shown below the items after the last page. Nothing when null.
  final WidgetBuilder? noMoreItemsIndicatorBuilder;
}
