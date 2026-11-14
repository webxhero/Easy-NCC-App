import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';

const _shirtFields = <(String, String)>[
  ('shirt_length', 'লম্বা'), ('shirt_body', 'বডি'), ('shirt_cuff', 'কাফ'),
  ('shirt_hand', 'হাত'), ('shirt_pet', 'পেট'), ('shirt_hip', 'হিপ'), ('shirt_collar', 'কলার'),
];
const _pantFields = <(String, String)>[
  ('pant_length', 'লম্বা'), ('pant_run', 'রান'), ('pant_high', 'হাই'),
  ('pant_waist', 'কোমর'), ('pant_muri', 'মুরি'), ('pant_hip', 'হিপ'),
];

class MeasurementsPage extends StatefulWidget {
  const MeasurementsPage({super.key, required this.repository, required this.profile});
  final EasyNccRepository repository;
  final Map<String, dynamic> profile;

  @override
  State<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends State<MeasurementsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  int _cardsPerPage = 12;
  bool get _canManage => canManage(widget.profile);
  bool get _isAdmin => isAdmin(widget.profile);

  @override
  void initState() { super.initState(); _future = widget.repository.getMeasurements(); }
  Future<void> _reload() async { setState(() => _future = widget.repository.getMeasurements()); await _future; }

  Future<void> _openForm({Map<String, dynamic>? record}) async {
    List<Map<String, dynamic>> profiles = [];
    try {
      profiles = await widget.repository.getProfiles();
      if (widget.profile['role'] == 'supervisor') {
        final assigned = await widget.repository.getAssignedCadetIds();
        profiles = profiles.where((p) => assigned.contains(p['id'].toString())).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    if (widget.profile['role'] == 'supervisor' && profiles.isEmpty) {
      showMessage(context, 'Measurement যোগ করার আগে Admin-কে আপনার সঙ্গে Cadet Assign করতে বলুন।', error: true);
      return;
    }
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MeasurementFormDialog(record: record, profiles: profiles),
    );
    if (data == null) return;
    final id = data.remove('_id')?.toString();
    try {
      await widget.repository.saveMeasurement(data, id: id);
      if (mounted) { showMessage(context, id == null ? 'Measurement যোগ হয়েছে।' : 'Measurement Update হয়েছে।'); await _reload(); }
    } catch (e) { if (mounted) showMessage(context, 'Measurement Save করা যায়নি: $e', error: true); }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Measurement Delete করবেন?'),
      content: Text('${record['cadet_name']} (${record['cadet_number']})-এর তথ্য মুছে যাবে।'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (yes != true) return;
    try { await widget.repository.deleteMeasurement(record['id'].toString()); await _reload(); if (mounted) showMessage(context, 'Measurement Delete হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }

  Future<void> _clearAll() async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('সব Measurement Delete করবেন?'),
      content: const Text('এই কাজটি Undo করা যাবে না।'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('সব মুছুন'))],
    ));
    if (yes != true) return;
    try { await widget.repository.clearAllMeasurements(); await _reload(); if (mounted) showMessage(context, 'সব Measurement Delete হয়েছে।'); }
    catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }

  Future<void> _exportJson(List<Map<String, dynamic>> rows) async {
    // Export the original ZIP's camelCase field names so older JSON backups remain compatible.
    final legacyRows = rows.map((row) {
      final item = <String, dynamic>{
        'id': row['id'],
        'name': row['cadet_name'],
        'cadetNumber': row['cadet_number'],
      };
      for (final field in [..._shirtFields, ..._pantFields]) {
        item[_toCamel(field.$1)] = row[field.$1] ?? '';
      }
      return item;
    }).toList();
    final payload = {'app': 'Cadet Measurement Card Generator', 'version': 1,
      'exportedAt': DateTime.now().toIso8601String(), 'cadets': legacyRows};
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
    try {
      await SharePlus.instance.share(ShareParams(
        title: 'Easy NCC Measurement Backup',
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['cadet-measurements.json'],
      ));
    } catch (e) { if (mounted) showMessage(context, 'Export করা যায়নি: $e', error: true); }
  }

  Future<void> _importJson() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final parsed = jsonDecode(utf8.decode(bytes));
      final source = parsed is List ? parsed : parsed is Map ? parsed['cadets'] : null;
      if (source is! List) throw const FormatException('JSON file-এ cadets array পাওয়া যায়নি।');
      final records = source.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) =>
        (e['name'] ?? e['cadet_name']) != null && (e['cadetNumber'] ?? e['cadet_number']) != null).map((e) {
          final normalized = <String, dynamic>{
            'cadet_name': (e['cadet_name'] ?? e['name']).toString(),
            'cadet_number': (e['cadet_number'] ?? e['cadetNumber']).toString(),
          };
          for (final field in [..._shirtFields, ..._pantFields]) {
            final camel = _toCamel(field.$1);
            normalized[field.$1] = (e[field.$1] ?? e[camel] ?? '').toString();
          }
          // Imported UUIDs may belong to another Supabase project; re-link the Cadet after import.
          return normalized;
        }).toList();
      if (records.isEmpty) throw const FormatException('কোনো valid Cadet record পাওয়া যায়নি।');
      if (!mounted) return;
      final merge = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Import Mode'),
        content: Text('${records.length}টি record পাওয়া গেছে। বর্তমান ডাটা রেখে নতুন ডাটা যোগ করবেন?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Replace')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Merge')),
        ],
      ));
      if (merge == null) return;
      await widget.repository.importMeasurements(records, merge: merge);
      await _reload();
      if (mounted) showMessage(context, '${records.length}টি record Import হয়েছে।');
    } catch (e) { if (mounted) showMessage(context, 'Import করা যায়নি: $e', error: true); }
  }

  String _toCamel(String snake) {
    final parts = snake.split('_');
    return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  Future<void> _openPdf(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) { showMessage(context, 'PDF তৈরির জন্য আগে Cadet Measurement যোগ করুন।', error: true); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _MeasurementPdfPage(rows: rows, cardsPerPage: _cardsPerPage)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(error: snapshot.error!, onRetry: _reload);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final rows = all.where((r) => '${r['cadet_name']} ${r['cadet_number']}'.toLowerCase().contains(_query.toLowerCase())).toList();
        final pages = all.isEmpty ? 0 : (all.length / _cardsPerPage).ceil();
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(20), children: [
            PageHeading(title: 'Cadet Measurement', subtitle: 'Shirt ও Pant Measurement সংরক্ষণ, Edit এবং A4 Card তৈরি করুন.',
              action: _canManage ? FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Add')) : null),
            LayoutBuilder(builder: (context, constraints) => GridView.count(
              crossAxisCount: constraints.maxWidth > 760 ? 3 : 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.9,
              children: [
                StatCard(label: 'মোট ক্যাডেট', value: '${all.length}', icon: Icons.groups_outlined),
                StatCard(label: 'মোট A4 Page', value: '$pages', icon: Icons.description_outlined, tint: AppColors.gold),
                StatCard(label: 'Cards / Page', value: '$_cardsPerPage', icon: Icons.grid_view_outlined, tint: AppColors.greenLight),
              ],
            )),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _openPdf(all), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Print / PDF')),
              if (_canManage) OutlinedButton.icon(onPressed: () => _exportJson(all), icon: const Icon(Icons.download_outlined), label: const Text('Data Export')),
              if (_isAdmin) OutlinedButton.icon(onPressed: _importJson, icon: const Icon(Icons.upload_file_outlined), label: const Text('Data Import')),
              if (_isAdmin) OutlinedButton.icon(onPressed: _clearAll, icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger), label: const Text('Clear All')),
            ]),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              const Expanded(child: Text('প্রতি A4 Page-এ Card', style: TextStyle(fontWeight: FontWeight.w700))),
              SegmentedButton<int>(segments: const [ButtonSegment(value: 9, label: Text('9 Cards')), ButtonSegment(value: 12, label: Text('12 Cards'))],
                selected: {_cardsPerPage}, onSelectionChanged: (v) => setState(() => _cardsPerPage = v.first)),
            ]))),
            const SizedBox(height: 12),
            TextField(onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cadet Name বা Number দিয়ে Search করুন')),
            const SizedBox(height: 14),
            if (rows.isEmpty) const Card(child: EmptyState(title: 'কোনো Measurement পাওয়া যায়নি', message: 'নতুন Measurement যোগ করুন অথবা Search পরিবর্তন করুন.', icon: Icons.straighten_outlined))
            else ...rows.map((record) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: .18), child: const Icon(Icons.person_outline, color: AppColors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(record['cadet_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Cadet Number: ${record['cadet_number'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ])),
                  if (_canManage) PopupMenuButton<String>(onSelected: (v) {
                    if (v == 'edit') _openForm(record: record);
                    if (v == 'delete') _delete(record);
                  }, itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ]),
                ]),
                const Divider(height: 20),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _MeasurementChip(label: 'Shirt Body', value: record['shirt_body']),
                  _MeasurementChip(label: 'Shirt Length', value: record['shirt_length']),
                  _MeasurementChip(label: 'Pant Waist', value: record['pant_waist']),
                  _MeasurementChip(label: 'Pant Length', value: record['pant_length']),
                ]),
                const SizedBox(height: 8),
                Text('Updated: ${formatDate(record['updated_at'] ?? record['created_at'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ])),
            )),
          ]),
        );
      },
    );
  }
}

class _MeasurementChip extends StatelessWidget {
  const _MeasurementChip({required this.label, required this.value});
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label: ${value?.toString().isNotEmpty == true ? value : '—'}', style: const TextStyle(fontSize: 11)),
    backgroundColor: AppColors.background,
  );
}

class _MeasurementFormDialog extends StatefulWidget {
  const _MeasurementFormDialog({this.record, required this.profiles});
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> profiles;
  @override
  State<_MeasurementFormDialog> createState() => _MeasurementFormDialogState();
}

class _MeasurementFormDialogState extends State<_MeasurementFormDialog> {
  final Map<String, TextEditingController> _controllers = {};
  String? _cadetUserId;

  @override
  void initState() {
    super.initState();
    for (final key in ['cadet_name', 'cadet_number', ..._shirtFields.map((e) => e.$1), ..._pantFields.map((e) => e.$1)]) {
      final value = widget.record?[key] ?? '';
      _controllers[key] = TextEditingController(text: value.toString());
    }
    _cadetUserId = widget.record?['cadet_user_id']?.toString();
  }

  @override
  void dispose() { for (final c in _controllers.values) { c.dispose(); } super.dispose(); }

  Widget _field(String key, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(controller: _controllers[key], decoration: InputDecoration(labelText: required ? '$label *' : label),
      textCapitalization: key == 'cadet_name' ? TextCapitalization.words : TextCapitalization.none),
  );

  @override
  Widget build(BuildContext context) {
    final cadets = widget.profiles.where((p) => p['role'] == 'member').toList();
    return AlertDialog(
      title: Text(widget.record == null ? 'ক্যাডেটের মাপ যোগ করুন' : 'Measurement Edit করুন'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field('cadet_name', 'নাম', required: true),
        _field('cadet_number', 'ক্যাডেট নম্বর', required: true),
        if (cadets.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: DropdownButtonFormField<String?>(
          initialValue: _cadetUserId,
          decoration: const InputDecoration(labelText: 'Registered Cadet Account (Optional)'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('Not linked')),
            ...cadets.map((p) => DropdownMenuItem<String?>(value: p['id'].toString(), child: Text('${p['display_name']} • ${p['cadet_number'] ?? 'No number'}')))],
          onChanged: (v) => setState(() => _cadetUserId = v),
        )),
        Text('শার্টের মাপ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.green)),
        const SizedBox(height: 8),
        ..._shirtFields.map((f) => _field(f.$1, f.$2)),
        const SizedBox(height: 6),
        Text('প্যান্টের মাপ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.green)),
        const SizedBox(height: 8),
        ..._pantFields.map((f) => _field(f.$1, f.$2)),
        const Text('মাপ ফাঁকা রাখা যাবে। দশমিক ও ভগ্নাংশ লিখতে পারবেন।', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final name = _controllers['cadet_name']!.text.trim();
          final number = _controllers['cadet_number']!.text.trim();
          if (name.isEmpty || number.isEmpty) { showMessage(context, 'নাম ও ক্যাডেট নম্বর লিখুন।', error: true); return; }
          final data = <String, dynamic>{'cadet_name': name, 'cadet_number': number, 'cadet_user_id': _cadetUserId};
          for (final entry in _controllers.entries) { if (entry.key != 'cadet_name' && entry.key != 'cadet_number') data[entry.key] = entry.value.text.trim(); }
          if (widget.record != null) data['_id'] = widget.record!['id'];
          Navigator.pop(context, data);
        }, child: const Text('Save Measurement')),
      ],
    );
  }
}

class _MeasurementPdfPage extends StatelessWidget {
  const _MeasurementPdfPage({required this.rows, required this.cardsPerPage});
  final List<Map<String, dynamic>> rows;
  final int cardsPerPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A4 Measurement Card Preview')),
      body: PdfPreview(
        build: (_) => _buildPdf(rows, cardsPerPage),
        pdfFileName: 'easy-ncc-measurement-cards.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

Future<Uint8List> _buildPdf(List<Map<String, dynamic>> records, int cardsPerPage) async {
  final regular = await PdfGoogleFonts.notoSansBengaliRegular();
  final bold = await PdfGoogleFonts.notoSansBengaliBold();
  final document = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final rowCount = cardsPerPage == 9 ? 3 : 4;
  final cellHeight = cardsPerPage == 9 ? 260.0 : 195.0;
  for (var start = 0; start < records.length; start += cardsPerPage) {
    final pageRecords = records.skip(start).take(cardsPerPage).toList();
    final tableRows = <pw.TableRow>[];
    for (var r = 0; r < rowCount; r++) {
      final cells = <pw.Widget>[];
      for (var c = 0; c < 3; c++) {
        final index = r * 3 + c;
        cells.add(index < pageRecords.length
            ? _pdfMeasurementCard(pageRecords[index], cellHeight)
            : pw.SizedBox(height: cellHeight));
      }
      tableRows.add(pw.TableRow(children: cells));
    }
    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .6),
        columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth(), 2: pw.FlexColumnWidth()},
        children: tableRows,
      ),
    ));
  }
  return document.save();
}

pw.Widget _pdfMeasurementCard(Map<String, dynamic> record, double height) {
  pw.Widget fieldLine(String label, dynamic value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(children: [
      pw.Expanded(flex: 3, child: pw.Text(label, style: const pw.TextStyle(fontSize: 6.5))),
      pw.Expanded(flex: 2, child: pw.Text((value == null || value.toString().isEmpty) ? '—' : value.toString(),
        style: const pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
    ]),
  );
  return pw.Container(
    height: height,
    padding: const pw.EdgeInsets.all(5),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('BNCC • EASY NCC', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text(record['cadet_name']?.toString() ?? '', maxLines: 2, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.Text('ক্যাডেট নম্বর: ${record['cadet_number'] ?? ''}', style: const pw.TextStyle(fontSize: 7)),
      pw.Divider(height: 7),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('শার্টের মাপ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          ..._shirtFields.map((f) => fieldLine(f.$2, record[f.$1])),
        ])),
        pw.SizedBox(width: 4),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('প্যান্টের মাপ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          ..._pantFields.map((f) => fieldLine(f.$2, record[f.$1])),
        ])),
      ]),
    ]),
  );
}
