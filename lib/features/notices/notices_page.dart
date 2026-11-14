import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  bool get _canPublish => canManage(widget.profile);
  @override
  void initState() { super.initState(); _future = widget.repository.getNotices(); }
  Future<void> _reload() async { setState(() => _future = widget.repository.getNotices()); await _future; }

  Future<void> _create() async {
    final result = await showDialog<Map<String, String>>(context: context, builder: (_) => const _NoticeDialog());
    if (result == null) return;
    try {
      await widget.repository.createNotice(title: result['title']!, body: result['body']!, category: result['category']!, priority: result['priority']!);
      await _reload(); if (mounted) showMessage(context, 'Notice Publish হয়েছে।');
    } catch (e) { if (mounted) showMessage(context, 'Notice Publish করা যায়নি: $e', error: true); }
  }

  Future<void> _delete(Map<String, dynamic> notice) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Notice Delete করবেন?'), content: Text(notice['title'].toString()),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (yes != true) return;
    try { await widget.repository.deleteNotice(notice['id'].toString()); await _reload(); if (mounted) showMessage(context, 'Notice Delete হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _reload);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final notices = snapshot.data!.where((n) => '${n['title']} ${n['body']} ${n['category']}'.toLowerCase().contains(_query.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: _reload, child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(20),
        children: [
          PageHeading(title: 'Notice & Announcements', subtitle: 'প্রয়োজনীয় ঘোষণা ও গুরুত্বপূর্ণ তথ্য দেখুন।',
            action: _canPublish ? FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Publish')) : null),
          TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Notice Search করুন')),
          const SizedBox(height: 14),
          if (notices.isEmpty) const Card(child: EmptyState(title: 'কোনো Notice নেই', message: 'নতুন Notice প্রকাশিত হলে এখানে দেখা যাবে।', icon: Icons.campaign_outlined))
          else ...notices.map((notice) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(backgroundColor: (notice['priority'] == 'important' ? AppColors.gold : AppColors.green).withValues(alpha: .13),
                child: Icon(notice['priority'] == 'important' ? Icons.priority_high : Icons.campaign_outlined,
                  color: notice['priority'] == 'important' ? AppColors.gold : AppColors.green)),
              title: Text(notice['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${notice['category'] ?? 'General'} • ${formatDate(notice['published_at'])} • ${notice['created_by_name'] ?? 'Member'}'),
              trailing: (_canPublish && (isAdmin(widget.profile) || notice['created_by'] == widget.repository.userId))
                  ? PopupMenuButton<String>(onSelected: (v) { if (v == 'delete') _delete(notice); },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete Notice'))]) : null,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [Align(alignment: Alignment.centerLeft, child: Text(notice['body']?.toString() ?? '', style: const TextStyle(height: 1.5)))],
            ),
          )),
        ],
      ));
    });
  }
}

class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog();
  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = 'General';
  String _priority = 'normal';
  @override
  void dispose() { _title.dispose(); _body.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('নতুন Notice Publish করুন'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Notice Title')),
      const SizedBox(height: 12),
      TextField(controller: _body, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Description')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category'),
        items: const ['General', 'Event', 'Training', 'Important'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _category = v ?? 'General')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _priority, decoration: const InputDecoration(labelText: 'Priority'),
        items: const [DropdownMenuItem(value: 'normal', child: Text('Normal')), DropdownMenuItem(value: 'important', child: Text('Important'))],
        onChanged: (v) => setState(() => _priority = v ?? 'normal')),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) { showMessage(context, 'Title ও Description লিখুন।', error: true); return; }
        Navigator.pop(context, {'title': _title.text.trim(), 'body': _body.text.trim(), 'category': _category, 'priority': _priority});
      }, child: const Text('Publish'))],
  );
}
