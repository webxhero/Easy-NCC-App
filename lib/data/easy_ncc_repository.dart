import 'package:supabase_flutter/supabase_flutter.dart';

/// All remote reads and writes live here. Passing a null Supabase client enables
/// an in-memory demo preview; demo data is intentionally not presented as cloud data.
class EasyNccRepository {
  EasyNccRepository({SupabaseClient? client}) : client = client;

  final SupabaseClient? client;
  bool get isDemo => client == null;
  String get userId => client?.auth.currentUser?.id ?? 'demo-member';

  final List<Map<String, dynamic>> _events = [
    {
      'id': 'demo-event-1', 'owner_id': 'demo-member', 'created_by_name': 'Demo Cadet',
      'title': 'Weekly Parade Preparation', 'event_date': DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10),
      'completed': false, 'visibility': 'personal', 'event_notes': <Map<String, dynamic>>[],
    },
    {
      'id': 'demo-event-2', 'owner_id': 'demo-supervisor', 'created_by_name': 'Demo Supervisor',
      'title': 'BNCC Central Activity', 'event_date': DateTime.now().add(const Duration(days: 8)).toIso8601String().substring(0, 10),
      'completed': false, 'visibility': 'central', 'event_notes': <Map<String, dynamic>>[],
    },
    {
      'id': 'demo-event-3', 'owner_id': 'demo-member', 'created_by_name': 'Demo Cadet',
      'title': 'Completed Drill Practice', 'event_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String().substring(0, 10),
      'completed': true, 'visibility': 'personal', 'event_notes': <Map<String, dynamic>>[],
    },
  ];
  final List<Map<String, dynamic>> _measurements = [];
  final List<Map<String, dynamic>> _notices = [
    {
      'id': 'demo-notice-1', 'title': 'Easy NCC-তে স্বাগতম',
      'body': 'এটি একটি ডেমো নোটিশ। Supabase যুক্ত হলে অনুমোদিত Admin ও Supervisor নোটিশ প্রকাশ করতে পারবেন।',
      'category': 'General', 'priority': 'normal', 'created_by_name': 'Easy NCC Admin',
      'published_at': DateTime.now().toIso8601String(), 'is_published': true,
    },
  ];
  final List<Map<String, dynamic>> _profiles = [
    {'id': 'demo-member', 'display_name': 'Demo Cadet', 'cadet_number': 'DEMO-001', 'rank': 'Cadet', 'unit_name': 'Demo Unit', 'role': 'member'},
    {'id': 'demo-supervisor', 'display_name': 'Demo Supervisor', 'cadet_number': 'SUP-001', 'rank': 'Supervisor', 'unit_name': 'Demo Unit', 'role': 'supervisor'},
    {'id': 'demo-admin', 'display_name': 'Easy NCC Admin', 'cadet_number': 'ADM-001', 'rank': 'Admin', 'unit_name': 'Platform', 'role': 'admin'},
  ];
  final List<Map<String, dynamic>> _training = [
    {
      'id': 'demo-training-1', 'cadet_user_id': 'demo-member', 'cadet_name': 'Demo Cadet',
      'title': 'Basic Leadership Training', 'description': 'Introduction to leadership and teamwork.',
      'training_date': DateTime.now().add(const Duration(days: 5)).toIso8601String().substring(0, 10),
      'status': 'in_progress', 'created_by_name': 'Demo Supervisor',
    },
  ];

  Future<Map<String, dynamic>> getMyProfile() async {
    if (isDemo) return _profiles.firstWhere((p) => p['id'] == 'demo-member');
    final user = client!.auth.currentUser;
    if (user == null) throw Exception('কোনো ব্যবহারকারী লগইন করা নেই।');
    final row = await client!.from('profiles').select().eq('id', user.id).maybeSingle();
    return row ?? {
      'id': user.id,
      'display_name': user.userMetadata?['display_name'] ?? user.email?.split('@').first ?? 'Member',
      'role': 'member',
    };
  }

  Future<List<Map<String, dynamic>>> getEvents({bool publicOnly = false}) async {
    if (isDemo) {
      final rows = _events.where((e) => publicOnly
          ? e['visibility'] == 'central'
          : (e['owner_id'] == userId || e['visibility'] == 'central')).toList();
      return rows.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final rows = publicOnly
        ? await client!.from('events').select('*, event_notes(*)').eq('visibility', 'central').order('event_date')
        : await client!.from('events').select('*, event_notes(*)').order('event_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createEvent({required String title, required String date, required String visibility, required String displayName}) async {
    if (isDemo) {
      _events.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(), 'owner_id': userId,
        'created_by_name': displayName, 'title': title, 'event_date': date,
        'completed': false, 'visibility': visibility, 'event_notes': <Map<String, dynamic>>[],
      });
      return;
    }
    await client!.from('events').insert({
      'owner_id': userId, 'title': title, 'event_date': date,
      'visibility': visibility, 'completed': false,
    });
  }

  Future<void> updateEvent(String id, Map<String, dynamic> values) async {
    if (isDemo) {
      final index = _events.indexWhere((e) => e['id'].toString() == id);
      if (index >= 0) _events[index] = {..._events[index], ...values};
      return;
    }
    await client!.from('events').update(values).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    if (isDemo) { _events.removeWhere((e) => e['id'].toString() == id); return; }
    await client!.from('events').delete().eq('id', id);
  }

  Future<void> addEventNote(String eventId, String note) async {
    if (isDemo) {
      final event = _events.firstWhere((e) => e['id'].toString() == eventId);
      final notes = List<Map<String, dynamic>>.from(event['event_notes'] as List? ?? []);
      notes.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'owner_id': userId,
        'note': note, 'created_by_name': 'Demo Cadet', 'created_at': DateTime.now().toIso8601String()});
      event['event_notes'] = notes;
      return;
    }
    await client!.from('event_notes').insert({'event_id': eventId, 'owner_id': userId, 'note': note});
  }

  Future<void> deleteEventNote(String id) async {
    if (isDemo) {
      for (final event in _events) {
        final notes = List<Map<String, dynamic>>.from(event['event_notes'] as List? ?? []);
        notes.removeWhere((n) => n['id'].toString() == id);
        event['event_notes'] = notes;
      }
      return;
    }
    await client!.from('event_notes').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMeasurements() async {
    if (isDemo) return _measurements.map((e) => Map<String, dynamic>.from(e)).toList();
    final rows = await client!.from('measurements').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveMeasurement(Map<String, dynamic> data, {String? id}) async {
    if (isDemo) {
      if (id == null) {
        _measurements.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'created_by': userId, ...data});
      } else {
        final index = _measurements.indexWhere((e) => e['id'].toString() == id);
        if (index >= 0) _measurements[index] = {..._measurements[index], ...data};
      }
      return;
    }
    final payload = {...data, 'created_by': userId};
    if (id == null) {
      await client!.from('measurements').insert(payload);
    } else {
      await client!.from('measurements').update(payload).eq('id', id);
    }
  }

  Future<void> deleteMeasurement(String id) async {
    if (isDemo) { _measurements.removeWhere((e) => e['id'].toString() == id); return; }
    await client!.from('measurements').delete().eq('id', id);
  }

  Future<void> importMeasurements(List<Map<String, dynamic>> records, {required bool merge}) async {
    if (isDemo) {
      if (!merge) _measurements.clear();
      for (final row in records) {
        _measurements.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'created_by': userId, ...row});
      }
      return;
    }
    if (!merge) await clearAllMeasurements();
    for (final row in records) {
      final payload = Map<String, dynamic>.from(row)
        ..remove('id')..remove('created_at')..remove('updated_at')..remove('created_by')
        ..remove('created_by_name');
      await client!.from('measurements').insert({...payload, 'created_by': userId});
    }
  }

  Future<void> clearAllMeasurements() async {
    if (isDemo) { _measurements.clear(); return; }
    await client!.from('measurements').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  }

  Future<List<Map<String, dynamic>>> getNotices() async {
    if (isDemo) return _notices.map((e) => Map<String, dynamic>.from(e)).toList();
    final rows = await client!.from('notices').select().order('published_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createNotice({required String title, required String body, required String category, required String priority}) async {
    if (isDemo) {
      _notices.insert(0, {'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': title,
        'body': body, 'category': category, 'priority': priority, 'is_published': true,
        'created_by_name': 'Demo Supervisor', 'published_at': DateTime.now().toIso8601String()});
      return;
    }
    await client!.from('notices').insert({'title': title, 'body': body, 'category': category,
      'priority': priority, 'is_published': true, 'created_by': userId});
  }

  Future<void> deleteNotice(String id) async {
    if (isDemo) { _notices.removeWhere((e) => e['id'].toString() == id); return; }
    await client!.from('notices').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getProfiles() async {
    if (isDemo) return _profiles.map((e) => Map<String, dynamic>.from(e)).toList();
    final rows = await client!.from('profiles')
        .select('id, display_name, cadet_number, rank, unit_name, avatar_url, role, created_at')
        .order('display_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateUserRole(String profileId, String role) async {
    if (isDemo) {
      final index = _profiles.indexWhere((p) => p['id'] == profileId);
      if (index >= 0) _profiles[index]['role'] = role;
      return;
    }
    await client!.from('profiles').update({'role': role}).eq('id', profileId);
  }

  Future<void> updateProfileDetails(String profileId, Map<String, dynamic> values) async {
    if (isDemo) {
      final index = _profiles.indexWhere((p) => p['id'] == profileId);
      if (index >= 0) _profiles[index] = {..._profiles[index], ...values};
      return;
    }
    await client!.from('profiles').update(values).eq('id', profileId);
  }

  Future<void> assignSupervisor(String supervisorId, String cadetId) async {
    if (isDemo) return;
    await client!.from('supervisor_assignments').upsert({
      'supervisor_id': supervisorId, 'cadet_id': cadetId,
    }, onConflict: 'supervisor_id,cadet_id');
  }

  Future<List<String>> getAssignedCadetIds() async {
    if (isDemo) return ['demo-member'];
    if (await _isCurrentAdmin()) {
      final rows = await client!.from('profiles').select('id').eq('role', 'member');
      return List<Map<String, dynamic>>.from(rows).map((e) => e['id'].toString()).toList();
    }
    final rows = await client!.from('supervisor_assignments').select('cadet_id').eq('supervisor_id', userId);
    return List<Map<String, dynamic>>.from(rows).map((e) => e['cadet_id'].toString()).toList();
  }

  Future<bool> _isCurrentAdmin() async {
    if (isDemo) return true;
    final row = await client!.from('profiles').select('role').eq('id', userId).maybeSingle();
    return row?['role'] == 'admin';
  }

  Future<List<Map<String, dynamic>>> getTraining() async {
    if (isDemo) return _training.map((e) => Map<String, dynamic>.from(e)).toList();
    final rows = await client!.from('training_records').select().order('training_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createTraining({required String cadetUserId, required String cadetName,
    required String title, required String description, required String date, required String status}) async {
    if (isDemo) {
      _training.insert(0, {'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'cadet_user_id': cadetUserId, 'cadet_name': cadetName, 'title': title,
        'description': description, 'training_date': date, 'status': status,
        'created_by_name': 'Demo Supervisor'});
      return;
    }
    await client!.from('training_records').insert({
      'cadet_user_id': cadetUserId, 'cadet_name': cadetName, 'title': title, 'description': description,
      'training_date': date, 'status': status, 'created_by': userId,
    });
  }

  Future<void> updateTraining(String id, String status) async {
    if (isDemo) {
      final index = _training.indexWhere((e) => e['id'].toString() == id);
      if (index >= 0) _training[index]['status'] = status;
      return;
    }
    await client!.from('training_records').update({'status': status}).eq('id', id);
  }

  Future<void> deleteTraining(String id) async {
    if (isDemo) { _training.removeWhere((e) => e['id'].toString() == id); return; }
    await client!.from('training_records').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final events = await getEvents();
    final notices = await getNotices();
    final training = await getTraining();
    final profiles = await getProfiles();
    final now = DateTime.now();
    final incomplete = events.where((e) => e['completed'] != true).toList();
    final upcoming = incomplete.where((e) {
      final date = DateTime.tryParse('${e['event_date']}');
      return date == null || !date.isBefore(DateTime(now.year, now.month, now.day));
    }).length;
    return {
      'cadets': profiles.where((p) => p['role'] == 'member').length,
      'events': events.length,
      'completed': events.where((e) => e['completed'] == true).length,
      'upcoming': upcoming,
      'overdue': incomplete.length - upcoming,
      'notices': notices.length,
      'training': training.length,
      'events_preview': events.take(4).toList(),
      'notices_preview': notices.take(3).toList(),
    };
  }
}
