import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> _future;
  DateTimeRange? _range;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<Map<String, dynamic>> _load() async {
    final stats = await widget.repository.getDashboardStats();
    final events = await widget.repository.getEvents();
    final measurements = await widget.repository.getMeasurements();
    final training = await widget.repository.getTraining();
    final notices = await widget.repository.getNotices();
    final profiles = await widget.repository.getProfiles();
    return {'stats': stats, 'events': events, 'measurements': measurements, 'training': training, 'notices': notices, 'profiles': profiles};
  }
  Future<void> _reload() async { setState(() => _future = _load()); await _future; }

  bool _inRange(dynamic value) {
    if (_range == null || value == null) return true;
    final date = DateTime.tryParse(value.toString());
    if (date == null) return true;
    return !date.isBefore(DateTime(_range!.start.year, _range!.start.month, _range!.start.day)) &&
      !date.isAfter(DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59));
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(now.year + 5),
      initialDateRange: _range ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _exportCsv(Map<String, dynamic> data) async {
    final events = List<Map<String, dynamic>>.from(data['events']).where((e) => _inRange(e['event_date'])).toList();
    final training = List<Map<String, dynamic>>.from(data['training']).where((e) => _inRange(e['training_date'])).toList();
    final measurements = List<Map<String, dynamic>>.from(data['measurements']).where((e) => _inRange(e['created_at'])).toList();
    final notices = List<Map<String, dynamic>>.from(data['notices']).where((e) => _inRange(e['published_at'])).toList();
    final cadets = List<Map<String, dynamic>>.from(data['profiles']).where((e) => e['role'] == 'member').toList();
    final buffer = StringBuffer('Report Type,Name/Title,Date,Status,Details\r\n');
    String q(dynamic v) {
      final value = (v ?? '').toString().replaceAll('\"', '\"\"');
      return '\"$value\"';
    }
    for (final e in events) { buffer.writeln(['Activity', q(e['title']), q(e['event_date']), q(e['completed'] == true ? 'Completed' : 'Pending'), q(e['visibility'])].join(',')); }
    for (final t in training) { buffer.writeln(['Training', q(t['title']), q(t['training_date']), q(t['status']), q(t['cadet_name'])].join(',')); }
    for (final m in measurements) { buffer.writeln(['Measurement', q(m['cadet_name']), q(m['created_at']), q('Saved'), q(m['cadet_number'])].join(',')); }
    for (final c in cadets) { buffer.writeln(['Cadet', q(c['display_name']), q(c['created_at']), q(c['role']), q(c['cadet_number'])].join(',')); }
    for (final n in notices) { buffer.writeln(['Notice', q(n['title']), q(n['published_at']), q(n['priority']), q(n['category'])].join(',')); }
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF${buffer.toString()}'));
    await SharePlus.instance.share(ShareParams(
      title: 'Easy NCC Report CSV', files: [XFile.fromData(bytes, mimeType: 'text/csv')],
      fileNameOverrides: ['easy-ncc-report.csv'],
    ));
  }

  Future<void> _exportPdf(Map<String, dynamic> data) async {
    final stats = Map<String, dynamic>.from(data['stats']);
    final reportEvents = List<Map<String, dynamic>>.from(data['events']).where((e) => _inRange(e['event_date'])).toList();
    final reportTraining = List<Map<String, dynamic>>.from(data['training']).where((e) => _inRange(e['training_date'])).toList();
    final reportMeasurements = List<Map<String, dynamic>>.from(data['measurements']).where((e) => _inRange(e['created_at'])).toList();
    final reportNotices = List<Map<String, dynamic>>.from(data['notices']).where((e) => _inRange(e['published_at'])).toList();
    final reportCadets = List<Map<String, dynamic>>.from(data['profiles']).where((e) => e['role'] == 'member').toList();
    final completedCount = reportEvents.where((e) => e['completed'] == true).length;
    final pendingEvents = reportEvents.where((e) => e['completed'] != true).toList();
    final today = DateTime.now();
    final overdueCount = pendingEvents.where((e) {
      final date = DateTime.tryParse('${e['event_date']}');
      return date != null && date.isBefore(DateTime(today.year, today.month, today.day));
    }).length;
    final upcomingCount = pendingEvents.length - overdueCount;
    final regular = await PdfGoogleFonts.notoSansBengaliRegular();
    final bold = await PdfGoogleFonts.notoSansBengaliBold();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Text('EASY NCC • MANAGEMENT REPORT', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated: ${DateTime.now().toLocal()}', style: const pw.TextStyle(fontSize: 9)),
        if (_range != null) pw.Text('Date range: ${_range!.start} — ${_range!.end}', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
        pw.Text('Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Metric', 'Value'],
          data: [
            ['Cadets', '${stats['cadets']}'], ['Activities', '${reportEvents.length}'],
            ['Completed', '$completedCount'], ['Upcoming', '$upcomingCount'],
            ['Overdue', '$overdueCount'], ['Training Records', '${reportTraining.length}'],
            ['Measurements', '${reportMeasurements.length}'], ['Notices', '${reportNotices.length}'],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Cadet Directory', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Name', 'Cadet No.', 'Rank', 'Unit'],
          data: reportCadets.map((e) => [
            e['display_name']?.toString() ?? '', e['cadet_number']?.toString() ?? '',
            e['rank']?.toString() ?? '', e['unit_name']?.toString() ?? '',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Activities', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Title', 'Date', 'Status', 'Visibility'],
          data: reportEvents.map((e) => [
            e['title']?.toString() ?? '', e['event_date']?.toString() ?? '',
            e['completed'] == true ? 'Completed' : 'Pending', e['visibility']?.toString() ?? '',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Training Records', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Cadet', 'Training', 'Date', 'Status'],
          data: reportTraining.map((e) => [
            e['cadet_name']?.toString() ?? '', e['title']?.toString() ?? '', e['training_date']?.toString() ?? '', e['status']?.toString() ?? '',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Cadet Measurement Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Cadet', 'Cadet No.', 'Shirt Body', 'Shirt Length', 'Pant Waist', 'Pant Length'],
          data: reportMeasurements.map((e) => [
            e['cadet_name']?.toString() ?? '', e['cadet_number']?.toString() ?? '',
            e['shirt_body']?.toString() ?? '', e['shirt_length']?.toString() ?? '',
            e['pant_waist']?.toString() ?? '', e['pant_length']?.toString() ?? '',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 6),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Notices', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Title', 'Category', 'Priority', 'Published'],
          data: reportNotices.map((e) => [
            e['title']?.toString() ?? '', e['category']?.toString() ?? '',
            e['priority']?.toString() ?? '', e['published_at']?.toString() ?? '',
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 6),
        ),
      ],
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'easy-ncc-report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _reload);
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!;
      final stats = Map<String, dynamic>.from(data['stats']);
      final events = List<Map<String, dynamic>>.from(data['events']).where((e) => _inRange(e['event_date'])).toList();
      final training = List<Map<String, dynamic>>.from(data['training']).where((e) => _inRange(e['training_date'])).toList();
      final measurements = List<Map<String, dynamic>>.from(data['measurements']).where((e) => _inRange(e['created_at'])).toList();
      final completedCount = events.where((e) => e['completed'] == true).length;
      final pendingEvents = events.where((e) => e['completed'] != true).toList();
      final now = DateTime.now();
      final overdueCount = pendingEvents.where((e) {
        final date = DateTime.tryParse('${e['event_date']}');
        return date != null && date.isBefore(DateTime(now.year, now.month, now.day));
      }).length;
      final upcomingCount = pendingEvents.length - overdueCount;
      final metrics = [
        ('Cadets', '${stats['cadets']}', Icons.groups_outlined),
        ('Activities', '${events.length}', Icons.event_note_outlined),
        ('Training', '${training.length}', Icons.school_outlined),
        ('Measurements', '${measurements.length}', Icons.straighten_outlined),
      ];
      return RefreshIndicator(onRefresh: _reload, child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(20),
        children: [
          PageHeading(title: 'Reports & Analytics', subtitle: 'Management Summary ও Report Export করুন.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _chooseRange, icon: const Icon(Icons.date_range), label: Text(_range == null ? 'Date Range' : '${formatDate(_range!.start.toIso8601String())} – ${formatDate(_range!.end.toIso8601String())}')),
            if (_range != null) TextButton(onPressed: () => setState(() => _range = null), child: const Text('Clear Filter')),
            FilledButton.tonalIcon(onPressed: () => _exportCsv(data), icon: const Icon(Icons.table_view_outlined), label: const Text('Export CSV')),
            FilledButton.tonalIcon(onPressed: () => _exportPdf(data), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Export PDF')),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth > 760 ? 4 : 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.9,
            children: metrics.map((m) => StatCard(label: m.$1, value: m.$2, icon: m.$3)).toList(),
          )),
          const SizedBox(height: 20),
          Text('Activity Status', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ReportBar(label: 'Completed', value: completedCount.toDouble(), total: events.length.toDouble(), color: AppColors.success),
          const SizedBox(height: 10),
          _ReportBar(label: 'Upcoming', value: upcomingCount.toDouble(), total: events.length.toDouble(), color: AppColors.gold),
          const SizedBox(height: 10),
          _ReportBar(label: 'Overdue', value: overdueCount.toDouble(), total: events.length.toDouble(), color: AppColors.danger),
          const SizedBox(height: 20),
          Text('Training Status', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ReportBar(label: 'Completed', value: training.where((e) => e['status'] == 'completed').length.toDouble(), total: training.length.toDouble(), color: AppColors.success),
          const SizedBox(height: 10),
          _ReportBar(label: 'In Progress', value: training.where((e) => e['status'] == 'in_progress').length.toDouble(), total: training.length.toDouble(), color: AppColors.gold),
          const SizedBox(height: 10),
          _ReportBar(label: 'Planned', value: training.where((e) => e['status'] == 'planned').length.toDouble(), total: training.length.toDouble(), color: AppColors.greenLight),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Report Notes', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('এই Report বর্তমান User-এর Supabase Permission অনুযায়ী দৃশ্যমান Data থেকে তৈরি হয়। Member নিজের তথ্য, Supervisor Assigned Cadet-এর তথ্য এবং Admin Platform-এর সব অনুমোদিত তথ্য দেখতে পারবেন.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, height: 1.5)),
          ]))),
        ],
      ));
    });
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({required this.label, required this.value, required this.total, required this.color});
  final String label;
  final double value, total;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text('${value.toInt()} / ${total.toInt()}', style: const TextStyle(color: AppColors.muted, fontSize: 12))]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: ratio, minHeight: 9, color: color, backgroundColor: color.withValues(alpha: .12))),
    ]);
  }
}
