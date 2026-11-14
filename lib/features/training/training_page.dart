import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool get _canManage => canManage(widget.profile);
  @override
  void initState() { super.initState(); _future = widget.repository.getTraining(); }
  Future<void> _reload() async { setState(() => _future = widget.repository.getTraining()); await _future; }

  Future<void> _create() async {
    List<Map<String, dynamic>> profiles = [];
    try { profiles = await widget.repository.getProfiles(); } catch (_) {}
    if (widget.profile['role'] == 'supervisor') {
      final assigned = await widget.repository.getAssignedCadetIds();
      profiles = profiles.where((p) => assigned.contains(p['id'].toString())).toList();
    } else {
      profiles = profiles.where((p) => p['role'] == 'member').toList();
    }
    if (!mounted) return;
    if (profiles.isEmpty) { showMessage(context, 'Assign করা কোনো Cadet পাওয়া যায়নি।', error: true); return; }
    final data = await showDialog<Map<String, String>>(context: context, builder: (_) => _TrainingDialog(cadets: profiles));
    if (data == null) return;
    try {
      await widget.repository.createTraining(cadetUserId: data['cadet_user_id']!, cadetName: data['cadet_name']!,
        title: data['title']!, description: data['description']!, date: data['date']!, status: data['status']!);
      await _reload(); if (mounted) showMessage(context, 'Training Record তৈরি হয়েছে।');
    } catch (e) { if (mounted) showMessage(context, 'Training তৈরি করা যায়নি: $e', error: true); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Training Record Delete করবেন?'), content: Text(row['title'].toString()),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (yes != true) return;
    try { await widget.repository.deleteTraining(row['id'].toString()); await _reload(); if (mounted) showMessage(context, 'Training Record Delete হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _reload);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      final completed = rows.where((r) => r['status'] == 'completed').length;
      final active = rows.where((r) => r['status'] == 'in_progress').length;
      return RefreshIndicator(onRefresh: _reload, child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(20),
        children: [
          PageHeading(title: 'Training & Progress', subtitle: 'Cadet Training Record এবং Progress পরিচালনা করুন.',
            action: _canManage ? FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Assign')) : null),
          LayoutBuilder(builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth > 760 ? 3 : 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.9,
            children: [
              StatCard(label: 'Total Training', value: '${rows.length}', icon: Icons.school_outlined),
              StatCard(label: 'In Progress', value: '$active', icon: Icons.pending_actions_outlined, tint: AppColors.gold),
              StatCard(label: 'Completed', value: '$completed', icon: Icons.task_alt, tint: AppColors.success),
            ],
          )),
          const SizedBox(height: 14),
          if (rows.isEmpty) const Card(child: EmptyState(title: 'Training Record নেই', message: 'Supervisor Training Assign করলে এখানে দেখা যাবে.', icon: Icons.school_outlined))
          else ...rows.map((row) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(child: Icon(Icons.school_outlined)), const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${row['cadet_name'] ?? 'Cadet'} • ${formatDate(row['training_date'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ])),
                if (_canManage) PopupMenuButton<String>(onSelected: (v) {
                  if (v == 'delete') _delete(row);
                  if (v == 'completed') _setStatus(row, 'completed');
                  if (v == 'progress') _setStatus(row, 'in_progress');
                  if (v == 'planned') _setStatus(row, 'planned');
                }, itemBuilder: (_) => const [
                  PopupMenuItem(value: 'planned', child: Text('Mark Planned')),
                  PopupMenuItem(value: 'progress', child: Text('Mark In Progress')),
                  PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                  PopupMenuDivider(), PopupMenuItem(value: 'delete', child: Text('Delete')),
                ]),
              ]),
              if ((row['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(row['description'].toString())),
              const SizedBox(height: 10),
              Row(children: [
                _StatusPill(status: row['status']?.toString() ?? 'planned'),
                const Spacer(),
                Text('Added by ${row['created_by_name'] ?? 'Supervisor'}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ]),
            ])),
          )),
        ],
      ));
    });
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    try { await widget.repository.updateTraining(row['id'].toString(), status); await _reload(); if (mounted) showMessage(context, 'Training Status Update হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'completed' ? AppColors.success : status == 'in_progress' ? AppColors.gold : AppColors.muted;
    final label = status == 'completed' ? 'COMPLETED' : status == 'in_progress' ? 'IN PROGRESS' : 'PLANNED';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)));
  }
}

class _TrainingDialog extends StatefulWidget {
  const _TrainingDialog({required this.cadets});
  final List<Map<String, dynamic>> cadets;
  @override
  State<_TrainingDialog> createState() => _TrainingDialogState();
}

class _TrainingDialogState extends State<_TrainingDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String _cadetId;
  late String _cadetName;
  DateTime _date = DateTime.now();
  String _status = 'planned';
  @override
  void initState() { super.initState(); _cadetId = widget.cadets.first['id'].toString(); _cadetName = widget.cadets.first['display_name'].toString(); }
  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Training Assign করুন'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(initialValue: _cadetId, decoration: const InputDecoration(labelText: 'Cadet'),
        items: widget.cadets.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['display_name']} • ${p['cadet_number'] ?? ''}'))).toList(),
        onChanged: (v) { if (v == null) return; setState(() { _cadetId = v; _cadetName = widget.cadets.firstWhere((p) => p['id'].toString() == v)['display_name'].toString(); }); }),
      const SizedBox(height: 12),
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Training Name')),
      const SizedBox(height: 12),
      TextField(controller: _description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description (Optional)')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (d != null) setState(() => _date = d);
      }, icon: const Icon(Icons.calendar_month), label: Text(formatDate(_date.toIso8601String()))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'),
        items: const [DropdownMenuItem(value: 'planned', child: Text('Planned')), DropdownMenuItem(value: 'in_progress', child: Text('In Progress')), DropdownMenuItem(value: 'completed', child: Text('Completed'))],
        onChanged: (v) => setState(() => _status = v ?? 'planned')),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (_title.text.trim().isEmpty) { showMessage(context, 'Training Name লিখুন।', error: true); return; }
        Navigator.pop(context, {'cadet_user_id': _cadetId, 'cadet_name': _cadetName,
          'title': _title.text.trim(), 'description': _description.text.trim(),
          'date': _date.toIso8601String().substring(0, 10), 'status': _status});
      }, child: const Text('Save Training'))],
  );
}
