import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taknoghte/ui/stats/stats_screen.dart';

/// Regression guard for the deep-work chart bottom overflow: the tallest bar
/// column (value label + bar + «امروز» label) must fit its fixed-height box
/// even at the 1.3× text scale the app allows. A RenderFlex overflow logs a
/// FlutterError, which this test promotes to a failure.
void main() {
  testWidgets('focus chart does not overflow at 1.3x text scale', (
    tester,
  ) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflows.add(details.exceptionAsString());
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      // A worst case: one tall bar with a multi-digit value, big text scale.
      const MaterialData(child: FocusChart(minutes: [0, 0, 0, 0, 0, 0, 999])),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });
}

/// Minimal host that stretches the chart to a phone-ish width at 1.3× text.
class MaterialData extends StatelessWidget {
  final Widget child;
  const MaterialData({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    );
  }
}
