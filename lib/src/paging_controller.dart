import 'dart:async';

import 'package:dartnative/dartnative.dart';

import 'paging_state.dart';
import 'paging_status.dart';

/// Called with the key of the page to load. It may be `async`: a future that
/// fails without the listener handling it becomes the controller's [error].
typedef PageRequestListener<PageKeyType> =
    FutureOr<void> Function(PageKeyType pageKey);

/// Called whenever the [PagingStatus] changes.
typedef PagingStatusListener = void Function(PagingStatus status);

/// Holds the pages of a paged list and asks for the next one.
///
/// Mirrors `infinite_scroll_pagination` 4's `PagingController`: register a
/// fetcher with [addPageRequestListener], and have it call [appendPage],
/// [appendLastPage] or set [error]. `PagedFastList` and `PagedListView`
/// rebuild from it and ask for pages as the user scrolls.
///
/// Two guards v4 leaves to the app:
/// - one request at a time — [requestNextPage] does nothing while a page is
///   loading ([isLoading]);
/// - [refresh] starts a new [generation]; a page, or an error, that a fetch
///   from before the refresh delivers is dropped.
class PagingController<PageKeyType, ItemType>
    extends ValueNotifier<PagingState<PageKeyType, ItemType>> {
  PagingController({required this.firstPageKey, this.invisibleItemsThreshold})
    : _value = PagingState<PageKeyType, ItemType>(nextPageKey: firstPageKey),
      super(PagingState<PageKeyType, ItemType>(nextPageKey: firstPageKey));

  /// Starts from an existing [PagingState]; [firstPageKey] is used by
  /// [refresh].
  PagingController.fromValue(
    super.value, {
    required this.firstPageKey,
    this.invisibleItemsThreshold,
  }) : _value = value;

  /// The key of the first page, requested again after [refresh].
  final PageKeyType firstPageKey;

  /// Items left below the last visible one that trigger the next request.
  /// The widget's own threshold wins; otherwise the default is 5.
  final int? invisibleItemsThreshold;

  // DartNative's ChangeNotifier is a stub outside a running app (so pure-Dart
  // tests could not notify), hence the controller keeps its own listeners.
  final List<VoidCallback> _listeners = [];
  final List<PagingStatusListener> _statusListeners = [];
  final List<PageRequestListener<PageKeyType>> _pageRequestListeners = [];

  PagingState<PageKeyType, ItemType> _value;
  int _generation = 0;
  bool _loading = false;
  bool _disposed = false;

  /// Bumped by every [refresh]. Results of fetches started under an older
  /// generation are ignored.
  int get generation => _generation;

  /// Whether a page request is in flight: dispatched by [requestNextPage]
  /// and not yet answered by [appendPage], [appendLastPage] or [error].
  bool get isLoading => _loading;

  /// Whether [dispose] was called. Every change after it is ignored.
  bool get isDisposed => _disposed;

  @override
  PagingState<PageKeyType, ItemType> get value => _value;

  @override
  set value(PagingState<PageKeyType, ItemType> newValue) {
    if (_disposed || newValue == _value) return;
    final oldStatus = _value.status;
    _value = newValue;
    final newStatus = newValue.status;
    if (oldStatus != newStatus) notifyStatusListeners(newStatus);
    notifyListeners();
  }

  /// Every item loaded so far, or `null` before the first page.
  List<ItemType>? get itemList => _value.itemList;
  set itemList(List<ItemType>? newItemList) {
    if (_isStale) return;
    value = PagingState(
      itemList: newItemList,
      error: error,
      nextPageKey: nextPageKey,
    );
  }

  /// The last request's error. Setting it ends the in-flight request.
  dynamic get error => _value.error;
  set error(dynamic newError) {
    if (_isStale) return;
    if (newError != null) _loading = false;
    value = PagingState(
      itemList: itemList,
      error: newError,
      nextPageKey: nextPageKey,
    );
  }

  /// The key of the next page; `null` once the last page is loaded.
  PageKeyType? get nextPageKey => _value.nextPageKey;
  set nextPageKey(PageKeyType? newNextPageKey) {
    if (_isStale) return;
    value = PagingState(
      itemList: itemList,
      error: error,
      nextPageKey: newNextPageKey,
    );
  }

  /// The current [PagingStatus].
  PagingStatus get status => _value.status;

  /// Appends [newItems], sets the next page's key and clears the error.
  void appendPage(List<ItemType> newItems, PageKeyType? nextPageKey) {
    if (_isStale) return;
    _loading = false;
    value = PagingState(
      itemList: [...?itemList, ...newItems],
      nextPageKey: nextPageKey,
    );
  }

  /// Appends [newItems] as the final page.
  void appendLastPage(List<ItemType> newItems) => appendPage(newItems, null);

  /// Clears the error and asks for the failed page again.
  void retryLastFailedRequest() {
    if (_disposed) return;
    _loading = false;
    value = PagingState(itemList: itemList, nextPageKey: nextPageKey);
    scheduleMicrotask(requestNextPage);
  }

  /// Drops every loaded page and asks for the first page again.
  ///
  /// Starts a new [generation], so a page still loading from before is
  /// discarded when it arrives. The request is made in a microtask, which
  /// folds several refreshes in one turn (filter changes, say) into one.
  void refresh() {
    if (_disposed) return;
    _generation++;
    _loading = false;
    value = PagingState(nextPageKey: firstPageKey);
    scheduleMicrotask(requestNextPage);
  }

  /// Asks the page request listeners for [nextPageKey], unless there is no
  /// next page, the last request failed, one is already loading, or nobody
  /// listens. Returns whether a request was made.
  ///
  /// The paged widgets call this as the user nears the end of the list.
  bool requestNextPage() {
    final key = nextPageKey;
    if (_disposed || _loading || key == null || error != null) return false;
    if (_pageRequestListeners.isEmpty) return false;
    _loading = true;
    notifyPageRequestListeners(key);
    return true;
  }

  /// Calls every page request listener with [pageKey], tagged with the
  /// current [generation] so a stale result can be recognised.
  void notifyPageRequestListeners(PageKeyType pageKey) {
    if (_disposed) return;
    final generation = _generation;
    void fail(Object error) {
      // Only an unanswered request of this generation turns into an error.
      if (!_disposed && _loading && generation == _generation) {
        this.error = error;
      }
    }

    runZoned(() {
      for (final listener in List.of(_pageRequestListeners)) {
        if (!_pageRequestListeners.contains(listener)) continue;
        try {
          final result = listener(pageKey);
          if (result is Future<void>) result.catchError(fail);
        } catch (error) {
          fail(error);
        }
      }
    }, zoneValues: {_requestZoneKey: _RequestTag(this, generation)});
  }

  /// Adds a fetcher, called with each page key to load.
  void addPageRequestListener(PageRequestListener<PageKeyType> listener) {
    if (!_disposed) _pageRequestListeners.add(listener);
  }

  /// Removes a fetcher added with [addPageRequestListener].
  void removePageRequestListener(PageRequestListener<PageKeyType> listener) {
    _pageRequestListeners.remove(listener);
  }

  /// Calls [listener] every time the [status] changes.
  void addStatusListener(PagingStatusListener listener) {
    if (!_disposed) _statusListeners.add(listener);
  }

  /// Removes a listener added with [addStatusListener].
  void removeStatusListener(PagingStatusListener listener) {
    _statusListeners.remove(listener);
  }

  /// Calls every status listener with [status].
  void notifyStatusListeners(PagingStatus status) {
    for (final listener in List.of(_statusListeners)) {
      if (_statusListeners.contains(listener)) listener(status);
    }
  }

  /// Whether anything listens for changes.
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void addListener(VoidCallback listener) {
    if (!_disposed) _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      if (_listeners.contains(listener)) listener();
    }
  }

  /// Releases every listener. A fetch that finishes afterwards is ignored.
  @override
  void dispose() {
    _disposed = true;
    _loading = false;
    _listeners.clear();
    _statusListeners.clear();
    _pageRequestListeners.clear();
  }

  // A result is stale when it comes from a request of an older generation
  // (the zone tags the fetch's whole async chain) or after dispose.
  bool get _isStale {
    if (_disposed) return true;
    final tag = Zone.current[_requestZoneKey];
    return tag is _RequestTag &&
        identical(tag.controller, this) &&
        tag.generation != _generation;
  }
}

final Object _requestZoneKey = Object();

class _RequestTag {
  _RequestTag(this.controller, this.generation);

  final Object controller;
  final int generation;
}
