import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../providers/audio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/subscription_provider.dart';
import '../subscription_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  /// Called when the back button is pressed while this screen is shown as a
  /// bottom-navigation tab (where there is nothing to pop). The host
  /// (MainScreen) uses it to switch back to the Home tab. When Settings is
  /// pushed as a route (e.g. from ProfileScreen) a normal pop is used.
  final VoidCallback? onBack;

  const SettingsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _genreOptions = const [
    'Pop',
    'Rock',
    'Hip Hop',
    'Jazz',
    'Electronic',
    'Indie',
    'R&B',
    'Classical',
  ];

  bool _activeDiscovery = true;
  double _searchDistance = 50;
  bool _dataSaver = false;
  bool _offlineMode = false;
  bool _explicitContent = true;
  bool _privateSession = false;
  bool _notificationsEnabled = true;
  Set<String> _selectedGenres = {'Pop', 'Rock'};

  // Public info
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  // Friends info
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _instagramController = TextEditingController();
  // Private info
  final _notesController = TextEditingController();
  final _realNameController = TextEditingController();

  late UserProfileProvider _profileProvider;
  bool _didInitFromProfile = false;

  @override
  void initState() {
    super.initState();
    _profileProvider = context.read<UserProfileProvider>();
    // The profile may still be loading when this tab is first built
    // (IndexedStack builds all tabs up-front). Fill the fields as soon as
    // the profile arrives instead of only once in a post-frame callback,
    // otherwise the form stays permanently empty and edits look "not saved".
    _profileProvider.addListener(_maybeLoadFromProfile);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeLoadFromProfile(),
    );
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_maybeLoadFromProfile);
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _instagramController.dispose();
    _notesController.dispose();
    _realNameController.dispose();
    super.dispose();
  }

  void _maybeLoadFromProfile() {
    if (!mounted || _didInitFromProfile) return;
    if (_profileProvider.profile == null) return;
    _didInitFromProfile = true;
    _loadFromProfile();
  }

  void _loadFromProfile() {
    final profile = _profileProvider.profile;
    final prefs = profile?.musicPreferences ?? {};

    if (!mounted) return;
    setState(() {
      _activeDiscovery = prefs['discovery_mode']?.toString() != 'passive';
      _searchDistance =
          (prefs['max_distance_km'] as num?)?.toDouble() ?? _searchDistance;
      _dataSaver = prefs['data_saver'] as bool? ?? _dataSaver;
      _offlineMode = prefs['offline_mode'] as bool? ?? _offlineMode;
      _explicitContent = prefs['explicit_content'] as bool? ?? _explicitContent;
      _privateSession = prefs['private_session'] as bool? ?? _privateSession;
      _notificationsEnabled =
          prefs['notifications_enabled'] as bool? ?? _notificationsEnabled;

      final genres = prefs['favorite_genres'];
      if (genres is List) {
        _selectedGenres = genres.map((e) => e.toString()).toSet();
      }

      // Public info
      final pub = profile?.publicInfo ?? {};
      _bioController.text = pub['bio']?.toString() ?? '';
      _locationController.text = pub['location']?.toString() ?? '';
      _websiteController.text = pub['website']?.toString() ?? '';
      // Friends info
      final fri = profile?.friendsInfo ?? {};
      _phoneController.text = fri['phone']?.toString() ?? '';
      _birthdayController.text = fri['birthday']?.toString() ?? '';
      _instagramController.text = fri['instagram']?.toString() ?? '';
      // Private info
      final prv = profile?.privateInfo ?? {};
      _notesController.text = prv['notes']?.toString() ?? '';
      _realNameController.text = prv['real_name']?.toString() ?? '';
    });
  }

  Future<void> _savePreferences() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<UserProfileProvider>();
    final token = authProvider.currentUser?.accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool infoSuccess = false;
    bool prefsSuccess = false;
    try {
      // Save profile info tiers
      infoSuccess = await profileProvider.updateProfile(
        token,
        profileProvider.profile?.displayName ?? '',
        profileProvider.profile?.avatarUrl,
        publicInfo: {
          'bio': _bioController.text.trim(),
          'location': _locationController.text.trim(),
          'website': _websiteController.text.trim(),
        },
        friendsInfo: {
          'phone': _phoneController.text.trim(),
          'birthday': _birthdayController.text.trim(),
          'instagram': _instagramController.text.trim(),
        },
        privateInfo: {
          'notes': _notesController.text.trim(),
          'real_name': _realNameController.text.trim(),
        },
      );

      // Save music preferences
      prefsSuccess = await profileProvider.updatePreferences(token, {
        'discovery_mode': _activeDiscovery ? 'active' : 'passive',
        'max_distance_km': _searchDistance.round(),
        'favorite_genres': _selectedGenres.toList()..sort(),
        'data_saver': _dataSaver,
        'offline_mode': _offlineMode,
        'explicit_content': _explicitContent,
        'private_session': _privateSession,
        'notifications_enabled': _notificationsEnabled,
      });
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }

    // Always persist offline mode locally first so it functions even without network
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('offline_mode', _offlineMode);
    } catch (_) {}

    if (!mounted) return;

    final allOk = infoSuccess && prefsSuccess;
    if (allOk) {
      // Re-sync the form with the server truth returned by the PUT calls
      // so the UI can never show stale/diverged values.
      _loadFromProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Settings saved',
            style: TextStyle(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.accent,
        ),
      );
    } else {
      final detail = profileProvider.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail != null && detail.isNotEmpty
                ? 'Could not save settings: $detail'
                : 'Could not save settings. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _sectionTitle(String title, {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null)
            Text(
              action,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
      title: Text(title, style: AppTheme.titleMd.copyWith(fontSize: 16)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: AppTheme.caption.copyWith(fontSize: 12)),
      trailing: trailing,
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _settingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        onChanged: (newValue) {
          setState(() => onChanged(newValue));
        },
        activeColor: AppTheme.accent,
      ),
    );
  }

  Widget _genreChip(String genre) {
    final isSelected = _selectedGenres.contains(genre);
    return FilterChip(
      selected: isSelected,
      label: Text(genre),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppTheme.accent,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.black,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedGenres.add(genre);
          } else {
            _selectedGenres.remove(genre);
          }
        });
      },
    );
  }

  Widget _buildPrivacySection({
    required IconData icon,
    required String title,
    required String visibilityNote,
    required Color accentColor,
    required List<Widget> fields,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(
            visibilityNote,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: fields),
          ),
        ),
      ],
    );
  }

  Widget _infoField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.profile;
    final isLoading = profileProvider.isLoading;
    // Reserve space for the floating mini player + pill nav so the
    // Save/Log out buttons can always be scrolled into view.
    final audio = context.watch<AudioProvider>();
    final hasMini = audio.hasTrack && !audio.isPlayerMaximized;
    final listBottomPadding = hasMini ? 230.0 : 150.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings & privacy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            // This screen is used both as a pushed route (Profile → Settings)
            // and as a bottom-navigation tab. Popping the root route leaves
            // a black screen, so only pop when there is a route to pop;
            // otherwise delegate (tab host switches back to Home).
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              widget.onBack?.call();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _savePreferences,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: listBottomPadding),
            children: [
              _sectionTitle('Your profile'),
              _card(
                child: Column(
                  children: [
                    _settingTile(
                      icon: Icons.person,
                      title: profile?.displayName ?? 'My profile',
                      subtitle: profile?.email ?? 'Tap to edit account details',
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _sectionTitle('Membership & Plans'),
              _card(
                child: Consumer<SubscriptionProvider>(
                  builder: (context, sub, _) => _settingTile(
                    icon: Icons.star_rounded,
                    title: sub.isPremium ? 'Premium Active' : 'Free Plan',
                    subtitle: sub.isPremium
                        ? 'Unlimited playlists & party hosting'
                        : 'Upgrade to unlock collaborative playlist editor',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.accent,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              _sectionTitle('Debug'),
              _card(
                child: Consumer<ConnectivityProvider>(
                  builder: (context, connectivity, _) => _toggleTile(
                    icon: Icons.cloud_off_rounded,
                    title: 'Simulate offline',
                    subtitle:
                        'Forces the offline banner + cached data without touching Wi-Fi',
                    value: connectivity.debugForceOffline,
                    onChanged: (offline) {
                      connectivity.setDebugForceOffline(offline);
                    },
                  ),
                ),
              ),
              _buildPrivacySection(
                icon: Icons.public,
                title: 'Profile details',
                visibilityNote: 'This data will be shown to everyone.',
                accentColor: AppTheme.accent,
                fields: [
                  _infoField(
                    label: 'Bio',
                    controller: _bioController,
                    hint: 'Tell the world about yourself…',
                  ),
                  _infoField(
                    label: 'Location',
                    controller: _locationController,
                    hint: 'City, Country',
                  ),
                  _infoField(
                    label: 'Website',
                    controller: _websiteController,
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              _buildPrivacySection(
                icon: Icons.group,
                title: 'Close friends details',
                visibilityNote:
                    'This data is visible only when you follow each other.',
                accentColor: const Color(0xFFFFC107),
                fields: [
                  _infoField(
                    label: 'Phone',
                    controller: _phoneController,
                    hint: '+1 234 567 890',
                    keyboardType: TextInputType.phone,
                  ),
                  _infoField(
                    label: 'Birthday',
                    controller: _birthdayController,
                    hint: 'YYYY-MM-DD',
                  ),
                  _infoField(
                    label: 'Instagram',
                    controller: _instagramController,
                    hint: '@username',
                  ),
                ],
              ),
              _buildPrivacySection(
                icon: Icons.lock,
                title: 'Private details',
                visibilityNote: 'Only you can view this data.',
                accentColor: const Color(0xFF9C27B0),
                fields: [
                  _infoField(
                    label: 'Real name',
                    controller: _realNameController,
                    hint: 'Your legal name',
                  ),
                  _infoField(
                    label: 'Notes',
                    controller: _notesController,
                    hint: 'Personal notes…',
                  ),
                ],
              ),
              _sectionTitle('Favorite genres'),
              _card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _genreOptions.map(_genreChip).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Save changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Provider.of<AuthProvider>(context, listen: false).logout();
                  },
                  child: const Text(
                    'Log out',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
        ],
      ),
    );
  }
}
