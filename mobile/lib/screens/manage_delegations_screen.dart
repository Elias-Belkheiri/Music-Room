import 'package:flutter/material.dart';
import 'package:musicroom/config/app_theme.dart';
import 'package:musicroom/models/delegation_model.dart';
import 'package:musicroom/models/user_profile_model.dart';
import 'package:musicroom/providers/auth_provider.dart';
import 'package:musicroom/services/delegation_service.dart';
import 'package:musicroom/services/user_service.dart';
import 'package:provider/provider.dart';

class ManageDelegationsScreen extends StatefulWidget {
  final String resourceId;
  final String resourceType; // PLAYLIST, EVENT
  final String resourceName;

  const ManageDelegationsScreen({
    super.key,
    required this.resourceId,
    required this.resourceType,
    required this.resourceName,
  });

  @override
  State<ManageDelegationsScreen> createState() => _ManageDelegationsScreenState();
}

class _ManageDelegationsScreenState extends State<ManageDelegationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DelegationService _delegationService = DelegationService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  List<dynamic> _friends = [];
  List<DelegationModel> _delegations = [];
  UserProfileModel? _currentUserProfile;

  // New Delegation Form State
  String? _selectedFriendId;
  String _selectedRole = 'ADMIN'; // ADMIN, VIEWER
  int _selectedDurationHours = 0; // 0 for Permanent

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = await _userService.getCurrentUserProfile(token);
      final friends = await _userService.getFriends(token);
      final delegations = await _delegationService.getDelegations(
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
        token: token,
      );

      setState(() {
        _currentUserProfile = profile;
        _friends = friends;
        _delegations = delegations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load delegation data: $e')),
      );
    }
  }

  Future<void> _createDelegation() async {
    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a friend first')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    DateTime? expiresAt;
    if (_selectedDurationHours > 0) {
      expiresAt = DateTime.now().add(Duration(hours: _selectedDurationHours));
    }

    setState(() => _isLoading = true);

    try {
      await _delegationService.createDelegation(
        delegateId: _selectedFriendId!,
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
        permissionLevel: _selectedRole,
        token: token,
        expiresAt: expiresAt,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Co-Host permission granted successfully!')),
      );

      // Reset selection and refresh
      _selectedFriendId = null;
      _selectedRole = 'ADMIN';
      _selectedDurationHours = 0;
      await _loadData();
      _tabController.animateTo(0); // Switch to active delegations tab
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create delegation: $e')),
      );
    }
  }

  Future<void> _revokeDelegation(String delegationId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      await _delegationService.removeDelegation(
        delegationId: delegationId,
        token: token,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission revoked successfully!')),
      );

      await _loadData();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke permission: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'Manage Co-Hosts',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              widget.resourceName,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          tabs: const [
            Tab(text: 'Active Co-Hosts', icon: Icon(Icons.people_outline)),
            Tab(text: 'Delegate Access', icon: Icon(Icons.person_add_alt_1_outlined)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveDelegationsTab(),
                _buildNewDelegationTab(),
              ],
            ),
    );
  }

  Widget _buildActiveDelegationsTab() {
    if (_delegations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: Colors.grey[700], size: 64),
            const SizedBox(height: 16),
            Text(
              'No active co-hosts assigned',
              style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Delegate rights to friends to let them assist you.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _delegations.length,
      itemBuilder: (context, index) {
        final delegation = _delegations[index];

        // Match delegate friend's display name if loaded
        String displayName = 'Co-Host';
        for (var friendship in _friends) {
          final friend = friendship['requester']['id'] == _currentUserProfile?.id
              ? friendship['addressee']
              : friendship['requester'];
          if (friend['id'] == delegation.delegateId) {
            displayName = friend['displayName'] ?? 'Co-Host';
            break;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: delegation.permissionLevel == 'ADMIN' 
                    ? AppTheme.accent.withOpacity(0.2) 
                    : Colors.blue.withOpacity(0.2),
                child: Icon(
                  delegation.permissionLevel == 'ADMIN' ? Icons.security : Icons.remove_red_eye,
                  color: delegation.permissionLevel == 'ADMIN' ? AppTheme.accent : Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${delegation.permissionLevel}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    if (delegation.expiresAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Expires: ${delegation.expiresAt!.toLocal().toString().substring(0, 16)}',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _showRevokeConfirmDialog(delegation),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewDelegationTab() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, color: Colors.grey[700], size: 64),
            const SizedBox(height: 16),
            Text(
              'No friends found',
              style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends first in your profile tab to delegate rights.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    final List<DropdownMenuItem<String>> friendItems = _friends.map((friendship) {
      final friend = friendship['requester']['id'] == _currentUserProfile?.id
          ? friendship['addressee']
          : friendship['requester'];
      return DropdownMenuItem<String>(
        value: friend['id'] as String,
        child: Text(
          friend['displayName'] ?? 'Friend',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Friend',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFriendId,
                hint: const Text('Choose a friend...', style: TextStyle(color: Colors.white30)),
                dropdownColor: AppTheme.surface,
                isExpanded: true,
                items: friendItems,
                onChanged: (val) => setState(() => _selectedFriendId = val),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose Role / Permission Level',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleCard('ADMIN', 'Full Control', 'Can add, remove tracks & play/pause room', Icons.admin_panel_settings),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRoleCard('VIEWER', 'DJ Assistant', 'Can suggest and upvote tracks only', Icons.music_note),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Access Duration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildDurationChip(0, 'Permanent'),
              _buildDurationChip(1, '1 Hour'),
              _buildDurationChip(4, '4 Hours'),
              _buildDurationChip(24, '1 Day'),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedFriendId == null ? null : _createDelegation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: const Text(
                'Grant Access Rights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String title, String subtitle, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.05),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : Colors.grey[500], size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(int hours, String label) {
    final isSelected = _selectedDurationHours == hours;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400])),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDurationHours = hours);
        }
      },
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void _showRevokeConfirmDialog(DelegationModel delegation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Revoke Co-Host Access?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to revoke access for this co-host? They will instantly lose DJ/control permissions.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _revokeDelegation(delegation.id);
            },
            child: const Text('Revoke Access', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
