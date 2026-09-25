import 'paging_status.dart';

/// The loaded items, the current error and the next page's key.
///
/// Immutable; a `PagingController` replaces it on every change.
class PagingState<PageKeyType, ItemType> {
  const PagingState({this.nextPageKey, this.itemList, this.error});

  /// Every item loaded so far, or `null` before the first page arrives.
  final List<ItemType>? itemList;

  /// The error of the last failed request, if any.
  final dynamic error;

  /// The key of the next page to request; `null` after the last page.
  final PageKeyType? nextPageKey;

  /// The current status, computed from the three fields.
  PagingStatus get status {
    final count = itemList?.length;
    final hasItems = count != null && count > 0;
    final hasNextPage = nextPageKey != null;
    final hasError = error != null;
    if (hasItems && hasNextPage && !hasError) return PagingStatus.ongoing;
    if (hasItems && !hasNextPage) return PagingStatus.completed;
    if (count == null && !hasError) return PagingStatus.loadingFirstPage;
    if (hasItems && hasNextPage && hasError) {
      return PagingStatus.subsequentPageError;
    }
    if (count == 0) return PagingStatus.noItemsFound;
    return PagingStatus.firstPageError;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagingState &&
          other.itemList == itemList &&
          other.error == error &&
          other.nextPageKey == nextPageKey;

  @override
  int get hashCode => Object.hash(itemList, error, nextPageKey);

  @override
  String toString() =>
      'PagingState(itemList: $itemList, error: $error, '
      'nextPageKey: $nextPageKey)';
}
