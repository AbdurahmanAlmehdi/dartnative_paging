# paging_kit design notes

Ticket P2-C2 (published later by P3-A5). Decisions were made without anyone
to ask. They are recorded here with the reason for each.

## Which API: infinite_scroll_pagination 4, not 5

The Flutter app (`daftaar/apps/mobile`) locks `infinite_scroll_pagination`
**4.1.0** and uses the v4 shape in `trips_list_page.dart` and
`expenses_page.dart` (three lists):

```dart
final _pagingController = PagingController<String, Trip>(firstPageKey: '');
_pagingController.addPageRequestListener(_fetchPage);
// in _fetchPage: appendLastPage / appendPage(items, nextCursor) / error = failure
// on filter change: _pagingController.refresh()
PagedListView<String, Trip>.separated(
  pagingController: ..., physics: ..., padding: ..., separatorBuilder: ...,
  builderDelegate: PagedChildBuilderDelegate<Trip>(
    itemBuilder: (context, trip, index) => ...,
    firstPageProgressIndicatorBuilder, newPageProgressIndicatorBuilder,
    firstPageErrorIndicatorBuilder, newPageErrorIndicatorBuilder,
    noItemsFoundIndicatorBuilder,
  ),
)
// error UIs call pagingController.retryLastFailedRequest
```

The v5 API (`PagingState` + `fetchPage` + `PagingListener`) is not used by the
app, so it is **not** shipped. The ticket's names are all v4 names, so
"support what SRC uses AND the ticket's v4 names" is one API.

Porting a call site means changing `PagedListView` to `PagedFastList` and the
import. Everything else (controller, delegate, builder names, `.separated`,
`padding`, `physics`) stays.

## Builder names

The ticket says `firstPageProgress`, `newPageProgress`, `noItemsFound`,
`firstPageError`. These are shortened forms of v4's
`...IndicatorBuilder` names, which the app uses, so the v4 names are kept.
`newPageErrorIndicatorBuilder` and `noMoreItemsIndicatorBuilder` are also
kept. v4's `animateTransitions` / `transitionDuration` are left out because
the app doesn't use them and DartNative has no cross-fade to map them to.

## The next-page trigger uses onVisibleRange, not onScroll

The ticket asks for a request when `onScroll` reaches `itemCount - 5`.
`FastList.onScroll` reports `(offset, maxExtent, viewport, dragging)` in
pixels, not an index. `FastList.onVisibleRange(first, last)` reports row
indexes, and fires only when the range changes, so it is cheap. The trigger
is `shouldRequestNextPage(lastVisibleIndex, itemCount, threshold)` fed from
`onVisibleRange`. `onScroll` and `onVisibleRange` are still passed through to
the app, for example to close swipe actions on scroll.

`onVisibleRange` fires on a range change only. If a page lands while the end
of the list is already on screen, the range may not change. So after every
controller change, the widget checks the last known range again.

The trigger is **not** item-build based, which is what v4 does
(`index == itemCount - threshold` inside `itemBuilder`).
`FastList` without `keepAliveCount` builds every row, and `ListView.builder`
in DartNative builds every row eagerly. A build-based trigger would therefore
chain-load every page without any scrolling.

The default threshold is 5 (the ticket's number). v4's
`invisibleItemsThreshold` on the controller is honoured, and the widget's
`invisibleItemsThreshold` overrides it.

## PagedListView

`PagedListView` sits on `ListView.builder`, which has no visible-range
callback. It listens to a `ScrollController` (the app's, or its own) and
requests the next page when less than one viewport of content is left. After
each page it checks again, which fills a viewport that isn't full yet. It
ignores zero-sized extents from before layout. DartNative's `ListView` has no
`.separated`, so both widgets make separators by alternating rows
(`PagedRows`).

## Request guard

v4 dedupes requests in the widget by item count. Here the **controller**
owns an in-flight flag. `requestNextPage()` does nothing when:

- a request is loading,
- there is no next page,
- an error is showing,
- or no listener is registered.

The flag is cleared by `appendPage`, `appendLastPage`, a non-null `error`,
`retryLastFailedRequest` and `refresh`. Both widgets and the tests use the
same `requestNextPage()`, so the guard is tested without a device.

## Stale pages after refresh (generation counter)

`refresh()` increments `generation`. `notifyPageRequestListeners` runs the
fetchers inside a `Zone` tagged with the generation. The async fetch keeps
that zone across every `await`. When `appendPage`, `appendLastPage`, `error=`,
`itemList=` or `nextPageKey=` run inside a tagged zone from an older
generation, they are dropped.

This keeps the app's fetchers unchanged: they need no token and no
`mounted` check. Calls from outside any fetch (such as a manual `appendPage`
or a delete that edits `itemList`) have no tag and always apply.
`generation` is public, for fetchers that hop zones, for example by
completing through a stream made in another zone.

## refresh() and retry request by themselves

In v4, `refresh()` only resets the state, and the rebuilt widget asks for the
first page. The ticket wants `refresh()` to reset **and** re-request. It
schedules `requestNextPage()` in a microtask. The guard folds several
refreshes in one turn into a single request; the app refreshes on three
provider changes that can fire together. The widget's own
"first page is showing → request" path is deduplicated by the same guard.
`retryLastFailedRequest()` works the same way.

## Errors from async fetchers

v4 types the listener `void Function(K)`. Here it is
`FutureOr<void> Function(K)`, so the app's `Future<void> _fetchPage` still
fits. A future or a synchronous throw that the fetcher doesn't catch becomes
the controller's `error` (current generation only), so the list shows the
error UI instead of spinning forever. The app catches `Failure` itself, so
nothing changes for it.

## After dispose

v4 asserts when a controller is used after `dispose()`. Here, every change
after `dispose()` is a silent no-op. The app's fetchers don't check
`mounted`, and a page that lands after the screen is gone is expected on a
phone.

## ChangeNotifier

`PagingController` extends DartNative's `ValueNotifier<PagingState>`, a
`ChangeNotifier`, as v4 does. `dn test` resolves the analysis stub of
`dartnative`, where `ChangeNotifier`'s bodies throw. For that reason the
controller overrides `addListener`, `removeListener`, `notifyListeners`,
`dispose` and `value` with its own list. This is what lets the controller be
tested in pure Dart. It is still a `ChangeNotifier` / `ValueListenable` for
anything that accepts one.

## No pull-to-refresh

DartNative has no `RefreshIndicator`. The app's `RefreshIndicator(onRefresh:
() => Future.sync(pagingController.refresh))` has to become a refresh button
or action until the framework has one. See the README's "Framework gaps".

## Framework gaps found on the simulator (iOS 26.0)

- With `FastList(keepAliveCount: 30)`, the native row count fell behind
  `itemCount` after about 10 appends: 382 native rows against 400, and
  paging stalled. Fixed in the framework (DartNative/dartnative#54; SDK
  `70531222383` pages to all 300 items), so the example now sets
  `keepAliveCount: 30` again.
- `AppBar` over the list crashed in `_dnEnsureBarScrollEdgeEffect`
  (unrecognized selector `setScrollView:` on
  `UIScrollEdgeElementContainerInteraction`). The example uses a header row.
- `dn run` in debug mode lost its VM-service connection when the app
  crashed. After the crash was fixed it stayed attached, and the log was
  read from `dn run`'s output.
- There was no way to inject scrolls here: access to the simulator tool
  wasn't granted. The on-device run used a temporary `Timer` that called
  `FastListController.scrollToItem` on the item 8 rows from the end every
  700 ms. It was reverted before the commit.

## Code provenance

The API shape (names, `PagingState.status` rules, `PagingStatus` values) is
adapted from infinite_scroll_pagination 4.1.0 (MIT, Edson Bueno). The status
derivation follows v4's rules so that statuses match. All code was written
from scratch for DartNative. No v4 source file was copied. See
`THIRD_PARTY_NOTICES`.
