// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final authUser = ref.watch(authStateProvider).value;
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        actions: [
          if (!_editing)
            TextButton.icon(
              onPressed: () => _startEditing(profileAsync.value),
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.secondary, size: 18),
              label: Text('Edit',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.secondary, fontSize: 14)),
            ),
          if (_editing)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textHint, fontSize: 14)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          final name = profile?['full_name'] as String? ?? 'User';
          final phone = profile?['phone'] as String? ?? '';
          final email = authUser?.email ?? '';
          final avatar = profile?['avatar_url'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar & name section
                _buildAvatarSection(name, role, avatar)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1),

                const SizedBox(height: 28),

                // Profile fields
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E2A3A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal Information',
                          style: GoogleFonts.playfairDisplay(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 16),
                      if (_editing) ...[
                        _buildEditField(
                          label: 'Full Name',
                          controller: _nameCtrl,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        _buildEditField(
                          label: 'Phone Number',
                          controller: _phoneCtrl,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving
                                ? null
                                : () => _saveProfile(authUser?.id),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black))
                                : Text('Save Changes',
                                    style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ] else ...[
                        _InfoTile(
                            icon: Icons.person_outline,
                            label: 'Full Name',
                            value: name),
                        const Divider(height: 20),
                        _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email),
                        const Divider(height: 20),
                        _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: phone.isEmpty ? 'Not set' : phone),
                        const Divider(height: 20),
                        _InfoTile(
                            icon: Icons.badge_outlined,
                            label: 'Role',
                            value: role.toUpperCase(),
                            valueColor: _roleColor(role)),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 20),

                // Password change
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E2A3A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Security',
                          style: GoogleFonts.playfairDisplay(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: AppTheme.info, size: 20),
                        ),
                        title: Text('Change Password',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text('Update your account password',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: AppTheme.textHint, size: 14),
                        onTap: () => _showChangePasswordDialog(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 20),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Sign Out',
                        message: 'Are you sure you want to sign out?',
                        confirmText: 'Sign Out',
                        isDanger: true,
                      );
                      if (confirmed) {
                        await ref.read(authNotifierProvider.notifier).signOut();
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text('Sign Out',
                        style: GoogleFonts.dmSans(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(error: e.toString()),
      ),
    );
  }

  Widget _buildAvatarSection(String name, String role, String? avatarUrl) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: _roleColor(role).withValues(alpha: 0.15),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.playfairDisplay(
                    color: _roleColor(role),
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor(role).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _roleColor(role).withValues(alpha: 0.3)),
          ),
          child: Text(
            role.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: _roleColor(role),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.textHint, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.secondary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _startEditing(Map<String, dynamic>? profile) {
    _nameCtrl.text = profile?['full_name'] as String? ?? '';
    _phoneCtrl.text = profile?['phone'] as String? ?? '';
    setState(() => _editing = true);
  }

  Future<void> _saveProfile(String? userId) async {
    if (userId == null) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(
        userId: userId,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      showAppSnackbar(context, 'Profile updated successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(context, 'Failed to save: $e', isError: true);
    }
  }

  void _showChangePasswordDialog() {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Change Password',
            style: GoogleFonts.playfairDisplay(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(controller: newCtrl, label: 'New Password'),
            const SizedBox(height: 12),
            _PasswordField(
                controller: confirmCtrl, label: 'Confirm New Password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppTheme.textHint)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                showAppSnackbar(context, 'Passwords do not match',
                    isError: true);
                return;
              }
              if (newCtrl.text.length < 6) {
                showAppSnackbar(
                    context, 'Password must be at least 6 characters',
                    isError: true);
                return;
              }
              try {
                final repo = ref.read(authRepositoryProvider);
                await repo.updatePassword(newCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                showAppSnackbar(ctx, 'Password changed successfully',
                    isSuccess: true);
              } catch (e) {
                if (!ctx.mounted) return;
                showAppSnackbar(ctx, 'Failed to change password: $e',
                    isError: true);
              }
            },
            child: Text('Change',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case AppConstants.roleAdmin:
        return AppTheme.secondary;
      case AppConstants.roleReceptionist:
        return AppTheme.info;
      case AppConstants.roleBarber:
        return Colors.purple;
      default:
        return AppTheme.success;
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.textHint, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textHint, fontSize: 11)),
              Text(value,
                  style: GoogleFonts.dmSans(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const _PasswordField({required this.controller, required this.label});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textHint, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}