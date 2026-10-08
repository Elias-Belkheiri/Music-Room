import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/follow_service.dart';
import '../user_public_profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final int initialTab; // 0 for Followers, 1 for Following

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTab = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  bool _isLoading = true;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  String _followersSearchQuery = '';
  String _followingSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    try {
      final followService = FollowService();
      final results = await Future.wait([
        followService.getFollowers(widget.userId, token),
        followService.getFollowing(widget.userId, token),
      ]);

      if (mounted) {
        setState(() {
          _followers = results[0];
          _following = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load connections: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredList(List<dynamic> list, String query) {
    if (query.trim().isEmpty) return list;
    return list.where((user) {
      final name = (user['displayName'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : TabBarView(
                children: [
                  _buildListSection(
                    list: _followers,
                    searchQuery: _followersSearchQuery,
                    onSearchChanged: (val) {
                      setState(() {
                        _followersSearchQuery = val;
                      });
                    },
                    emptyMessage: 'No followers yet',
                  ),
                  _buildListSection(
                    list: _following,
                    searchQuery: _followingSearchQuery,
                    onSearchChanged: (val) {
                      setState(() {
                        _followingSearchQuery = val;
                      });
                    },
                    emptyMessage: 'Not following anyone yet',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildListSection({
    required List<dynamic> list,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
    required String emptyMessage,
  }) {
    final filteredList = _getFilteredList(list, searchQuery);

    return Column(
      children: [
        // Local search input
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search people...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF242424),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.trim().isNotEmpty
                        ? 'No matches found'
                        : emptyMessage,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final user = filteredList[index];
                    final userId = user['id'] ?? '';
                    final displayName = user['displayName'] ?? 'Unknown User';
                    final avatarUrl = user['avatarUrl'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () {
                          // Prevent navigating to oneself in dynamic profiles
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          if (userId == auth.currentUser?.id) {
                            Navigator.pop(context); // just pop or do nothing
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserPublicProfileScreen(
                                  userId: userId,
                                  displayName: displayName,
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: avatarUrl != null &&
                                      avatarUrl.isNotEmpty &&
                                      !avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              backgroundColor: Colors.grey[800],
                              child: avatarUrl == null ||
                                      avatarUrl.isEmpty ||
                                      avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
                                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ],
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
