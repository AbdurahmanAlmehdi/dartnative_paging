/// Where a paged list is in its lifecycle, derived from a `PagingState`.
enum PagingStatus {
  /// Items are loaded and there is no next page.
  completed,

  /// The first page loaded and was empty.
  noItemsFound,

  /// Nothing is loaded yet and there is no error.
  loadingFirstPage,

  /// Items are loaded and more pages remain.
  ongoing,

  /// The first page failed.
  firstPageError,

  /// A page after the first failed.
  subsequentPageError,
}
