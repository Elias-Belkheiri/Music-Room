import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _avatarUrlController;
  late UserProfileProvider _profileProvider;
  bool _didInitFromProfile = false;

  @override
  void initState() {
    super.initState();
    _profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    _nameController = TextEditingController(
      text: _profileProvider.profile?.displayName ?? '',
    );
    _avatarUrlController = TextEditingController(
      text: _profileProvider.profile?.avatarUrl ?? '',
    );
    // The profile may still be loading when this screen opens; fill the
    // fields as soon as it arrives (only if the user hasn't typed yet).
    _profileProvider.addListener(_maybeLoadFromProfile);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeLoadFromProfile(),
    );
  }

  void _maybeLoadFromProfile() {
    if (!mounted || _didInitFromProfile) return;
    final profile = _profileProvider.profile;
    if (profile == null) return;
    _didInitFromProfile = true;
    if (_nameController.text.isEmpty) {
      _nameController.text = profile.displayName;
    }
    if (_avatarUrlController.text.isEmpty) {
      _avatarUrlController.text = profile.avatarUrl ?? '';
    }
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_maybeLoadFromProfile);
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );
      final token = authProvider.currentUser?.accessToken;

      if (token != null) {
        final success = await profileProvider.updateProfile(
          token,
          _nameController.text.trim(),
          _avatarUrlController.text.trim(),
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Profile updated successfully!',
                style: TextStyle(color: AppTheme.onAccent),
              ),
              backgroundColor: AppTheme.accent,
            ),
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.errorMessage ?? 'Failed to update profile',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserProfileProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display Name',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Avatar URL (Optional)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _avatarUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[900],
                      hintText: 'https://...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent, // Spotify green
                        foregroundColor: AppTheme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
        ],
      ),
    );
  }
}
