import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class CadetDirectoryPage extends StatefulWidget {
  const CadetDirectoryPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  @override
  State<CadetDirectoryPage> createState() => _CadetDirectoryPageState();
}

class _CadetDirectoryPageState extends State<CadetDirectoryPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  bool get _isAdmin => isAdmin(widget.profile);
  @override
  void initState() { super.initState(); _future = widget.repository.getProfiles(); }
  Future<void> _reload() async { setState(() => _future = widget.repository.getProfiles()); await _future; }

  Future<void> _changeRole(Map<String, dynamic> cadet, String role) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Account Role পরিবর্তন করবেন?'),
      content: Text('${cadet['display_name']} → $role'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))],
    ));
    if (yes != true) return;
    try { await widget.repository.updateUserRole(cadet['id'].toString(), role); await _reload(); if (mounted) showMessage(context, 'Role Update হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, 'Role Update করা যায়নি: $e', error: true); }
  }

  Future<void> _editProfile(Map<String, dynamic> cadet) async {
    final name = TextEditingController(text: cadet['display_name']?.toString() ?? '');
    final number = TextEditingController(text: cadet['cadet_number']?.toString() ?? '');
    final rank = TextEditingController(text: cadet['rank']?.toString() ?? '');
    final unit = TextEditingController(text: cadet['unit_name']?.toString() ?? '');
    final values = await showDialog<Map<String, String>>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cadet Profile Edit'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full Name')),
        const SizedBox(height: 10), TextField(controller: number, decoration: const InputDecoration(labelText: 'Cadet Number')),
        const SizedBox(height: 10), TextField(controller: rank, decoration: const InputDecoration(labelText: 'Rank / Designation')),
        const SizedBox(height: 10), TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit Name')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, {
          'display_name': name.text.trim(), 'cadet_number': number.text.trim(),
          'rank': rank.text.trim(), 'unit_name': unit.text.trim(),
        }), child: const Text('Save'))],
    ));
    name.dispose(); number.dispose(); rank.dispose(); unit.dispose();
    if (values == null) return;
    if (values['display_name']!.isEmpty) { showMessage(context, 'নাম ফাঁকা রাখা যাবে না।', error: true); return; }
    try {
      await widget.repository.updateProfileDetails(cadet['id'].toString(), {
        'display_name': values['display_name'],
        'cadet_number': values['cadet_number']!.isEmpty ? null : values['cadet_number'],
        'rank': values['rank']!.isEmpty ? null : values['rank'],
        'unit_name': values['unit_name']!.isEmpty ? null : values['unit_name'],
      });
      await _reload();
      if (mounted) showMessage(context, 'Cadet Profile Update হয়েছে।');
    } catch (e) { if (mounted) showMessage(context, 'Profile Update করা যায়নি: $e', error: true); }
  }

  Future<void> _assignSupervisor(Map<String, dynamic> cadet, List<Map<String, dynamic>> profiles) async {
    final supervisors = profiles.where((p) => p['role'] == 'supervisor').toList();
    if (supervisors.isEmpty) { showMessage(context, 'আগে অন্তত একজন Member-কে Supervisor Role দিন।', error: true); return; }
    String? selected = supervisors.first['id'].toString();
    final result = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('Supervisor Assign করুন'),
      content: DropdownButtonFormField<String>(initialValue: selected,
        items: supervisors.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['display_name'].toString()))).toList(),
        onChanged: (v) => setLocal(() => selected = v),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Assign'))],
    )));
    if (result == null) return;
    try { await widget.repository.assignSupervisor(result, cadet['id'].toString()); if (mounted) showMessage(context, 'Supervisor Assign হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, 'Assign করা যায়নি: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _reload);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final all = snapshot.data!;
      final cadets = all.where((p) => '${p['display_name']} ${p['cadet_number']} ${p['rank']} ${p['unit_name']}'.toLowerCase().contains(_query.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: _reload, child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(20),
        children: [
          const PageHeading(title: 'Cadet Directory', subtitle: 'Registered Member ও Cadet Profile দেখুন।'),
          LayoutBuilder(builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth > 760 ? 3 : 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.9,
            children: [
              StatCard(label: 'Total Profiles', value: '${all.length}', icon: Icons.groups_outlined),
              StatCard(label: 'Cadets / Members', value: '${all.where((p) => p['role'] == 'member').length}', icon: Icons.person_outline, tint: AppColors.greenLight),
              StatCard(label: 'Supervisors', value: '${all.where((p) => p['role'] == 'supervisor').length}', icon: Icons.supervisor_account_outlined, tint: AppColors.gold),
            ],
          )),
          const SizedBox(height: 14),
          TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, Cadet Number বা Unit দিয়ে Search করুন')),
          const SizedBox(height: 14),
          if (cadets.isEmpty) const Card(child: EmptyState(title: 'কোনো Profile পাওয়া যায়নি', message: 'Search পরিবর্তন করুন।', icon: Icons.person_search_outlined))
          else ...cadets.map((cadet) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.green.withValues(alpha: .10),
                backgroundImage: cadet['avatar_url'] != null ? NetworkImage(cadet['avatar_url'].toString()) : null,
                child: cadet['avatar_url'] == null ? Text((cadet['display_name']?.toString().isNotEmpty == true ? cadet['display_name'].toString()[0] : 'C').toUpperCase(), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)) : null,
              ),
              title: Text(cadet['display_name']?.toString() ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cadet No: ${cadet['cadet_number'] ?? 'Not set'}'),
                Text('${cadet['rank'] ?? 'Cadet'} • ${cadet['unit_name'] ?? 'Unit not set'}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 4),
                _RolePill(role: cadet['role']?.toString() ?? 'member'),
              ])),
              isThreeLine: true,
              trailing: _isAdmin && cadet['id'] != widget.repository.userId ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'supervisor') _changeRole(cadet, 'supervisor');
                  if (value == 'member') _changeRole(cadet, 'member');
                  if (value == 'admin') _changeRole(cadet, 'admin');
                  if (value == 'assign') _assignSupervisor(cadet, all);
                  if (value == 'edit') _editProfile(cadet);
                },
                itemBuilder: (_) => [
                  if (cadet['role'] != 'supervisor') const PopupMenuItem(value: 'supervisor', child: Text('Make Supervisor')),
                  if (cadet['role'] != 'member') const PopupMenuItem(value: 'member', child: Text('Set as Member')),
                  if (cadet['role'] != 'admin') const PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit Cadet Profile')),
                  if (cadet['role'] == 'member') const PopupMenuItem(value: 'assign', child: Text('Assign Supervisor')),
                ],
              ) : null,
            ),
          )),
        ],
      ));
    });
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final color = role == 'admin' ? AppColors.gold : role == 'supervisor' ? AppColors.greenMid : AppColors.muted;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)));
  }
}
