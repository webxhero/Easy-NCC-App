import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';
import '../dashboard/dashboard_page.dart';
import '../events/events_page.dart';
import '../measurements/measurements_page.dart';
import '../notices/notices_page.dart';
import '../cadets/cadet_directory_page.dart';
import '../training/training_page.dart';
import '../reports/reports_page.dart';
import '../more/more_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.repository, required this.profile, required this.demoMode});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  final bool demoMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: Text('Activities')),
    NavigationRailDestination(icon: Icon(Icons.straighten_outlined), selectedIcon: Icon(Icons.straighten), label: Text('Measurement')),
    NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: Text('Notices')),
    NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Cadet Directory')),
    NavigationRailDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: Text('Training')),
    NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reports')),
  ];

  Widget _pageFor(int index) {
    switch (index) {
      case 0: return DashboardPage(repository: widget.repository, profile: widget.profile);
      case 1: return EventsPage(repository: widget.repository, profile: widget.profile);
      case 2: return MeasurementsPage(repository: widget.repository, profile: widget.profile);
      case 3: return NoticesPage(repository: widget.repository, profile: widget.profile);
      case 4: return CadetDirectoryPage(repository: widget.repository, profile: widget.profile);
      case 5: return TrainingPage(repository: widget.repository, profile: widget.profile);
      case 6: return ReportsPage(repository: widget.repository, profile: widget.profile);
      default: return MorePage(onSelect: (value) => setState(() => _selectedIndex = value));
    }
  }

  int get _mobileIndex => _selectedIndex >= 3 ? 3 : _selectedIndex;

  void _selectMobile(int index) {
    setState(() => _selectedIndex = index == 3 ? 7 : index);
  }

  Future<void> _handleMenu(String value) async {
    if (value == 'profile') {
      if (!mounted) return;
      showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: const Text('Account Profile'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.profile['display_name']?.toString() ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Role: ${widget.profile['role'] ?? 'member'}'),
          if (widget.profile['cadet_number'] != null) Text('Cadet Number: ${widget.profile['cadet_number']}'),
          if (widget.demoMode) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Demo Preview — data is not synced to Supabase.')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } else if (value == 'logout') {
      if (widget.demoMode) {
        Navigator.of(context).pop();
      } else {
        try { await widget.repository.client?.auth.signOut(); }
        catch (e) { if (mounted) showMessage(context, 'Logout করা যায়নি: $e', error: true); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .015), end: Offset.zero).animate(animation), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _pageFor(_selectedIndex)),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: isWide ? 20 : 16,
        title: const AppLogo(size: 42),
        actions: [
          if (widget.demoMode)
            Padding(padding: const EdgeInsets.only(right: 8), child: Chip(
              label: const Text('DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              backgroundColor: AppColors.gold.withValues(alpha: .18), side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              tooltip: 'Account menu',
              onSelected: _handleMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profile'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Logout'), contentPadding: EdgeInsets.zero)),
              ],
              child: CircleAvatar(
                backgroundColor: AppColors.green,
                child: Text((widget.profile['display_name']?.toString().isNotEmpty == true
                    ? widget.profile['display_name'].toString()[0] : 'E').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _selectedIndex > 6 ? 0 : _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.gold.withValues(alpha: .22),
                destinations: _destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: isWide ? null : NavigationBar(
        selectedIndex: _mobileIndex,
        onDestinationSelected: _selectMobile,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.straighten_outlined), selectedIcon: Icon(Icons.straighten), label: 'Measure'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'More'),
        ],
      ),
    );
  }
}

