import 'package:dartnative/dartnative.dart';

Widget defaultFirstPageProgress(BuildContext context) =>
    const Center(child: CircularProgressIndicator());

Widget defaultNewPageProgress(BuildContext context) => const Padding(
  padding: EdgeInsets.symmetric(vertical: 16),
  child: Center(child: CircularProgressIndicator()),
);

Widget defaultNoItemsFound(BuildContext context) =>
    const Center(child: Text('No items found'));

Widget defaultFirstPageError(BuildContext context, VoidCallback onRetry) =>
    Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Something went wrong'),
          const SizedBox(height: 12),
          Button(title: 'Try again', onPressed: onRetry),
        ],
      ),
    );

Widget defaultNewPageError(BuildContext context, VoidCallback onRetry) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Button(title: 'Try again', onPressed: onRetry),
      ),
    );
