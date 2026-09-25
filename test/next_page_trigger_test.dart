import 'package:paging_kit/paging_kit.dart';
import 'package:paging_kit/src/paged_rows.dart';
import 'package:test/test.dart';

void main() {
  group('shouldRequestNextPage', () {
    test('fires once the last visible item reaches itemCount - threshold', () {
      expect(shouldRequestNextPage(13, 20, 5), isFalse);
      expect(shouldRequestNextPage(14, 20, 5), isFalse);
      expect(shouldRequestNextPage(15, 20, 5), isTrue);
      expect(shouldRequestNextPage(19, 20, 5), isTrue);
    });

    test('the footer index (== itemCount) always fires', () {
      expect(shouldRequestNextPage(20, 20, 5), isTrue);
      expect(shouldRequestNextPage(3, 3, 0), isTrue);
    });

    test('a list shorter than the threshold fires from the top', () {
      expect(shouldRequestNextPage(0, 3, 5), isTrue);
    });

    test('never fires without items or a visible index', () {
      expect(shouldRequestNextPage(0, 0, 5), isFalse);
      expect(shouldRequestNextPage(-1, 20, 5), isFalse);
    });

    test('a negative threshold behaves as zero', () {
      expect(shouldRequestNextPage(18, 20, -3), isFalse);
      expect(shouldRequestNextPage(20, 20, -3), isTrue);
    });

    test('the default threshold is 5', () {
      expect(defaultInvisibleItemsThreshold, 5);
    });
  });

  group('PagedRows', () {
    test('plain rows are items plus an optional footer', () {
      const rows = PagedRows(itemCount: 3, separated: false, hasFooter: true);
      expect(rows.rowCount, 4);
      expect([for (var r = 0; r < 4; r++) rows.kindOf(r)], [
        PagedRowKind.item,
        PagedRowKind.item,
        PagedRowKind.item,
        PagedRowKind.footer,
      ]);
      expect([for (var r = 0; r < 4; r++) rows.itemIndexOf(r)], [0, 1, 2, 3]);
    });

    test('separated rows interleave separators between items only', () {
      const rows = PagedRows(itemCount: 3, separated: true, hasFooter: true);
      expect(rows.rowCount, 6);
      expect([for (var r = 0; r < 6; r++) rows.kindOf(r)], [
        PagedRowKind.item,
        PagedRowKind.separator,
        PagedRowKind.item,
        PagedRowKind.separator,
        PagedRowKind.item,
        PagedRowKind.footer,
      ]);
      expect([for (var r = 0; r < 6; r++) rows.itemIndexOf(r)], [
        0,
        0,
        1,
        1,
        2,
        3,
      ]);
    });

    test('no footer and no items means no rows', () {
      const rows = PagedRows(itemCount: 0, separated: true, hasFooter: false);
      expect(rows.rowCount, 0);
    });

    test('separated rows without a footer end on an item', () {
      const rows = PagedRows(itemCount: 2, separated: true, hasFooter: false);
      expect(rows.rowCount, 3);
      expect(rows.kindOf(2), PagedRowKind.item);
      expect(rows.itemIndexOf(2), 1);
    });
  });
}
