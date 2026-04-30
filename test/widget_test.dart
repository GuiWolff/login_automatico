import 'package:flutter_test/flutter_test.dart';
import 'package:login_automatico/main.dart';

void main() {
  testWidgets('shows Keycloak auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Keycloak Auth'), findsOneWidget);
    expect(find.text('Entrar com Keycloak'), findsOneWidget);
    expect(find.text('Nenhum usuario autenticado.'), findsOneWidget);
  });
}
