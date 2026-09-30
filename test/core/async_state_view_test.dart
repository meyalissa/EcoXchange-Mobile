// EcoXchange Mobile — AsyncStateView tests (Phase 4C.2 §14/§21): every
// network-backed screen relies on this for its loading/empty/error states,
// so it is tested directly and in isolation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/widgets/async_state_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows a loading indicator, not a blank screen, while loading with no data yet', (tester) async {
    await tester.pumpWidget(wrap(AsyncStateView<String>(
      isLoading: true,
      error: null,
      data: null,
      builder: (context, data) => Text(data),
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an understandable message for a network error, never a raw exception', (tester) async {
    await tester.pumpWidget(wrap(AsyncStateView<String>(
      isLoading: false,
      error: const NetworkException('Could not connect to EcoXchange. Please check your internet connection.'),
      data: null,
      builder: (context, data) => Text(data),
    )));

    expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('Exception:'), findsNothing);
  });

  testWidgets('shows the retry button and it is wired to onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(wrap(AsyncStateView<String>(
      isLoading: false,
      error: const ServerException('Something went wrong.'),
      data: null,
      onRetry: () => retried = true,
      builder: (context, data) => Text(data),
    )));

    await tester.tap(find.text('Try Again'));
    expect(retried, isTrue);
  });

  testWidgets('shows an honest empty state, not fake content, when there is genuinely no data', (tester) async {
    await tester.pumpWidget(wrap(AsyncStateView<List<int>>(
      isLoading: false,
      error: null,
      data: const <int>[],
      isEmpty: true,
      emptyMessage: 'No pickups found for this filter.',
      builder: (context, data) => Text('Got ${data.length} items'),
    )));

    expect(find.text('No pickups found for this filter.'), findsOneWidget);
    expect(find.textContaining('Got'), findsNothing);
  });

  testWidgets('renders real data via the builder once loaded', (tester) async {
    await tester.pumpWidget(wrap(AsyncStateView<String>(
      isLoading: false,
      error: null,
      data: 'real server value',
      builder: (context, data) => Text(data),
    )));

    expect(find.text('real server value'), findsOneWidget);
  });
}
