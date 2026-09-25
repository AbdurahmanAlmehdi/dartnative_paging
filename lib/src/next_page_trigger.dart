/// How many items may remain below the last visible one before the next page
/// is requested, when neither the widget nor the controller sets one.
const int defaultInvisibleItemsThreshold = 5;

/// Whether the next page is due once the item at [lastVisibleIndex] is on
/// screen: true when it is at or past `itemCount - threshold`.
///
/// An index at or past [itemCount] (the loading footer) always qualifies.
/// With no items loaded yet, the first page is requested elsewhere, so this
/// returns false.
bool shouldRequestNextPage(int lastVisibleIndex, int itemCount, int threshold) {
  if (itemCount <= 0 || lastVisibleIndex < 0) return false;
  final clamped = threshold < 0 ? 0 : threshold;
  return lastVisibleIndex >= itemCount - clamped;
}
