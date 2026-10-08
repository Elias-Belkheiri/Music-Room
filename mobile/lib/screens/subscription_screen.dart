import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedDuration = 'monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false)
          .currentUser
          ?.accessToken;
      final subProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      subProvider.fetchStatus(token);
      subProvider.fetchPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final token = auth.currentUser?.accessToken;
    final sub = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Membership & Plans',
          style: AppTheme.titleLg.copyWith(fontSize: 18),
        ),
      ),
      body: sub.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Current Tier Hero Card ────────────────────────────────
                  _buildCurrentPlanCard(sub),
                  const SizedBox(height: 24),

                  // ── Feature Matrix ────────────────────────────────────────
                  Text(
                    'Feature Comparison',
                    style: AppTheme.titleMd.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureComparison(),
                  const SizedBox(height: 24),

                  // ── Plan Selection (if free) ──────────────────────────────
                  if (!sub.isPremium) ...[
                    Text(
                      'Choose Your Plan',
                      style: AppTheme.titleMd.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildPlanSelector(),
                    const SizedBox(height: 24),

                    // Upgrade Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final success = await sub.upgrade(
                            token,
                            duration: _selectedDuration,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Welcome to Premium! All features unlocked.'
                                    : (sub.errorMessage ?? 'Upgrade failed')),
                                backgroundColor: success
                                    ? AppTheme.accent
                                    : AppTheme.danger,
                              ),
                            );
                          }
                        },
                        child: Text(
                          _selectedDuration == 'monthly'
                              ? 'Upgrade Now • \$9.99/mo'
                              : 'Upgrade Now • \$99.99/yr',
                          style: AppTheme.label.copyWith(
                            color: AppTheme.onAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Downgrade Option for Premium Members
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_downward_rounded,
                            size: 16, color: AppTheme.textSecondary),
                        label: Text(
                          'Cancel / Downgrade to Free',
                          style: AppTheme.label.copyWith(
                            color: AppTheme.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        onPressed: () => _confirmDowngrade(context, sub, token),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionProvider sub) {
    final isPrem = sub.isPremium;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isPrem ? AppTheme.accent : AppTheme.surfaceRaised,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Status',
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPrem ? AppTheme.accent : AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  isPrem ? 'PREMIUM' : 'FREE TIER',
                  style: AppTheme.label.copyWith(
                    color: isPrem ? AppTheme.onAccent : AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPrem ? 'MusicRoom Unlimited' : 'MusicRoom Basic',
            style: AppTheme.titleLg.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            isPrem
                ? (sub.expiresAt != null
                    ? 'Active until ${sub.expiresAt!.toLocal().toString().split(' ')[0]}'
                    : 'Active VIP Membership')
                : 'Free features: join events, vote on tracks, listen & stream',
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          _featureRow('Discover & stream Audius tracks', free: true, prem: true),
          _featureRow('Join live rooms & vote on queue', free: true, prem: true),
          _featureRow('Download music for offline listening', free: true, prem: true),
          _featureRow('Create collaborative playlists', free: false, prem: true),
          _featureRow('Edit & manage multi-user playlists', free: false, prem: true),
          _featureRow('Invite friends with role permissions', free: false, prem: true),
          _featureRow('Host unlimited music parties', free: false, prem: true),
        ],
      ),
    );
  }

  Widget _featureRow(String name, {required bool free, required bool prem}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surfaceRaised, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: AppTheme.body.copyWith(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Icon(
            free ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 16,
            color: free ? Colors.greenAccent : Colors.white24,
          ),
          const SizedBox(width: 16),
          Icon(
            prem ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 16,
            color: prem ? AppTheme.accent : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Row(
      children: [
        Expanded(
          child: _planCard(
            title: 'Monthly',
            price: '\$9.99',
            period: '/month',
            badge: null,
            duration: 'monthly',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _planCard(
            title: 'Annual',
            price: '\$99.99',
            period: '/year',
            badge: 'SAVE 17%',
            duration: 'yearly',
          ),
        ),
      ],
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String period,
    required String? badge,
    required String duration,
  }) {
    final selected = _selectedDuration == duration;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = duration),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceRaised : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppTheme.onAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(title, style: AppTheme.caption),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: AppTheme.titleLg.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(period, style: AppTheme.caption.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDowngrade(
      BuildContext context, SubscriptionProvider sub, String? token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Downgrade to Free?'),
        content: const Text(
          'You will lose access to creating and editing playlists.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Keep Premium'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Downgrade',
                style: TextStyle(color: AppTheme.danger)),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await sub.downgrade(token);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Downgraded to free plan.'
                        : 'Failed to downgrade.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
