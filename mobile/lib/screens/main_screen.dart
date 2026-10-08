import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/audio_provider.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile/settings_screen.dart';
import '../widgets/acid/acid_bottom_nav.dart';
import '../widgets/create_menu_bottom_sheet.dart';
import '../widgets/audio_player_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/responsive_layout.dart';

/// Acid Noir shell — floating pill nav with 3 items (Library | Home | Settings).
/// Search/Recommended is reached via the SearchPill inside Discover.
/// Create Event/Playlist via the header + action in Library.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 0 = Library, 1 = Home (Discover), 2 = Settings
  int _selectedIndex = 1;
  bool _isCreateMenuOpen = false;

  void _onItemTapped(int index) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    if (audioProvider.isPlayerMaximized) {
      audioProvider.minimizePlayer();
    }
    setState(() {
      _selectedIndex = index;
      _isCreateMenuOpen = false;
    });
  }

  void _toggleCreateMenu() {
    if (!_isCreateMenuOpen) {
      Provider.of<AudioProvider>(context, listen: false).minimizePlayer();
    }
    setState(() => _isCreateMenuOpen = !_isCreateMenuOpen);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LibraryScreen(onPlusTap: _toggleCreateMenu),
      const HomeScreen(),
      SettingsScreen(onBack: () => _onItemTapped(1)),
    ];

    final isWide = ResponsiveLayout.isTablet(context) || ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          if (isWide)
            Row(
              children: [
                NavigationRail(
                  backgroundColor: AppTheme.surface,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppTheme.accent),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedIconTheme: const IconThemeData(color: AppTheme.textSecondary),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.library_music_rounded),
                      label: Text('Library'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.play_arrow_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_rounded),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppTheme.surfaceRaised),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: screens),
                ),
              ],
            )
          else
            IndexedStack(index: _selectedIndex, children: screens),

          // Offline banner notification
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OfflineBanner(),
          ),

          // Mini player + floating pill nav (mobile only for bottom nav)
          Positioned(
            left: isWide ? 80 : 0,
            right: 0,
            bottom: 0,
            child: Selector<AudioProvider, bool>(
              selector: (_, p) => p.isPlayerMaximized,
              builder: (_, isMaximized, __) {
                if (isMaximized) return const SizedBox.shrink();
                return SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AudioMiniPlayer(),
                      if (!isWide) ...[
                        Selector<AudioProvider, bool>(
                          selector: (_, p) =>
                              p.hasTrack && !p.isPlayerMaximized,
                          builder: (_, hasMini, __) => SizedBox(
                            height: hasMini ? 8 : 0,
                          ),
                        ),
                        AcidBottomNav(
                          selectedIndex: _selectedIndex,
                          onTap: _onItemTapped,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // Maximized player covers mini + nav.
          Selector<AudioProvider, bool>(
            selector: (_, p) => p.isPlayerMaximized,
            builder: (_, isMaximized, __) {
              if (!isMaximized) return const SizedBox.shrink();
              return const AudioPlayerOverlay();
            },
          ),
          // Create menu + dim go last so the sheet sits above the mini
          // player and bottom nav.
          if (_isCreateMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isCreateMenuOpen = false),
                child: Container(
                  color: AppTheme.background.withValues(alpha: 0.55),
                ),
              ),
            ),
          if (_isCreateMenuOpen)
            Positioned(
              left: isWide ? 80 : 0,
              right: 0,
              bottom: 0,
              child: CreateMenuOverlay(
                onClose: () => setState(() => _isCreateMenuOpen = false),
              ),
            ),
        ],
      ),
    );
  }
}
