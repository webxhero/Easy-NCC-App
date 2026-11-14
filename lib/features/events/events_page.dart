import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({
    super.key,
    required this.repository,
    required this.profile,
  });
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getEvents();
  }

  Future<void> _reload() async {
    final newFuture = widget.repository.getEvents();

    setState(() {
      _future = newFuture;
    });

    await newFuture;
  }

  Future<void> _addEvent() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _EventFormDialog(),
    );
    if (result == null) return;
    try {
      await widget.repository.createEvent(
        title: result['title']!,
        date: result['date']!,
        visibility: result['visibility']!,
        displayName: widget.profile['display_name']?.toString() ?? 'Member',
      );
      if (mounted) {
        showMessage(context, 'Activity যোগ হয়েছে।');
        await _reload();
      }
    } catch (e) {
      if (mounted)
        showMessage(context, 'Activity যোগ করা যায়নি: $e', error: true);
    }
  }

  bool _matches(Map<String, dynamic> event) {
    final title = event['title']?.toString().toLowerCase() ?? '';
    final date = event['event_date']?.toString().toLowerCase() ?? '';
    if (_query.isNotEmpty &&
        !title.contains(_query.toLowerCase()) &&
        !date.contains(_query.toLowerCase()))
      return false;
    final completed = event['completed'] == true;
    final parsed = DateTime.tryParse('${event['event_date']}');
    final today = DateTime.now();
    final overdue =
        !completed &&
        parsed != null &&
        parsed.isBefore(DateTime(today.year, today.month, today.day));
    switch (_filter) {
      case 'completed':
        return completed;
      case 'upcoming':
        return !completed && !overdue;
      case 'overdue':
        return overdue;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return ErrorState(error: snapshot.error!, onRetry: _reload);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final rows = all.where(_matches).toList();
        final completed = all.where((e) => e['completed'] == true).length;
        final pending = all.length - completed;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.all(20),
            children: [
              PageHeading(
                title: 'Activity & To-Do',
                subtitle:
                    'Personal ও Central Activity এক জায়গায় পরিচালনা করুন।',
                action: FilledButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  crossAxisCount: constraints.maxWidth > 760 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    StatCard(
                      label: 'Total Activities',
                      value: '${all.length}',
                      icon: Icons.event_note_outlined,
                    ),
                    StatCard(
                      label: 'Completed',
                      value: '$completed',
                      icon: Icons.task_alt,
                      tint: AppColors.success,
                    ),
                    StatCard(
                      label: 'Pending',
                      value: '$pending',
                      icon: Icons.schedule,
                      tint: AppColors.gold,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Activity name বা date দিয়ে Search করুন',
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      value: 'all',
                      selected: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    _FilterChip(
                      label: 'Upcoming',
                      value: 'upcoming',
                      selected: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    _FilterChip(
                      label: 'Completed',
                      value: 'completed',
                      selected: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    _FilterChip(
                      label: 'Overdue',
                      value: 'overdue',
                      selected: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Card(
                  child: EmptyState(
                    title: 'কোনো Activity পাওয়া যায়নি',
                    message: 'Search বা Filter পরিবর্তন করুন, অথবা নতুন Activity যোগ করুন.',
                    icon: Icons.event_busy_outlined,
                  ),
                )
              else
                ...rows.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EventTile(
                      key: ValueKey(event['id']),
                      event: event,
                      repository: widget.repository,
                      profile: widget.profile,
                      onChanged: _reload,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PublicEventsPage extends StatefulWidget {
  const PublicEventsPage({super.key, required this.repository});
  final EasyNccRepository repository;
  @override
  State<PublicEventsPage> createState() => _PublicEventsPageState();
}

class _PublicEventsPageState extends State<PublicEventsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getEvents(publicOnly: true);
  }

  Future<void> _reload() async {
    final newFuture = widget.repository.getEvents(publicOnly: true);

    setState(() {
      _future = newFuture;
    });

    await newFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Central Activities')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorState(error: snapshot.error!, onRetry: _reload);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Public Central Activities',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.greenDark,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'এই Activities Internet-এর যেকোনো Visitor দেখতে পারবেন। Personal Task এখানে দেখানো হয় না।',
                ),
                const SizedBox(height: 16),
                if (events.isEmpty)
                  const Card(
                    child: EmptyState(
                      title: 'এখনো কোনো Public Activity নেই',
                      message:
                          'নতুন Central Activity প্রকাশিত হলে এখানে দেখা যাবে.',
                      icon: Icons.public_off_outlined,
                    ),
                  )
                else
                  ...events.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EventTile(
                        event: e,
                        repository: widget.repository,
                        profile: const {'id': '', 'role': 'guest'},
                        onChanged: _reload,
                        readOnly: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label, value, selected;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onTap(value),
    ),
  );
}

class EventTile extends StatefulWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.repository,
    required this.profile,
    required this.onChanged,
    this.readOnly = false,
  });
  final Map<String, dynamic> event;
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  final Future<void> Function() onChanged;
  final bool readOnly;

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  final _note = TextEditingController();
  bool _expanded = false;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isOwner => widget.event['owner_id'] == widget.repository.userId;
  bool get _isAdmin => widget.profile['role'] == 'admin';
  bool get _canManage => !widget.readOnly && (_isOwner || _isAdmin);
  bool get _canAddNote =>
      !widget.readOnly &&
      (widget.event['visibility'] == 'central' || _isOwner || _isAdmin);

  String get _status {
    if (widget.event['completed'] == true) return 'Completed';
    final date = DateTime.tryParse('${widget.event['event_date']}');
    final now = DateTime.now();
    if (date != null && date.isBefore(DateTime(now.year, now.month, now.day)))
      return 'Overdue';
    return 'Upcoming';
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    var completed = false;
    try {
      await action();
      await widget.onChanged();
      completed = true;
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (completed) showMessage(context, success);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = List<Map<String, dynamic>>.from(
      widget.event['event_notes'] as List? ?? [],
    );
    final statusColor = _status == 'Completed'
        ? AppColors.success
        : (_status == 'Overdue' ? AppColors.danger : AppColors.gold);
    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: _canManage
                ? Checkbox(
                    value: widget.event['completed'] == true,
                    activeColor: AppColors.green,
                    onChanged: _busy
                        ? null
                        : (value) => _run(
                            () => widget.repository.updateEvent(
                              widget.event['id'].toString(),
                              {
                                'completed': value ?? false,
                                'completed_at': value == true
                                    ? DateTime.now().toIso8601String()
                                    : null,
                              },
                            ),
                            'Status Update হয়েছে।',
                          ),
                  )
                : CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: .12),
                    child: Icon(
                      widget.event['completed'] == true
                          ? Icons.check
                          : Icons.event_note,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
            title: Text(
              widget.event['title']?.toString() ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: widget.event['completed'] == true
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatDate(widget.event['event_date']),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  Text(
                    'Added by ${widget.event['created_by_name'] ?? 'Member'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  _SmallTag(
                    text: widget.event['visibility'] == 'central'
                        ? 'CENTRAL'
                        : 'PERSONAL',
                    color: widget.event['visibility'] == 'central'
                        ? AppColors.green
                        : AppColors.muted,
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallTag(text: _status.toUpperCase(), color: statusColor),
                if (_canManage)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Activity'),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: 'Notes',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          'Event Notes (${notes.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (notes.isEmpty)
                          const Text(
                            'এখনো কোনো Note যোগ করা হয়নি।',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ...notes.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.notes,
                                  size: 16,
                                  color: AppColors.greenMid,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n['note']?.toString() ?? ''),
                                      Text(
                                        '${n['created_by_name'] ?? 'Member'} • ${formatDateTime(n['created_at'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!widget.readOnly &&
                                    (n['owner_id'] ==
                                            widget.repository.userId ||
                                        _isAdmin))
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => _run(
                                      () => widget.repository.deleteEventNote(
                                        n['id'].toString(),
                                      ),
                                      'Note Delete হয়েছে.',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_canAddNote)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _note,
                                  decoration: const InputDecoration(
                                    hintText: 'এই Activity-এর Note লিখুন',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        if (_note.text.trim().isEmpty) return;
                                        final text = _note.text.trim();
                                        _note.clear();
                                        await _run(
                                          () => widget.repository.addEventNote(
                                            widget.event['id'].toString(),
                                            text,
                                          ),
                                          'Note যোগ হয়েছে।',
                                        );
                                      },
                                icon: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Activity Delete করবেন?'),
        content: const Text('এই Activity ও এর Notes মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true)
      await _run(
        () => widget.repository.deleteEvent(widget.event['id'].toString()),
        'Activity Delete হয়েছে।',
      );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    ),
  );
}

class _EventFormDialog extends StatefulWidget {
  const _EventFormDialog();
  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _title = TextEditingController();
  DateTime _date = DateTime.now();
  String _visibility = 'personal';
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('নতুন Activity যোগ করুন'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Activity Name'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (value != null) setState(() => _date = value);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Date: ${formatDate(_date.toIso8601String())}'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: const [
                DropdownMenuItem(
                  value: 'personal',
                  child: Text('Personal — শুধু আমি'),
                ),
                DropdownMenuItem(
                  value: 'central',
                  child: Text('Central — Internet Public'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _visibility = value ?? 'personal'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Central Activity Internet-এ Login ছাড়াও দেখা যাবে। ব্যক্তিগত তথ্য লিখবেন না।',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'date': _date.toIso8601String().substring(0, 10),
              'visibility': _visibility,
            });
          },
          child: const Text('Save Activity'),
        ),
      ],
    );
  }
}
