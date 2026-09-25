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
