# paging_kit

Infinite-scroll pagination for [DartNative](https://dartnative.com) apps.
It uses the API of
[`infinite_scroll_pagination`](https://pub.dev/packages/infinite_scroll_pagination)
**4** (`PagingController`, `addPageRequestListener`, `appendPage`,
`PagedChildBuilderDelegate`), so a Flutter list ports by renaming its widget.

```dart
// import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:paging_kit/paging_kit.dart';

// PagedListView<String, Trip>.separated(...)  becomes
PagedFastList<String, Trip>.separated(...)
```

## Why this package

- **Built on `FastList`.** Rows are native cells that get recycled
  (`UITableView` / `RecyclerView`).
- **v4's names.** The controller, the delegate and every builder keep their
  names. The fetcher code is unchanged.
- **One request at a time.** Scroll events that arrive while a page is
  loading don't send a second request.
- **Refresh drops old pages.** `refresh()` starts a new generation. A page
  requested before the refresh is discarded when it arrives, so a filter
  change can't mix old rows into new ones.

## Install

```yaml
dependencies:
  paging_kit:
    hosted: https://dartpub.dev
    version: ^0.1.0
```

Or from a local checkout:

```yaml
dependencies:
  paging_kit:
    path: ../dartnative_paging
```

## Use

```dart
class TripsList extends StatefulWidget {
  const TripsList({super.key});

  @override
  State<TripsList> createState() => _TripsListState();
}

class _TripsListState extends State<TripsList> {
  final _pagingController = PagingController<String, Trip>(firstPageKey: '');

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(String cursor) async {
    try {
      final page = await repository.fetchPage(cursor: cursor, limit: 20);
      if (page.nextCursor == null) {
        _pagingController.appendLastPage(page.items);
      } else {
        _pagingController.appendPage(page.items, page.nextCursor);
      }
    } on Failure catch (failure) {
      _pagingController.error = failure;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagedFastList<String, Trip>.separated(
      pagingController: _pagingController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      builderDelegate: PagedChildBuilderDelegate<Trip>(
        itemBuilder: (context, trip, index) => TripRow(trip: trip),
        firstPageProgressIndicatorBuilder: (_) => const ListSkeleton(),
        newPageProgressIndicatorBuilder: (_) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        firstPageErrorIndicatorBuilder: (_) => ErrorState(
          onRetry: _pagingController.retryLastFailedRequest,
        ),
        newPageErrorIndicatorBuilder: (_) => Button(
          title: 'Retry',
          onPressed: _pagingController.retryLastFailedRequest,
        ),
        noItemsFoundIndicatorBuilder: (_) => const EmptyState(),
      ),
    );
  }
}
```

Call `_pagingController.refresh()` when a filter changes. It clears the
list and requests the first page again.

### PagedListView

`PagedListView` / `PagedListView.separated` take the same arguments on
DartNative's `ListView.builder`. `ListView.builder` builds every row, so use
it only for short lists or where `FastList` can't go. It requests the next
page when less than one screen of content is left. Pass a `scrollController`
to observe scrolling yourself.

### Scroll hooks

`PagedFastList` passes `onScroll`, `onVisibleRange` and `controller`
(a `FastListController`) through to `FastList`. For example, you can close
open swipe actions on scroll. Row indexes count separators: with `.separated`,
item `i` is row `2 * i`.

## API

| paging_kit | infinite_scroll_pagination 4 |
|---|---|
| `PagingController<K, T>({firstPageKey, invisibleItemsThreshold})`, `.fromValue` | same |
| `itemList`, `error`, `nextPageKey`, `value`, `status` | same |
| `appendPage(items, nextKey)`, `appendLastPage(items)` | same |
| `refresh()` | same, and requests the first page itself |
| `retryLastFailedRequest()` | same, and requests the page again itself |
| `addPageRequestListener` / `removePageRequestListener` | same (listener may be `async`) |
| `addStatusListener` / `removeStatusListener` | same |
| `PagingState<K, T>`, `PagingStatus` | same |
| `PagedChildBuilderDelegate<T>(itemBuilder, firstPageErrorIndicatorBuilder, newPageErrorIndicatorBuilder, firstPageProgressIndicatorBuilder, newPageProgressIndicatorBuilder, noItemsFoundIndicatorBuilder, noMoreItemsIndicatorBuilder)` | same, without `animateTransitions` / `transitionDuration` |
| `PagedFastList<K, T>` / `.separated` | `PagedListView<K, T>` / `.separated` |
| `PagedListView<K, T>` / `.separated` | same (subset of arguments) |
| `requestNextPage()`, `isLoading`, `generation`, `isDisposed` | additions |
| `shouldRequestNextPage(lastVisibleIndex, itemCount, threshold)` | addition |

infinite_scroll_pagination **5**'s API (`PagingState` with `fetchNextPage`,
`PagingListener`) is not provided.

## Differences from infinite_scroll_pagination 4

- The next page is requested when the last visible row is within
  `invisibleItemsThreshold` (default 5) of the end, measured with
  `FastList.onVisibleRange`. v4 triggers from `itemBuilder` instead.
- `refresh()` and `retryLastFailedRequest()` request the page themselves.
  They don't wait for the widget to rebuild.
- A result from a fetch started before `refresh()` is dropped. A fetcher
  that throws, or whose future fails, sets `error`.
- Changes after `dispose()` are ignored. v4 asserts instead.
- Status indicators are plain widgets, not slivers, and get the list's
  `padding`.

## Framework gaps

These were found while building the example on an iPhone 16 Pro Max
simulator running iOS 26.0.

- **No pull-to-refresh.** DartNative has no `RefreshIndicator`
  ([DartNative/dartnative#44](https://github.com/DartNative/dartnative/issues/44)).
  Until it does, call `refresh()` from a button or an app-bar action.
- **`AppBar` crashes on iOS 26.0.** A `Scaffold` with an `AppBar` over the
  list crashed in `_dnEnsureBarScrollEdgeEffect` with
  `-[UIScrollEdgeElementContainerInteraction setScrollView:]: unrecognized
  selector`, which suggests an API added after 26.0
  ([DartNative/dartnative#48](https://github.com/DartNative/dartnative/issues/48)).
  The example uses a plain header row instead.

  ```dart
  Scaffold(appBar: AppBar(title: const Text('x')), body: FastList(...))
  ```

## Example

[`example/lib/main.dart`](example/lib/main.dart) loads 300 fake rows 20 at a
time with a 300 ms delay, and logs every page request.

```sh
cd example && dn pub get && dn run
```

## Credits & license

The API shape is adapted from
[infinite_scroll_pagination](https://github.com/EdsonBueno/infinite_scroll_pagination)
4.1.0 by Edson Bueno (MIT): the class, method and builder names, and the
rules that derive `PagingStatus` from `PagingState`. The code was written from
scratch for DartNative, and no source file was ported. See
[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).

paging_kit is MIT licensed, see [LICENSE](LICENSE).
