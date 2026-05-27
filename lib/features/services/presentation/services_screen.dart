// lib/features/services/presentation/services_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/service_provider.dart';
import '../domain/service_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Services',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showServiceDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Service'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search services...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: servicesAsync.when(
              data: (services) {
                final filtered = _searchController.text.isEmpty
                    ? services
                    : services
                        .where((s) => s.name
                            .toLowerCase()
                            .contains(_searchController.text.toLowerCase()))
                        .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildServiceTile(filtered[i], i, ref),
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

  Widget _buildServiceTile(ServiceModel service, int index, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: service.isActive
            ? null
            : Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: service.isActive
                ? AppTheme.secondary.withValues(alpha: 0.1)
                : AppTheme.textHint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.content_cut,
              color: service.isActive ? AppTheme.secondary : AppTheme.textHint,
              size: 22),
        ),
        title: Row(
          children: [
            Text(service.name,
                style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            if (!service.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Inactive',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.error, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (service.description != null)
              Text(service.description!,
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textHint, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text('${service.durationMinutes} min',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₱${service.price.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(
                    color: AppTheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textHint),
              color: AppTheme.surface,
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _showServiceDialog(context, ref, service: service);
                    break;
                  case 'toggle':
                    ref.read(serviceNotifierProvider.notifier).updateService(
                        service.id, {'is_active': !service.isActive});
                    ref.invalidate(allServicesProvider);
                    break;
                  case 'delete':
                    _confirmDelete(context, ref, service);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text('Edit',
                        style: GoogleFonts.dmSans(color: AppTheme.textPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                        service.isActive
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined,
                        color: AppTheme.textSecondary,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(service.isActive ? 'Deactivate' : 'Activate',
                        style: GoogleFonts.dmSans(color: AppTheme.textPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete',
                        style: GoogleFonts.dmSans(color: AppTheme.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms);
  }

  void _showServiceDialog(BuildContext context, WidgetRef ref,
      {ServiceModel? service}) {
    final nameCtrl = TextEditingController(text: service?.name ?? '');
    final descCtrl = TextEditingController(text: service?.description ?? '');
    final priceCtrl =
        TextEditingController(text: service?.price.toStringAsFixed(0) ?? '');
    final durationCtrl = TextEditingController(
        text: service?.durationMinutes.toString() ?? '30');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          service == null ? 'Add Service' : 'Edit Service',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: 'Service Name',
                  prefixIcon: Icons.content_cut,
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: descCtrl,
                  label: 'Description',
                  maxLines: 2,
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: priceCtrl,
                        label: 'Price (₱)',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.payments_outlined,
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: durationCtrl,
                        label: 'Duration (min)',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.timer_outlined,
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              // FIX: Parse numbers safely with try/catch BEFORE closing the
              // dialog, so the user can correct the input if parsing fails.
              double price;
              int duration;
              try {
                price = double.parse(priceCtrl.text.trim());
                duration = int.parse(durationCtrl.text.trim());
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid price or duration value.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }

              // FIX: Close AFTER the operation so errors can be shown.
              bool ok;
              if (service == null) {
                ok = await ref
                    .read(serviceNotifierProvider.notifier)
                    .createService(
                      name: nameCtrl.text.trim(),
                      description:
                          descCtrl.text.isEmpty ? null : descCtrl.text.trim(),
                      price: price,
                      durationMinutes: duration,
                    );
              } else {
                ok = await ref
                    .read(serviceNotifierProvider.notifier)
                    .updateService(
                  service.id,
                  {
                    'name': nameCtrl.text.trim(),
                    'description':
                        descCtrl.text.isEmpty ? null : descCtrl.text.trim(),
                    'price': price,
                    'duration_minutes': duration,
                  },
                );
              }

              if (!context.mounted) return;
              Navigator.pop(ctx);

              final state = ref.read(serviceNotifierProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? (service == null
                          ? 'Service added successfully.'
                          : 'Service updated successfully.')
                      : (state.error?.toString() ?? 'Operation failed.')),
                  backgroundColor: ok ? AppTheme.success : AppTheme.error,
                ),
              );

              ref.invalidate(allServicesProvider);
              ref.invalidate(servicesProvider);
            },
            child: Text(service == null ? 'Add Service' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ServiceModel service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Service',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${service.name}"? This cannot be undone.',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(serviceNotifierProvider.notifier)
                  .deleteService(service.id);
              ref.invalidate(allServicesProvider);
              ref.invalidate(servicesProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
