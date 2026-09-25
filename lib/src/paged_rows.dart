/// What a row of a paged list shows.
enum PagedRowKind { item, separator, footer }

/// Maps list rows to items, separators and the trailing footer, so the
/// widgets stay thin and the mapping is testable without a device.
class PagedRows {
  const PagedRows({
    required this.itemCount,
    required this.separated,
    required this.hasFooter,
  });

  /// Loaded items.
  final int itemCount;

  /// Whether a separator sits between neighbouring items.
  final bool separated;

  /// Whether a last row (loading, error or no-more-items) follows the items.
  final bool hasFooter;

  /// Rows handed to the list.
  int get rowCount {
    final itemRows = separated && itemCount > 0 ? itemCount * 2 - 1 : itemCount;
    return itemRows + (hasFooter ? 1 : 0);
  }

  /// What row [row] shows.
  PagedRowKind kindOf(int row) {
    if (hasFooter && row == rowCount - 1) return PagedRowKind.footer;
    if (separated && row.isOdd) return PagedRowKind.separator;
    return PagedRowKind.item;
  }

  /// The item a row shows or follows (a separator maps to the item above it,
  /// the footer to [itemCount]).
  int itemIndexOf(int row) {
    if (hasFooter && row == rowCount - 1) return itemCount;
    return separated ? row ~/ 2 : row;
  }
}
