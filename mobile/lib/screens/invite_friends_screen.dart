import 'package:flutter/material.dart';
import 'package:musicroom/config/app_theme.dart';
import 'package:musicroom/models/user_profile_model.dart';
import 'package:musicroom/providers/auth_provider.dart';
import 'package:musicroom/services/event_service.dart';
import 'package:musicroom/services/user_service.dart';
import 'package:provider/provider.dart';

class InviteFriendsScreen extends StatefulWidget {
  final String eventId;
  const InviteFriendsScreen({super.key, required this.eventId});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  bool _isLoading = true;
  List<dynamic> _friends = [];
  final Set<String> _selectedFriends = {};
  UserProfileModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) {
      // Handle not logged in
      return;
    }

    try {
      final currentUser = await UserService().getCurrentUserProfile(token);
      final friends = await UserService().getFriends(token);
      setState(() {
        _currentUser = currentUser;
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  void _sendInvites() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    try {
      for (String friendId in _selectedFriends) {
        await EventService().inviteUser(widget.eventId, friendId, token);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitations sent successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send invitations: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Invite Friends',
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
                Expanded(
                  child: ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friendship = _friends[index];
                      final friend =
                          friendship['requester']['id'] == _currentUser!.id
                          ? friendship['addressee']
                          : friendship['requester'];
                      final friendId = friend['id'];
                      final isSelected = _selectedFriends.contains(friendId);

                      return CheckboxListTile(
                        title: Text(
                          friend['displayName'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFriends.add(friendId);
                            } else {
                              _selectedFriends.remove(friendId);
                            }
                          });
                        },
                        activeColor: AppTheme.accent,
                        checkColor: AppTheme.onAccent,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedFriends.isEmpty ? null : _sendInvites,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Send Invites',
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
    );
  }
}
