import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = widget.repository.getDashboardStats(); }
  Future<void> _refresh() async { setState(() => _future = widget.repository.getDashboardStats()); await _future; }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['display_name']?.toString() ?? 'Member';
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _refresh);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final stats = [
          ('Total Cadets', '${data['cadets']}', Icons.groups_outlined, AppColors.green),
          ('Total Activities', '${data['events']}', Icons.event_note_outlined, AppColors.gold),
          ('Completed', '${data['completed']}', Icons.task_alt, AppColors.success),
          ('Upcoming', '${data['upcoming']}', Icons.upcoming_outlined, AppColors.greenLight),
        ];
        final events = List<Map<String, dynamic>>.from(data['events_preview'] as List);
        final notices = List<Map<String, dynamic>>.from(data['notices_preview'] as List);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.greenDark, AppColors.greenMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('EASY NCC • CADET MANAGEMENT', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Text('স্বাগতম, $name', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('আপনার Activity, Training ও Cadet তথ্য এক জায়গায় পরিচালনা করুন।', style: TextStyle(color: Colors.white70, height: 1.4)),
                  ])),
                  const SizedBox(width: 12),
                  Container(width: 62, height: 62, padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
                    child: Image.asset('assets/branding/bncc_logo.png')),
                ]),
              ),
              const SizedBox(height: 20),
              const PageHeading(title: 'Overview', subtitle: 'আপনার Management Summary'),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 780 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns, shrinkWrap: true, mainAxisSpacing: 12, crossAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth > 780 ? 1.8 : 1.65,
                  physics: const NeverScrollableScrollPhysics(),
                  children: stats.map((s) => StatCard(label: s.$1, value: s.$2, icon: s.$3, tint: s.$4)).toList(),
                );
              }),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Text('Recent Activities', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                Text('${events.length} items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ]),
              const SizedBox(height: 10),
              if (events.isEmpty) const Card(child: EmptyState(title: 'কোনো Activity নেই', message: 'Activities Page থেকে নতুন Task যোগ করুন।'))
              else ...events.map((event) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.green.withValues(alpha: .08), child: const Icon(Icons.event_note, color: AppColors.green)),
                  title: Text(event['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatDate(event['event_date'])} • Added by ${event['created_by_name'] ?? 'Member'}'),
                  trailing: Icon(event['completed'] == true ? Icons.check_circle : Icons.schedule, color: event['completed'] == true ? AppColors.success : AppColors.gold),
                ),
              )),
              const SizedBox(height: 16),
              Text('Latest Notices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (notices.isEmpty) const Card(child: EmptyState(title: 'নোটিশ নেই', message: 'নতুন Notice প্রকাশিত হলে এখানে দেখা যাবে।', icon: Icons.campaign_outlined))
              else ...notices.map((notice) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                  title: Text(notice['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${notice['category'] ?? 'General'} • ${formatDate(notice['published_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: notice['priority'] == 'important' ? const Icon(Icons.priority_high, color: AppColors.danger) : null,
                ),
              )),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: StatCard(label: 'Training Records', value: '${data['training']}', icon: Icons.school_outlined, tint: AppColors.greenMid)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Overdue Tasks', value: '${data['overdue']}', icon: Icons.warning_amber_outlined, tint: AppColors.danger)),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
