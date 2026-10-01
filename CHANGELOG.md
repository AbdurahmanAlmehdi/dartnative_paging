## 0.1.2

- The example uses an `AppBar` again. Its crash on the iOS 26.0 simulator came
  from a beta-2 runtime (23A5276e), not from released iOS 26
  (DartNative/dartnative#48), so the README no longer warns about it.

## 0.1.1

- `keepAliveCount` works on paged lists: the framework bug that made the
  list lose rows as it grew is fixed (DartNative/dartnative#54, SDK
  `70531222383`). The README's warning is gone and the example uses
  `keepAliveCount: 30`.

## 0.1.0

- First release: `PagingController`, `PagingState`, `PagingStatus` and
  `PagedChildBuilderDelegate` with `infinite_scroll_pagination` 4's names.
- `PagedFastList` / `PagedFastList.separated` on DartNative's `FastList`,
  requesting the next page when the last visible row is within
  `invisibleItemsThreshold` (default 5) of the end.
- `PagedListView` / `PagedListView.separated` on `ListView.builder`.
- One page request at a time; `refresh()` drops pages from fetches started
  before it; an uncaught fetcher error becomes `error`.
- `shouldRequestNextPage(lastVisibleIndex, itemCount, threshold)`.
