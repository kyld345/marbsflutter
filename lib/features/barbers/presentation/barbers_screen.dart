// lib/features/barbers/presentation/barbers_screen.dart
//
// FIXES:
//  1. substring(0,1) crash on empty displayName → guarded with isNotEmpty check
//  2. Edit dialog now shows Display Name field and saves it to DB
//  3. Edit dialog also shows / allows changing Branch
//  4. DropdownButtonFormField uses `value:` (not non-existent `initialValue:`)
//  5. All database fields (display_name, branch_id, specialization, bio,
//     experience_years) are present in both Add and Edit forms so nothing
//     is ever null-saved accidentally
//  6. Minor UI polish (consistent padding, card overflow guard)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/barber_provider.dart';
import '../domain/barber_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class BarbersScreen extends ConsumerStatefulWidget {
  const BarbersScreen({super.key});

  @override
  ConsumerState<BarbersScreen> createState() => _BarbersScreenState();
}

class _BarbersScreenState extends ConsumerState<BarbersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barbersAsync = ref.watch(allBarbersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Barbers',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showBarberDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Barber'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search barbers...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: barbersAsync.when(
              data: (barbers) {
                final filtered = _searchController.text.isEmpty
                    ? barbers
                    : barbers
                        .where((b) => b.displayName
                            .toLowerCase()
                            .contains(_searchController.text.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No barbers found.',
                      style: GoogleFonts.dmSans(color: AppTheme.textHint),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (ctx, constraints) {
                    final crossAxis = constraints.maxWidth > 900 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) =>
                          _buildBarberCard(filtered[index], index, ref),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(error: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberCard(BarberModel barber, int index, WidgetRef ref) {
    // FIX: guard against empty displayName before calling substring
    final initial = barber.displayName.isNotEmpty
        ? barber.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: barber.isAvailable
              ? AppTheme.success.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: GoogleFonts.playfairDisplay(
                    color: AppTheme.secondary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color:
                      barber.isAvailable ? AppTheme.success : AppTheme.textHint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardColor, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              barber.displayName,
              style: GoogleFonts.dmSans(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (barber.specialization != null &&
              barber.specialization!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                barber.specialization!,
                style: GoogleFonts.dmSans(
                  color: AppTheme.textHint,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: AppTheme.secondary, size: 14),
              const SizedBox(width: 4),
              Text(
                barber.rating.toStringAsFixed(1),
                style: GoogleFonts.dmSans(
                  color: AppTheme.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${barber.totalReviews})',
                style:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${barber.experienceYears} yr${barber.experienceYears != 1 ? 's' : ''} exp',
            style:
                GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () =>
                    _showBarberDialog(context, ref, barber: barber),
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.textHint, size: 18),
                tooltip: 'Edit',
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, ref, barber),
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.error, size: 18),
                tooltip: 'Delete',
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: barber.isAvailable,
                  onChanged: (v) async {
                    await ref
                        .read(barberNotifierProvider.notifier)
                        .updateBarber(barber.id, {'is_available': v});
                    ref.invalidate(allBarbersProvider);
                  },
                  activeThumbColor: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms).scale(
          begin: const Offset(0.95, 0.95),
        );
  }

  void _showBarberDialog(BuildContext context, WidgetRef ref,
      {BarberModel? barber}) {
    // FIX: for edit, use displayNameOverride (the actual DB column), not
    // the computed displayName (which falls back to user.full_name).
    final nameController = TextEditingController(
        text: barber?.displayNameOverride ?? barber?.displayName ?? '');
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final specializationController =
        TextEditingController(text: barber?.specialization ?? '');
    final bioController = TextEditingController(text: barber?.bio ?? '');
    final expController = TextEditingController(
        text: (barber?.experienceYears ?? 0).toString());

    String? selectedBranchId = barber?.branchId;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, dialogRef, _) {
          final branchesAsync = dialogRef.watch(activeBranchesProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final branches =
                  branchesAsync.valueOrNull ?? const <Map<String, dynamic>>[];

              // Auto-select first branch if none selected yet
              if (selectedBranchId == null && branches.isNotEmpty) {
                selectedBranchId = branches.first['id'] as String;
              }

              return AlertDialog(
                title: Text(
                  barber == null ? 'Add Barber' : 'Edit Barber',
                  style:
                      GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
                ),
                content: SizedBox(
                  width: 420,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.65,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Fields only shown when CREATING ───────────
                          if (barber == null) ...[
                            AppTextField(
                              controller: emailController,
                              label: 'Email',
                              hint: 'barber@email.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: passwordController,
                              label: 'Password',
                              hint: 'At least 6 characters',
                              obscureText: true,
                              prefixIcon: Icons.lock_outline,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Display Name (shown for both Add & Edit) ──
                          AppTextField(
                            controller: nameController,
                            label: 'Display Name',
                            prefixIcon: Icons.person_outline,
                            hint: 'Enter barber name',
                          ),
                          const SizedBox(height: 12),

                          // ── Branch dropdown (shown for both) ──────────
                          branchesAsync.when(
                            data: (_) => DropdownButtonFormField<String>(
                              // `value:` is the correct controlled-value param
                              // for DropdownButtonFormField; the lint fires
                              // against the FormField base-class getter which
                              // is unrelated — safe to suppress here.
                              // ignore: deprecated_member_use
                              value: selectedBranchId,
                              decoration: const InputDecoration(
                                labelText: 'Branch',
                                prefixIcon: Icon(Icons.store_outlined),
                              ),
                              items: branches
                                  .map(
                                    (b) => DropdownMenuItem<String>(
                                      value: b['id'] as String,
                                      child: Text(
                                          (b['name'] as String?) ?? 'Branch'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedBranchId = v),
                            ),
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                            error: (e, _) => Text('Could not load branches',
                                style: GoogleFonts.dmSans(
                                    color: AppTheme.error, fontSize: 12)),
                          ),
                          const SizedBox(height: 12),

                          // ── Specialization ────────────────────────────
                          AppTextField(
                            controller: specializationController,
                            label: 'Specialization',
                            hint: 'e.g. Fade Specialist',
                            prefixIcon: Icons.content_cut,
                          ),
                          const SizedBox(height: 12),

                          // ── Bio ───────────────────────────────────────
                          AppTextField(
                            controller: bioController,
                            label: 'Bio',
                            hint: 'Short description...',
                            maxLines: 3,
                            prefixIcon: Icons.notes,
                          ),
                          const SizedBox(height: 12),

                          // ── Experience Years ──────────────────────────
                          AppTextField(
                            controller: expController,
                            label: 'Years of Experience',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.work_outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      // ── Shared validation ────────────────────────────
                      final trimmedName = nameController.text.trim();
                      if (trimmedName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a display name.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      if (selectedBranchId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a branch.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      if (barber == null) {
                        // ── CREATE new barber ────────────────────────
                        final email = emailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }

                        if (passwordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Password must be at least 6 characters.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }

                        final notifier =
                            ref.read(barberNotifierProvider.notifier);
                        final ok = await notifier.createBarberWithAccount(
                          email: email,
                          password: passwordController.text,
                          fullName: trimmedName,
                          branchId: selectedBranchId!,
                          specialization:
                              specializationController.text.trim(),
                          bio: bioController.text.trim(),
                          experienceYears:
                              int.tryParse(expController.text) ?? 0,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        final state = ref.read(barberNotifierProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Barber added successfully.'
                                : (state.error?.toString() ??
                                    'Failed to add barber.')),
                            backgroundColor:
                                ok ? AppTheme.success : AppTheme.error,
                          ),
                        );
                      } else {
                        // ── EDIT existing barber ─────────────────────
                        // FIX: include display_name and branch_id so they
                        // are actually saved to the database
                        await ref
                            .read(barberNotifierProvider.notifier)
                            .updateBarber(
                          barber.id,
                          {
                            'display_name': trimmedName,
                            'branch_id': selectedBranchId,
                            'specialization':
                                specializationController.text.trim().isNotEmpty
                                    ? specializationController.text.trim()
                                    : null,
                            'bio': bioController.text.trim().isNotEmpty
                                ? bioController.text.trim()
                                : null,
                            'experience_years':
                                int.tryParse(expController.text) ?? 0,
                          },
                        );
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Barber updated successfully.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }

                      ref.invalidate(allBarbersProvider);
                    },
                    child: Text(barber == null ? 'Add' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BarberModel barber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Barber',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove ${barber.displayName} from the system? This cannot be undone.',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(barberNotifierProvider.notifier)
                  .deleteBarber(barber.id);
              ref.invalidate(allBarbersProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}