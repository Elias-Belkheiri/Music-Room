import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/event_service.dart';
import '../services/user_service.dart';
import '../services/follow_service.dart';
import 'user_public_profile_screen.dart';

class EventSettingsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String description;
  final String visibility;

  const EventSettingsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.description,
    required this.visibility,
  });

  @override
  State<EventSettingsScreen> createState() => _EventSettingsScreenState();
}

class _EventSettingsScreenState extends State<EventSettingsScreen>
    with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService();
  final UserService _userService = UserService();

  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isPrivate = false;
  bool _savingSettings = false;

  // Collaborators
  List<Map<String, dynamic>> _collaborators = [];
  List<Map<String, dynamic>> _listeners = [];
  bool _loadingCollaborators = true;

  // Search / Invite
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final Set<String> _invitingIds = {};

  // Followers / Following
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  bool _loadingFollows = true;
  int _activeFollowTab = 0; // 0 for Followers, 1 for Following

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nameController = TextEditingController(text: widget.eventName);
    _descriptionController = TextEditingController(text: widget.description);
    _isPrivate = widget.visibility == 'private';
    _loadCollaborators();
    _loadFollowData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String? get _token => Provider.of<AuthProvider>(
    context,
    listen: false,
  ).currentUser?.accessToken;

  String? get _currentUserId =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

  // ── Load collaborators & listeners ──────────────────────────────────────────
  Future<void> _loadCollaborators() async {
    final token = _token;
    if (token == null) return;

    try {
      final results = await Future.wait([
        _eventService.getEventCollaborators(widget.eventId, token),
        _eventService.getEventListeners(widget.eventId, token),
      ]);
      if (mounted) {
        setState(() {
          _collaborators = results[0];
          _listeners = results[1];
          _loadingCollaborators = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCollaborators = false);
      }
    }
  }

  // ── Load followers & following for invites ─────────────────────────────────
  Future<void> _loadFollowData() async {
    final token = _token;
    final myId = _currentUserId;
    if (token == null || myId == null) {
      if (mounted) {
        setState(() => _loadingFollows = false);
      }
      return;
    }

    try {
      final followService = FollowService();
      final followers = await followService.getFollowers(myId, token);
      final following = await followService.getFollowing(myId, token);

      if (mounted) {
        setState(() {
          _followers = followers;
          _following = following;
          _loadingFollows = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow data: $e');
      if (mounted) {
        setState(() => _loadingFollows = false);
      }
    }
  }

  List<dynamic> _getFilteredFollowList(List<dynamic> rawList) {
    final collabIds = _collaborators.map((c) => c['userId'] as String).toSet();
    final myId = _currentUserId;
    return rawList
        .where((u) => u['id'] != myId && !collabIds.contains(u['id']))
        .toList();
  }

  Widget _buildFollowList(List<dynamic> rawList) {
    if (_loadingFollows) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    final list = _getFilteredFollowList(rawList);

    if (list.isEmpty) {
      final isFollowersTab = _activeFollowTab == 0;
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowersTab
                    ? Icons.people_outline_rounded
                    : Icons.person_add_alt_rounded,
                color: Colors.white24,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                isFollowersTab
                    ? 'No followers to invite'
                    : 'No followed users to invite',
                style: const TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.05),
          height: 1,
          indent: 72,
        ),
        itemBuilder: (context, index) {
          final user = list[index];
          final userId = user['id'] as String;
          final name = user['displayName'] as String? ?? 'User';
          final avatar = user['avatarUrl'] as String? ?? '';
          final isInviting = _invitingIds.contains(userId);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.1),
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54, size: 22)
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            trailing: SizedBox(
              width: 90,
              height: 36,
              child: ElevatedButton(
                onPressed: isInviting ? null : () => _inviteUser(userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: isInviting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Invite',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Save event settings ────────────────────────────────────────────────────
  Future<void> _saveSettings() async {
    final token = _token;
    if (token == null) return;

    setState(() => _savingSettings = true);
    try {
      await _eventService.updateEventSettings(
        widget.eventId,
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        _isPrivate,
        token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.onAccent, size: 18),
                SizedBox(width: 10),
                Text(
                  'Settings saved',
                  style: TextStyle(color: AppTheme.onAccent),
                ),
              ],
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  // ── Search users ───────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final token = _token;
    if (token == null) return;
    setState(() => _isSearching = true);

    try {
      final results = await _userService.searchUsers(query, token);
      // Filter out current user AND users who are already collaborators
      final collabIds = _collaborators
          .map((c) => c['userId'] as String)
          .toSet();
      final myId = _currentUserId;
      final filtered = results
          .where((u) => u['id'] != myId && !collabIds.contains(u['id']))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Invite a user ──────────────────────────────────────────────────────────
  Future<void> _inviteUser(String userId) async {
    final token = _token;
    if (token == null) return;

    setState(() => _invitingIds.add(userId));
    try {
      await _eventService.inviteUser(widget.eventId, userId, token);
      await _loadCollaborators();
      // Remove from search results
      setState(() {
        _searchResults.removeWhere((u) => u['id'] == userId);
        _invitingIds.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.person_add, color: AppTheme.onAccent, size: 18),
                SizedBox(width: 10),
                Text(
                  'User invited!',
                  style: TextStyle(color: AppTheme.onAccent),
                ),
              ],
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _invitingIds.remove(userId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to invite: $e')));
      }
    }
  }

  // ── Update collaborator role ───────────────────────────────────────────────
  Future<void> _updateRole(String collaboratorId, String newRole) async {
    final token = _token;
    if (token == null) return;

    try {
      await _eventService.updateCollaboratorRole(
        widget.eventId,
        collaboratorId,
        newRole,
        token,
      );
      await _loadCollaborators();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
      }
    }
  }

  // ── Remove collaborator ────────────────────────────────────────────────────
  Future<void> _removeCollaborator(String collaboratorId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove $name from this event?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final token = _token;
    if (token == null) return;

    try {
      await _eventService.removeCollaborator(
        widget.eventId,
        collaboratorId,
        token,
      );
      await _loadCollaborators();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Listeners'),
            Tab(text: 'Invite'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGeneralTab(), _buildMembersTab(), _buildInviteTab()],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1 — General (name, description, visibility)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Event Name
          const Text(
            'Event Name',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'Enter event name',
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),

          const SizedBox(height: 24),

          // Description
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 4,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'Describe your event...',
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),

          const SizedBox(height: 28),

          // Visibility toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Text(
                _isPrivate ? 'Private Event' : 'Public Event',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _isPrivate
                    ? 'Only invited users can join'
                    : 'Anyone can discover and join',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              secondary: Icon(
                _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                color: _isPrivate ? Colors.orangeAccent : AppTheme.accent,
                size: 24,
              ),
              value: _isPrivate,
              onChanged: (val) => setState(() => _isPrivate = val),
              activeColor: AppTheme.accent,
            ),
          ),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _savingSettings ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: _savingSettings
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2 — Members (current collaborators with role management)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildMembersTab() {
    if (_loadingCollaborators) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    final ownerCollab = _collaborators.firstWhere(
      (c) => c['permission'] == 'owner',
      orElse: () => <String, dynamic>{},
    );
    final ownerId = ownerCollab['userId'] as String?;
    final isCurrentUserOwner = _currentUserId == ownerId;

    if (_collaborators.isEmpty && _listeners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No listeners yet',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to the Invite tab to add people',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final hasListeners = _listeners.isNotEmpty;
    final totalItems =
        1 +
        _collaborators.length +
        (hasListeners ? (1 + _listeners.length) : 0);

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _loadCollaborators,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // 1. Collaborators Header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: AppTheme.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Collaborators (${_collaborators.length})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          // 2. Collaborators Items
          final collabIndex = index - 1;
          if (collabIndex < _collaborators.length) {
            final c = _collaborators[collabIndex];
            final userId = c['userId'] as String;
            final displayName = c['displayName'] as String? ?? 'User';
            final avatarUrl = c['avatarUrl'] as String? ?? '';
            final permission = c['permission'] as String? ?? 'viewer';
            final isMe = userId == _currentUserId;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserPublicProfileScreen(
                      userId: userId,
                      displayName: displayName,
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white54, size: 22)
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: permission == 'owner'
                            ? Colors.orangeAccent.withOpacity(0.15)
                            : (permission == 'editor'
                                  ? AppTheme.accent.withOpacity(0.15)
                                  : Colors.blueGrey.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        permission == 'owner'
                            ? '👑 Owner'
                            : (permission == 'editor'
                                  ? '✏️ Editor'
                                  : '👁 Viewer'),
                        style: TextStyle(
                          color: permission == 'owner'
                              ? Colors.orangeAccent
                              : (permission == 'editor'
                                    ? AppTheme.accent
                                    : Colors.blueGrey[200]),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: (isCurrentUserOwner && !isMe && permission != 'owner')
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white38),
                      color: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'make_editor') {
                          _updateRole(userId, 'editor');
                        } else if (value == 'make_viewer') {
                          _updateRole(userId, 'viewer');
                        } else if (value == 'remove') {
                          _removeCollaborator(userId, displayName);
                        }
                      },
                      itemBuilder: (context) => [
                        if (permission != 'editor')
                          const PopupMenuItem(
                            value: 'make_editor',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: AppTheme.accent,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Make Editor',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        if (permission != 'viewer')
                          const PopupMenuItem(
                            value: 'make_viewer',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Colors.blueGrey,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Make Viewer',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Remove',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
            );
          }

          // 3. Active Listeners Header
          final relativeIndex = collabIndex - _collaborators.length;
          if (relativeIndex == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.headset_rounded,
                    color: Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Listeners (${_listeners.length})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          // 4. Active Listeners Items
          final listenerIndex = relativeIndex - 1;
          final listener = _listeners[listenerIndex];
          final userId = listener['userId'] as String;
          final displayName = listener['displayName'] as String? ?? 'User';
          final avatarUrl = listener['avatarUrl'] as String? ?? '';
          final isMe = userId == _currentUserId;

          final collabIndexForListener = _collaborators.indexWhere(
            (c) => c['userId'] == userId,
          );
          final String permission = collabIndexForListener != -1
              ? _collaborators[collabIndexForListener]['permission']
                        as String? ??
                    'viewer'
              : 'viewer';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserPublicProfileScreen(
                    userId: userId,
                    displayName: displayName,
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.1),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54, size: 22)
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: permission == 'owner'
                          ? Colors.orangeAccent.withOpacity(0.15)
                          : (permission == 'editor'
                                ? AppTheme.accent.withOpacity(0.15)
                                : Colors.blueGrey.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      permission == 'owner'
                          ? '👑 Owner'
                          : (permission == 'editor'
                                ? '✏️ Editor'
                                : '👁 Viewer'),
                      style: TextStyle(
                        color: permission == 'owner'
                            ? Colors.orangeAccent
                            : (permission == 'editor'
                                  ? AppTheme.accent
                                  : Colors.blueGrey[200]),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: AppTheme.accent,
                          size: 12,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Listening Now',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing: (isCurrentUserOwner && !isMe && permission != 'owner')
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white38),
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'make_editor') {
                        _updateRole(userId, 'editor');
                      } else if (value == 'make_viewer') {
                        _updateRole(userId, 'viewer');
                      } else if (value == 'remove') {
                        _removeCollaborator(userId, displayName);
                      }
                    },
                    itemBuilder: (context) => [
                      if (permission != 'editor')
                        const PopupMenuItem(
                          value: 'make_editor',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: AppTheme.accent,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Make Editor',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      if (permission != 'viewer')
                        const PopupMenuItem(
                          value: 'make_viewer',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.blueGrey,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Make Viewer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      if (collabIndexForListener != -1) ...[
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Remove',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 3 — Invite (search users by name and add)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildInviteTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white38,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'Search users by name...',
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),
        ),

        // Results
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: CircularProgressIndicator(color: AppTheme.accent),
          )
        else if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    color: Colors.white24,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No users found',
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else if (_searchController.text.isEmpty) ...[
          // Toggle Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeFollowTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeFollowTab == 0
                            ? AppTheme.accent
                            : Colors.white.withOpacity(0.06),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Followers (${_getFilteredFollowList(_followers).length})',
                        style: TextStyle(
                          color: _activeFollowTab == 0
                              ? AppTheme.onAccent
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeFollowTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeFollowTab == 1
                            ? AppTheme.accent
                            : Colors.white.withOpacity(0.06),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Following (${_getFilteredFollowList(_following).length})',
                        style: TextStyle(
                          color: _activeFollowTab == 1
                              ? AppTheme.onAccent
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFollowList(_activeFollowTab == 0 ? _followers : _following),
        ] else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withOpacity(0.05),
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final userId = user['id'] as String;
                final name = user['displayName'] as String? ?? 'User';
                final avatar = user['avatarUrl'] as String? ?? '';
                final isInviting = _invitingIds.contains(userId);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 22,
                          )
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  trailing: SizedBox(
                    width: 90,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: isInviting ? null : () => _inviteUser(userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: isInviting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Invite',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
