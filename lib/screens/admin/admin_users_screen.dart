import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';

/// User management panel — visible to superadmin only.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = '';

  static const _roles = ['', 'user', 'booking', 'admin'];
  static const _roleLabels = ['All', 'User', 'Booking', 'Admin'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search() {
    context.read<AdminProvider>().loadUsers(
          role: _roleFilter.isEmpty ? null : _roleFilter,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          color: const Color(0xCC170F0F),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchCtrl.clear();
                        _search();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2A1212),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Role filter chips
        Container(
          color: const Color(0xCC170F0F),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_roles.length, (i) {
                final selected = _roleFilter == _roles[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_roleLabels[i]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _roleFilter = _roles[i]);
                      _search();
                    },
                    selectedColor: AppColors.primaryRed.withOpacity(0.3),
                    checkmarkColor: AppColors.primaryRed,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primaryRed : Colors.white70,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF2A1212),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryRed
                          : Colors.white24,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // User list
        Expanded(
          child: Consumer<AdminProvider>(
            builder: (context, adminProvider, _) {
              if (adminProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryRed),
                  ),
                );
              }

              if (adminProvider.users.isEmpty) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xBF170F0F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFAF0406), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off,
                            size: 64,
                            color: AppColors.primaryRed.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('No users found',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.primaryRed,
                onRefresh: () => adminProvider.loadUsers(
                  role: _roleFilter.isEmpty ? null : _roleFilter,
                  search: _searchCtrl.text.trim().isEmpty
                      ? null
                      : _searchCtrl.text.trim(),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: adminProvider.users.length,
                  itemBuilder: (context, index) {
                    return _buildUserCard(
                        adminProvider.users[index], adminProvider);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
      Map<String, dynamic> user, AdminProvider adminProvider) {
    final role = user['role'] as String? ?? 'user';
    final name = user['name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final userId = user['id'] as String? ?? '';
    final isSuperAdmin = role == 'superadmin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC170F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A1A1A), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _roleColor(role).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: _roleColor(role).withOpacity(0.5)),
            ),
            child: Icon(Icons.person, color: _roleColor(role), size: 24),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                _roleBadge(role),
              ],
            ),
          ),

          // Actions — disabled for superadmin
          if (!isSuperAdmin) ...[
            const SizedBox(width: 8),
            Column(
              children: [
                _RoleDropdown(
                  currentRole: role,
                  onChanged: (newRole) async {
                    final ok =
                        await adminProvider.changeUserRole(userId, newRole);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Role updated to $newRole'
                            : adminProvider.errorMessage ?? 'Error'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ));
                    }
                  },
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _confirmDelete(userId, name, adminProvider),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.4), width: 1),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _roleColor(role).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _roleColor(role).withOpacity(0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
            color: _roleColor(role),
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmDelete(
      String userId, String name, AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1010),
        title: const Text('Delete User',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "$name"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await adminProvider.deleteUser(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? '$name deleted'
                      : adminProvider.errorMessage ?? 'Error'),
                  backgroundColor: ok ? Colors.orange : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'superadmin' => const Color(0xFFE040FB),
      'admin' => const Color(0xFFFF5722),
      'booking' => const Color(0xFF1E88E5),
      _ => Colors.white54,
    };
  }
}

/// Compact dropdown to change a user's role
class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.currentRole,
    required this.onChanged,
  });

  final String currentRole;
  final void Function(String) onChanged;

  static const _options = ['user', 'booking', 'admin'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<String>(
        value: _options.contains(currentRole) ? currentRole : null,
        hint: const Text('Role', style: TextStyle(color: Colors.white54, fontSize: 12)),
        dropdownColor: const Color(0xFF2A1212),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
        items: _options
            .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null && v != currentRole) onChanged(v);
        },
      ),
    );
  }
}
