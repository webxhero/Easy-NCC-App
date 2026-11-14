import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import '../data/easy_ncc_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.isSupabaseReady) return null;
  return Supabase.instance.client;
});

final repositoryProvider = Provider<EasyNccRepository>((ref) {
  return EasyNccRepository(client: ref.watch(supabaseClientProvider));
});
