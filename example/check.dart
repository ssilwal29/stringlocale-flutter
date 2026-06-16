/// Drift check + prune. Run: dart run example/check.dart
import 'package:stringlocale/compile.dart';

import 'strings.dart';

void main() {
  registerAll();
  final report = check(null, 'dist');
  print(report.summary());
  if (!report.ok) {
    final pruned = prune(null, 'dist', dryRun: true);
    print('\nWould prune:\n${pruned.summary()}');
  }
}
