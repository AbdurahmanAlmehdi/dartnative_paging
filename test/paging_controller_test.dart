import 'dart:async';

import 'package:paging_kit/paging_kit.dart';
import 'package:test/test.dart';

PagingController<int, String> newController() =>
    PagingController<int, String>(firstPageKey: 0);

void main() {
  group('state and status', () {
    test('starts loading the first page with the first key', () {
      final controller = newController();
      expect(controller.itemList, isNull);
      expect(controller.error, isNull);
      expect(controller.nextPageKey, 0);
      expect(controller.status, PagingStatus.loadingFirstPage);
      expect(controller.isLoading, isFalse);
    });

    test('appendPage adds items, sets the key and notifies', () {
      final controller = newController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.appendPage(['a', 'b'], 1);

      expect(controller.itemList, ['a', 'b']);
      expect(controller.nextPageKey, 1);
      expect(controller.status, PagingStatus.ongoing);
      expect(notified, 1);
    });

    test('appendLastPage completes the list', () {
      final controller = newController()..appendPage(['a'], 1);
      controller.appendLastPage(['b']);
      expect(controller.itemList, ['a', 'b']);
      expect(controller.nextPageKey, isNull);
      expect(controller.status, PagingStatus.completed);
    });

    test('an empty last first page is noItemsFound', () {
      final controller = newController()..appendLastPage([]);
      expect(controller.status, PagingStatus.noItemsFound);
    });

    test('an error before any item is firstPageError', () {
      final controller = newController()..error = 'offline';
      expect(controller.status, PagingStatus.firstPageError);
    });

    test('an error after items is subsequentPageError', () {
      final controller = newController()..appendPage(['a'], 1);
      controller.error = 'offline';
      expect(controller.status, PagingStatus.subsequentPageError);
      expect(controller.itemList, ['a']);
    });

    test('appendPage clears a previous error', () {
      final controller = newController()..appendPage(['a'], 1);
      controller.error = 'offline';
      controller.appendPage(['b'], 2);
      expect(controller.error, isNull);
      expect(controller.status, PagingStatus.ongoing);
    });

    test('status listeners hear status changes only', () {
      final controller = newController();
      final statuses = <PagingStatus>[];
      controller.addStatusListener(statuses.add);
      controller
        ..appendPage(['a'], 1)
        ..appendPage(['b'], 2)
        ..appendLastPage(['c']);
      expect(statuses, [PagingStatus.ongoing, PagingStatus.completed]);
    });

    test('removed listeners are not called', () {
      final controller = newController();
      var notified = 0;
      void listener() => notified++;
      controller
        ..addListener(listener)
        ..removeListener(listener)
        ..appendPage(['a'], 1);
      expect(notified, 0);
    });

    test('fromValue starts from the given state', () {
      final controller = PagingController<int, String>.fromValue(
        const PagingState(itemList: ['a'], nextPageKey: 3),
        firstPageKey: 0,
      );
      expect(controller.status, PagingStatus.ongoing);
      controller.refresh();
      expect(controller.nextPageKey, 0);
      expect(controller.itemList, isNull);
    });
  });

  group('page requests', () {
    test('requestNextPage asks listeners for the next key', () {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);

      expect(controller.requestNextPage(), isTrue);
      expect(keys, [0]);
      expect(controller.isLoading, isTrue);
    });

    test('a second request while one is loading is dropped', () {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);

      controller.requestNextPage();
      expect(controller.requestNextPage(), isFalse);
      expect(keys, [0]);

      controller.appendPage(['a'], 1);
      expect(controller.isLoading, isFalse);
      expect(controller.requestNextPage(), isTrue);
      expect(keys, [0, 1]);
    });

    test('no request after the last page', () {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);
      controller.appendLastPage(['a']);
      expect(controller.requestNextPage(), isFalse);
      expect(keys, isEmpty);
    });

    test('no request without listeners, and no stuck loading flag', () {
      final controller = newController();
      expect(controller.requestNextPage(), isFalse);
      expect(controller.isLoading, isFalse);
    });

    test('no request while an error is shown', () {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);
      controller.requestNextPage();
      controller.error = 'offline';
      expect(controller.isLoading, isFalse);
      expect(controller.requestNextPage(), isFalse);
      expect(keys, [0]);
    });

    test('error then retry asks for the same page again', () async {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);

      controller.requestNextPage();
      controller.appendPage(['a'], 1);
      controller.requestNextPage();
      controller.error = 'offline';
      expect(controller.status, PagingStatus.subsequentPageError);

      controller.retryLastFailedRequest();
      expect(controller.error, isNull);
      expect(controller.status, PagingStatus.ongoing);
      await pumpEventQueue();

      expect(keys, [0, 1, 1]);
      controller.appendLastPage(['b']);
      expect(controller.itemList, ['a', 'b']);
    });

    test('a failing async listener becomes the error', () async {
      final controller = newController();
      controller.addPageRequestListener((key) async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('boom');
      });
      controller.requestNextPage();
      await pumpEventQueue();
      expect(controller.error, isA<StateError>());
      expect(controller.isLoading, isFalse);
      expect(controller.status, PagingStatus.firstPageError);
    });

    test('a throwing sync listener becomes the error', () {
      final controller = newController();
      controller.addPageRequestListener((key) => throw StateError('boom'));
      controller.requestNextPage();
      expect(controller.error, isA<StateError>());
    });

    test('removed page request listeners are not called', () {
      final controller = newController();
      final keys = <int>[];
      controller
        ..addPageRequestListener(keys.add)
        ..removePageRequestListener(keys.add);
      expect(controller.requestNextPage(), isFalse);
      expect(keys, isEmpty);
    });
  });

  group('refresh', () {
    test('resets to the first page and requests it', () async {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);
      controller.requestNextPage();
      controller.appendPage(['a', 'b'], 1);

      controller.refresh();
      expect(controller.itemList, isNull);
      expect(controller.nextPageKey, 0);
      expect(controller.status, PagingStatus.loadingFirstPage);
      expect(controller.generation, 1);

      await pumpEventQueue();
      expect(keys, [0, 0]);
    });

    test('several refreshes in one turn make one request', () async {
      final controller = newController();
      final keys = <int>[];
      controller.addPageRequestListener(keys.add);
      controller
        ..refresh()
        ..refresh()
        ..refresh();
      await pumpEventQueue();
      expect(keys, [0]);
    });

    test('drops a page from a fetch started before the refresh', () async {
      final controller = newController();
      final gates = <int, Completer<void>>{};
      var fetches = 0;
      controller.addPageRequestListener((key) async {
        final fetch = fetches++;
        final gate = gates[fetch] = Completer<void>();
        await gate.future;
        controller.appendPage(['fetch$fetch-page$key'], key + 1);
      });

      controller.requestNextPage(); // fetch 0, generation 0
      controller.refresh();
      await pumpEventQueue(); // fetch 1, generation 1
      expect(fetches, 2);

      gates[0]!.complete(); // the stale one lands first
      await pumpEventQueue();
      expect(controller.itemList, isNull);
      expect(controller.isLoading, isTrue);

      gates[1]!.complete();
      await pumpEventQueue();
      expect(controller.itemList, ['fetch1-page0']);
      expect(controller.isLoading, isFalse);
    });

    test('drops an error from a fetch started before the refresh', () async {
      final controller = newController();
      final gates = <Completer<void>>[];
      controller.addPageRequestListener((key) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        controller.error = 'late failure';
      });

      controller.requestNextPage();
      controller.refresh();
      await pumpEventQueue();

      gates.first.complete();
      await pumpEventQueue();
      expect(controller.error, isNull);
      expect(controller.status, PagingStatus.loadingFirstPage);
    });

    test('a stale async failure does not become the error', () async {
      final controller = newController();
      final gates = <Completer<void>>[];
      controller.addPageRequestListener((key) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        throw StateError('late');
      });
      controller.requestNextPage();
      controller.refresh();
      await pumpEventQueue();
      gates.first.complete();
      await pumpEventQueue();
      expect(controller.error, isNull);
    });

    test('changes from outside any fetch are always applied', () async {
      final controller = newController();
      controller.addPageRequestListener((_) {});
      controller.refresh();
      controller.appendPage(['manual'], null);
      expect(controller.itemList, ['manual']);
    });
  });

  group('dispose', () {
    test('a fetch that finishes after dispose is ignored', () async {
      final controller = newController();
      final gate = Completer<void>();
      controller.addPageRequestListener((key) async {
        await gate.future;
        controller.appendPage(['late'], 1);
      });
      controller.requestNextPage();
      controller.dispose();
      gate.complete();
      await pumpEventQueue();
      expect(controller.isDisposed, isTrue);
      expect(controller.itemList, isNull);
      expect(controller.requestNextPage(), isFalse);
    });
  });
}
