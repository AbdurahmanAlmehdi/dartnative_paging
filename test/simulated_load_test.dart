import 'dart:async';

import 'package:paging_kit/paging_kit.dart';
import 'package:test/test.dart';

const total = 300;
const pageSize = 20;

/// A backend with [total] rows, served [pageSize] at a time by offset.
class FakeBackend {
  final requests = <int>[];

  Future<({List<String> items, int? next})> fetch(int offset) async {
    requests.add(offset);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final end = (offset + pageSize).clamp(0, total);
    return (
      items: [for (var i = offset; i < end; i++) 'Row ${i + 1}'],
      next: end < total ? end : null,
    );
  }
}

/// The same fetcher shape as the app's `_fetchPage`.
void wire(PagingController<int, String> controller, FakeBackend backend) {
  controller.addPageRequestListener((offset) async {
    final page = await backend.fetch(offset);
    if (page.next == null) {
      controller.appendLastPage(page.items);
    } else {
      controller.appendPage(page.items, page.next);
    }
  });
}

/// Scrolls a 10-row viewport down the list the way the widget does: every
/// scroll step reports the last visible row, and a request is made when it
/// is within the threshold of the end.
Future<void> scrollToEnd(PagingController<int, String> controller) async {
  var lastVisible = 9;
  for (var step = 0; step < 10000; step++) {
    final count = controller.itemList?.length ?? 0;
    if (count == 0) {
      controller.requestNextPage(); // the first page, as the widget does
    } else if (shouldRequestNextPage(lastVisible, count, 5)) {
      // Several scroll events land while one page is loading.
      controller.requestNextPage();
      controller.requestNextPage();
    }
    if (controller.status == PagingStatus.completed &&
        lastVisible >= count - 1) {
      return;
    }
    if (lastVisible < count) lastVisible++;
    await Future<void>.delayed(Duration.zero);
  }
  fail('never reached the end');
}

void main() {
  test('300 rows load 20 at a time, in order, none twice or skipped', () async {
    final controller = PagingController<int, String>(firstPageKey: 0);
    final backend = FakeBackend();
    wire(controller, backend);

    await scrollToEnd(controller);

    final items = controller.itemList!;
    expect(backend.requests, [for (var o = 0; o < total; o += pageSize) o]);
    expect(backend.requests, hasLength(15));
    expect(items, hasLength(total));
    expect(items.toSet(), hasLength(total));
    expect(items, [for (var i = 1; i <= total; i++) 'Row $i']);
    expect(controller.status, PagingStatus.completed);
  });

  test('a refresh mid-load still ends with 300 unique rows', () async {
    final controller = PagingController<int, String>(firstPageKey: 0);
    final backend = FakeBackend();
    wire(controller, backend);

    controller.requestNextPage();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.requestNextPage(); // page 2 in flight...
    controller.refresh(); // ...and dropped when it lands
    await scrollToEnd(controller);

    final items = controller.itemList!;
    expect(items, [for (var i = 1; i <= total; i++) 'Row $i']);
    expect(controller.generation, 1);
  });
}
