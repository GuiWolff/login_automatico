import 'package:flutter_test/flutter_test.dart';
import 'package:login_automatico/main.dart';

void main() {
  testWidgets('shows Keycloak login method selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(
      find.text('Escolha uma forma de login para continuar'),
      findsOneWidget,
    );
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Entrar com Apple'), findsOneWidget);
    expect(find.text('Entrar com Facebook'), findsOneWidget);
    expect(find.text('Entrar com e-mail'), findsOneWidget);
    expect(find.text('Entrar com Keycloak'), findsNothing);
  });
}
