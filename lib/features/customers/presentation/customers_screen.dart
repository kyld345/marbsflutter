// lib/features/customers/presentation/customers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

// Customer list provider
final customersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, search) async {
    final client = ref.watch(supabaseClientProvider);
    final customerRole = await client
        .from(SupabaseConfig.rolesTable)
        .select('id')
        .eq('name', 'customer')
        .maybeSingle();

    if (customerRole == null || customerRole['id'] == null) {
      return <Map<String, dynamic>>[];
    }

    final customerRoleId = customerRole['id'] as String;
    var query = client
        .from(SupabaseConfig.usersTable)
        .select('*, roles(name)')
        .eq('role_id', customerRoleId);

    final response =
        await query.order('created_at', ascending: false).limit(100);

    if (search.isEmpty) return List<Map<String, dynamic>>.from(response);

    return List<Map<String, dynamic>>.from(response).where((u) {
      final name = (u['full_name'] as String? ?? '').toLowerCase();
      final phone = (u['phone'] as String? ?? '').toLowerCase();
      return name.contains(search.toLowerCase()) ||
          phone.contains(search.toLowerCase());
    }).toList();
  },
);

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider(_search));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Customers',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textHint),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textHint),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          customersAsync.when(
            data: (customers) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${customers.length} customer${customers.length != 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textHint, fontSize: 13),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('No customers found',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (constraints.maxWidth > 700) {
                      return _buildTable(customers);
                    }
                    return _buildList(customers);
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

  Widget _buildTable(List<Map<String, dynamic>> customers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.surface),
          columns: [
            _col('Customer'),
            _col('Phone'),
            _col('Joined'),
            _col('Status'),
            _col('Actions'),
          ],
          rows: customers.asMap().entries.map((e) {
            final c = e.value;
            final name = c['full_name'] as String? ?? 'N/A';
            final phone = c['phone'] as String? ?? '—';
            final createdAt = c['created_at'] != null
                ? DateTime.parse(c['created_at'] as String)
                : DateTime.now();
            final isActive = c['is_active'] as bool? ?? true;
            return DataRow(
              cells: [
                DataCell(Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(name,
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500)),
                  ],
                )),
                DataCell(Text(phone,
                    style: GoogleFonts.dmSans(color: AppTheme.textSecondary))),
                DataCell(Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
                )),
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.dmSans(
                      color: isActive ? AppTheme.success : AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined,
                          size: 18, color: AppTheme.textHint),
                      onPressed: () => _showCustomerDetail(context, c),
                      tooltip: 'View',
                    ),
                    IconButton(
                      icon: Icon(
                        isActive
                            ? Icons.block_outlined
                            : Icons.check_circle_outlined,
                        size: 18,
                        color: isActive ? AppTheme.error : AppTheme.success,
                      ),
                      onPressed: () =>
                          _toggleCustomerStatus(c['id'] as String, !isActive),
                      tooltip: isActive ? 'Deactivate' : 'Activate',
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> customers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (_, i) {
        final c = customers[i];
        final name = c['full_name'] as String? ?? 'N/A';
        final phone = c['phone'] as String? ?? '—';
        final isActive = c['is_active'] as bool? ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(phone,
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.dmSans(
                    color: isActive ? AppTheme.success : AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 40).ms);
      },
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label,
            style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      );

  void _showCustomerDetail(
      BuildContext context, Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer['full_name'] as String? ?? 'Customer',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Phone', customer['phone'] as String? ?? '—'),
            _detailRow(
                'Status',
                (customer['is_active'] as bool? ?? true)
                    ? 'Active'
                    : 'Inactive'),
            _detailRow(
              'Joined',
              customer['created_at'] != null
                  ? DateTime.parse(customer['created_at'] as String)
                      .toString()
                      .substring(0, 10)
                  : '—',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 13)),
          ),
          Text(value,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _toggleCustomerStatus(String userId, bool isActive) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from(SupabaseConfig.usersTable)
        .update({'is_active': isActive}).eq('id', userId);
    ref.invalidate(customersProvider);
  }
}
