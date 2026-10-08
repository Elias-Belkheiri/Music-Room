import 'package:flutter_test/flutter_test.dart';
import 'package:musicroom/providers/subscription_provider.dart';

void main() {
  group('SubscriptionProvider Tests', () {
    test('Default subscription state is free and not premium', () {
      final provider = SubscriptionProvider();
      expect(provider.tier, 'free');
      expect(provider.isPremium, isFalse);
      expect(provider.expiresAt, isNull);
      expect(provider.startedAt, isNull);
      expect(provider.plans, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('fetchStatus handles empty or null token gracefully without crashing', () async {
      final provider = SubscriptionProvider();
      await provider.fetchStatus(null);
      expect(provider.isPremium, isFalse);
      expect(provider.tier, 'free');

      await provider.fetchStatus('');
      expect(provider.isPremium, isFalse);
    });

    test('upgrade handles empty token by returning false', () async {
      final provider = SubscriptionProvider();
      final result = await provider.upgrade(null);
      expect(result, isFalse);
      expect(provider.isPremium, isFalse);
    });

    test('downgrade handles empty token by returning false', () async {
      final provider = SubscriptionProvider();
      final result = await provider.downgrade(null);
      expect(result, isFalse);
    });
  });
}
