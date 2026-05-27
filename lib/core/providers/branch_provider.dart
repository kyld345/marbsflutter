import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_provider.dart';
import '../config/supabase_config.dart';

final activeBranchIdProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final branch = await client
      .from(SupabaseConfig.branchesTable)
      .select('id')
      .eq('is_active', true)
      .limit(1) 
      .maybeSingle();

  if (branch == null) {
    throw Exception('No active branch found.');
  }

  return branch['id'] as String;
});
