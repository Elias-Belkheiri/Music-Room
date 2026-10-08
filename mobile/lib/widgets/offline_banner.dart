import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../config/app_theme.dart';

/// Thin banner displayed at the top of the screen when offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.orange.shade800,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  connectivity.pendingCount > 0
                      ? 'Offline — ${connectivity.pendingCount} change(s) pending'
                      : 'Offline — changes will sync when connected',
                  style: AppTheme.label.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
