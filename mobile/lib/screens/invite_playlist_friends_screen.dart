import 'package:flutter/material.dart';
import 'package:musicroom/config/app_theme.dart';
import 'package:musicroom/providers/auth_provider.dart';
import 'package:musicroom/services/playlist_service.dart';
import 'package:musicroom/services/user_service.dart';
import 'package:musicroom/services/follow_service.dart';
import 'package:provider/provider.dart';

class InvitePlaylistFriendsScreen extends StatefulWidget {
  final String playlistId;
  const InvitePlaylistFriendsScreen({super.key, required this.playlistId});

  @override
  State<InvitePlaylistFriendsScreen> createState() =>
      _InvitePlaylistFriendsScreenState();
}

class _InvitePlaylistFriendsScreenState
    extends State<InvitePlaylistFriendsScreen> {
  bool _isLoading = true;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  List<dynamic> _searchResults = [];
  final Set<String> _selectedCollaborators = {};
  final Set<String> _existingCollaboratorIds = {};
  String _permission = 'editor'; // Default to editor for collaborators
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) {
      return;
    }

    try {
      final currentUser = await UserService().getCurrentUserProfile(token);
      final followers = await FollowService().getFollowers(
        currentUser.id,
        token,
      );
      final following = await FollowService().getFollowing(
        currentUser.id,
        token,
      );

      final playlistService = PlaylistService();
      try {
        final playlist = await playlistService.getPlaylistById(
          widget.playlistId,
          token,
        );
        _existingCollaboratorIds.add(playlist.ownerId);
      } catch (e) {
        debugPrint('Error loading playlist owner: $e');
      }

      try {
        final collaborators = await playlistService.getPlaylistCollaborators(
          widget.playlistId,
          token,
        );
        for (var c in collaborators) {
          final cid = c['userId'] as String?;
          if (cid != null) {
            _existingCollaboratorIds.add(cid);
          }
        }
      } catch (e) {
        debugPrint('Error loading existing collaborators: $e');
      }

      setState(() {
        _followers = followers;
        _following = following;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    final myId = authProvider.currentUser?.id;
    if (token == null) return;

    try {
      final results = await UserService().searchUsers(query, token);
      setState(() {
        _searchResults = results.where((u) => u['id'] != myId).toList();
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  void _sendInvites() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    setState(() {
      _isLoading = true;
    });

    int successCount = 0;
    int conflictCount = 0;
    String? lastError;

    try {
      final playlistService = PlaylistService();
      for (String collaboratorId in _selectedCollaborators) {
        try {
          await playlistService.inviteUserToPlaylist(
            widget.playlistId,
            collaboratorId,
            _permission,
            token,
          );
          successCount++;
        } catch (e) {
          if (e.toString().contains('409')) {
            conflictCount++;
          } else {
            lastError = e.toString();
          }
        }
      }

      if (mounted) {
        if (lastError != null && successCount == 0) {
          throw Exception(lastError);
        }

        String msg = 'Collaborators updated!';
        if (successCount > 0 && conflictCount > 0) {
          msg =
              'Successfully invited $successCount collaborators (others were already added).';
        } else if (successCount > 0) {
          msg = 'Collaborators invited successfully!';
        } else if (conflictCount > 0) {
          msg = 'Selected users are already collaborators.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.accent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add collaborators: $e')),
        );
      }
    }
  }

  Widget _buildUserTile(
    String userId,
    String displayName,
    String? avatarUrl,
    bool isSelected,
  ) {
    if (_existingCollaboratorIds.contains(userId)) {
      return ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundImage:
              avatarUrl != null &&
                  avatarUrl.isNotEmpty &&
                  !avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
              ? NetworkImage(avatarUrl)
              : null,
          backgroundColor: Colors.grey[800],
          child:
              avatarUrl == null ||
                  avatarUrl.isEmpty ||
                  avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Already Added',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: const Text(
            'Added',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return CheckboxListTile(
      secondary: CircleAvatar(
        radius: 20,
        backgroundImage:
            avatarUrl != null &&
                avatarUrl.isNotEmpty &&
                !avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
            ? NetworkImage(avatarUrl)
            : null,
        backgroundColor: Colors.grey[800],
        child:
            avatarUrl == null ||
                avatarUrl.isEmpty ||
                avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: isSelected,
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            _selectedCollaborators.add(userId);
          } else {
            _selectedCollaborators.remove(userId);
          }
        });
      },
      activeColor: AppTheme.accent,
      checkColor: AppTheme.onAccent,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No people found.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = user['id'] ?? '';
        final displayName = user['displayName'] ?? 'Unknown User';
        final avatarUrl = user['avatarUrl'];
        final isSelected = _selectedCollaborators.contains(userId);

        return _buildUserTile(userId, displayName, avatarUrl, isSelected);
      },
    );
  }

  Widget _buildFollowList(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No people here yet.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final user = list[index];
        final userId = user['id'] ?? '';
        final displayName = user['displayName'] ?? 'Unknown User';
        final avatarUrl = user['avatarUrl'];
        final isSelected = _selectedCollaborators.contains(userId);

        return _buildUserTile(userId, displayName, avatarUrl, isSelected);
      },
    );
  }

  Widget _buildTabsAndLists() {
    return Column(
      children: [
        const TabBar(
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _buildFollowList(_followers),
              _buildFollowList(_following),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.trim().isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Add Collaborators',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Permission: ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          dropdownColor: AppTheme.surface,
                          value: _permission,
                          items: const [
                            DropdownMenuItem(
                              value: 'editor',
                              child: Text(
                                'Editor',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'viewer',
                              child: Text(
                                'Viewer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _permission = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search people by name...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white54,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: isSearching
                        ? _buildSearchResultsList()
                        : _buildTabsAndLists(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _selectedCollaborators.isEmpty
                            ? null
                            : _sendInvites,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Add Collaborators',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
