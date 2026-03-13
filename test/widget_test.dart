import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_pathfinding/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const IndoorPathfindingApp());
    expect(find.text('실내 길찾기'), findsOneWidget);
  });
}
