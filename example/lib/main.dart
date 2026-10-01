import 'package:dartnative/dartnative.dart';
import 'package:paging_kit/paging_kit.dart';

import 'dartnative_plugin_registrant.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const RowsScreen());
}

const _total = 300;
const _pageSize = 20;

/// A fake backend: [_total] rows served by offset after 300 ms.
Future<({List<String> items, int? next})> fetchRows(int offset) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final end = (offset + _pageSize).clamp(0, _total);
  return (
    items: [for (var i = offset; i < end; i++) 'Row ${i + 1}'],
    next: end < _total ? end : null,
  );
}

class RowsScreen extends StatefulWidget {
  const RowsScreen({super.key});

  @override
  State<RowsScreen> createState() => _RowsScreenState();
}

class _RowsScreenState extends State<RowsScreen> {
  final _pagingController = PagingController<int, String>(firstPageKey: 0);
  var _requests = 0;

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

  // Same shape as an infinite_scroll_pagination 4 fetcher.
  Future<void> _fetchPage(int offset) async {
    _requests++;
    dnLog('[paging] request #$_requests offset=$offset');
    final page = await fetchRows(offset);
    if (page.next == null) {
      _pagingController.appendLastPage(page.items);
    } else {
      _pagingController.appendPage(page.items, page.next);
    }
    _logLoaded();
  }

  void _logLoaded() {
    final items = _pagingController.itemList ?? const <String>[];
    final inOrder = [
      for (var i = 0; i < items.length; i++) items[i] == 'Row ${i + 1}',
    ].every((ok) => ok);
    dnLog(
      '[paging] loaded rows=${items.length} unique=${items.toSet().length} '
      'inOrder=$inOrder status=${_pagingController.status.name}',
    );
  }

  void _refresh() {
    dnLog('[paging] refresh');
    _requests = 0;
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.light,
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text('paging_kit'),
        actions: [
          Button(
            title: 'Refresh',
            variant: ButtonVariant.plain,
            onPressed: _refresh,
          ),
        ],
      ),
      body: _list(),
    );
  }

  Widget _list() {
    return PagedFastList<int, String>.separated(
      pagingController: _pagingController,
      keepAliveCount: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      builderDelegate: PagedChildBuilderDelegate<String>(
        itemBuilder: (context, row, index) => _RowTile(label: row),
        noMoreItemsIndicatorBuilder: (_) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('All $_total rows loaded')),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
      ),
    );
  }
}
