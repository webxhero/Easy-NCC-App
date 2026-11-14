import 'package:flutter/material.dart';
import '../../core/app_widgets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (3, 'Notice & Announcements', 'প্রয়োজনীয় নোটিশ ও ঘোষণা', Icons.campaign_outlined),
      (4, 'Cadet Directory', 'Cadet Profile ও Directory', Icons.groups_outlined),
      (5, 'Training & Progress', 'Training Record ও Progress', Icons.school_outlined),
      (6, 'Reports & Analytics', 'Summary, Report ও Export', Icons.analytics_outlined),
    ];
    return ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20), children: [
      const PageHeading(title: 'More Features', subtitle: 'Easy NCC-এর অন্যান্য Management Page'),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          leading: CircleAvatar(child: Icon(item.$4)),
          title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(item.$3),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onSelect(item.$1),
        )),
      )),
    ]);
  }
}
