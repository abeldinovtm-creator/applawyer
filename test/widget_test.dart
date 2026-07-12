import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:applawyer/widgets.dart';

// MyApp (lib/main.dart) требует инициализированный Supabase.instance ещё до
// runApp — прогонять его целиком в widget-тесте без мок-бэкенда бессмысленно.
// Поэтому тестируем независимый от бэкенда виджет.
void main() {
  testWidgets('StarRatingDisplay показывает нужное число закрашенных звёзд', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StarRatingDisplay(rating: 3))),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
  });
}
