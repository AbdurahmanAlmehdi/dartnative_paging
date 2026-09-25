# paging_kit — agent guide

Infinite-scroll pagination for DartNative with `infinite_scroll_pagination`
4's API. Dart-only: no iOS or Android sources. Published on dartpub.dev.

## Toolchain

Use `dn`, never `flutter` or `dart` directly:

```sh
dn pub get --no-example
dn analyze --no-pub
dn test --no-pub
(cd example && dn pub get && dn run -d <device>)
dn plugin build        # packs dist/ without publishing
```

Publish with `COPYFILE_DISABLE=1 dn publish`. Without it, macOS `tar` adds
`._*` metadata files to the archive. Bump `version` in `pubspec.yaml` and add
the matching `CHANGELOG.md` section first.

Resolve the root and `example/` separately, as above. A plain `dn pub get` at
the root also resolves `example/` with plain pub, which breaks analysis.

## Layout

- `lib/paging_kit.dart`: public exports.
- `lib/src/paging_controller.dart`: `PagingController`, with the request
  guard, generations and its own listener list.
- `lib/src/paging_state.dart`, `paging_status.dart`: state, and v4's status
  rules.
- `lib/src/next_page_trigger.dart`: `shouldRequestNextPage`, the pure trigger.
- `lib/src/paged_rows.dart`: maps list rows to items, separators and the
  footer (pure).
- `lib/src/paged_layout.dart`: the state shared by both widgets (status
  builders, row building, first-page request).
- `lib/src/paged_fast_list.dart`: `PagedFastList` on `FastList`.
- `lib/src/paged_list_view.dart`: `PagedListView` on `ListView.builder`.
- `test/`: pure Dart tests. No device needed.
- `example/`: a DartNative app (made with `dn create`) that uses the package
  by path: 300 fake rows, 20 per page.
- `doc/design.md`: why things are the way they are. Read it before changing
  behaviour.

## Invariants — don't break these

- **Names match `infinite_scroll_pagination` 4.** Adding API is fine.
  Renaming, or changing what the v4 names mean, isn't.
- **One request in flight.** Everything that asks for a page goes through
  `PagingController.requestNextPage()`.
- **Stale results are dropped.** Fetchers run in a zone tagged with the
  generation. Every mutation a fetcher can make checks `_isStale`.
- **No build-based trigger.** `FastList` (without `keepAliveCount`) and
  `ListView.builder` build every row, so triggering from `itemBuilder` would
  load every page.
- **Pure-Dart testable.** `dn test` sees DartNative's stubs, where
  `ChangeNotifier` throws, so the controller never calls `super` on it.

## Conventions

- Comments explain *why*, not what. Keep inline comments to 3 lines at most.
  Public API gets short dartdoc.
- Every change to behaviour gets a test in `test/`, and a `CHANGELOG.md`
  entry under the next version.
- Import only `package:dartnative/dartnative.dart`, never
  `package:flutter/...`.
