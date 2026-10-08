import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicroom/providers/auth_provider.dart';
import 'package:musicroom/router/app_router_delegate.dart';
import 'package:musicroom/router/app_route_information_parser.dart';
import 'package:musicroom/screens/signup_screen.dart';
import 'package:musicroom/screens/login_screen.dart';

Future<AppRouterDelegate> pumpUnauthenticatedApp(
    WidgetTester t, AuthProvider auth) async {
  final delegate = AppRouterDelegate(authProvider: auth);
  await t.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    ),
  );
  await auth.checkSession();
  // NB: pump(), not pumpAndSettle() — the welcome screen runs an
  // infinite wave animation that never settles.
  await t.pump();
  await t.pump(const Duration(seconds: 4));
  return delegate;
}

void main() {
  testWidgets('Continue with email opens signup screen', (t) async {
    SharedPreferences.setMockInitialValues({});
    await pumpUnauthenticatedApp(t, AuthProvider());
    expect(find.text('Continue with email'), findsOneWidget);
    await t.tap(find.text('Continue with email'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('log in route shows login screen', (t) async {
    // NB: the 'log in' link is a RichText span — widget-test taps can't
    // hit spans precisely, so drive the exact callback the span invokes.
    SharedPreferences.setMockInitialValues({});
    final delegate = await pumpUnauthenticatedApp(t, AuthProvider());
    delegate.navigateToLogin();
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
