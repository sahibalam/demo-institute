import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../services/demo_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _FeesPanel extends StatefulWidget {
  const _FeesPanel({
    required this.loading,
    required this.students,
  });

  final bool loading;
  final List<Map<String, dynamic>> students;

  @override
  State<_FeesPanel> createState() => _FeesPanelState();
}

class _FeesPanelState extends State<_FeesPanel> {
  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _filterClass = '';
  String _filterStream = '';

static const String _envPhoneId = '861212063734417';
static const String _envAccessToken = 'EAASRpl7ndooBQTudWvGZBu0DsblZBg9ZCjZAjC1imNVZC5cuX4YUlAmWCssyYQ0QlOhM1x66LMjQjdg9ELdrSHOjERf7z0RUcph1dnc3QDggPcrwFUcqLXWEt485TTbV47vHXIi25IJELCRWEX5q52yiQiKnHZCcvZB2LFyUZAZCKmJoie6ZBfjQuxdUIRppzsd2lTiAZDZD';

  static const _feesCfgPhoneIdKey = 'demo_admin_fees_phone_id_v1';
  static const _feesCfgAccessTokenKey = 'demo_admin_fees_access_token_v1';

  final _phoneIdCtrl = TextEditingController();
  final _accessTokenCtrl = TextEditingController();

  final Map<String, bool> _selected = {};
  final Map<String, Set<String>> _selectedMonths = {};
  final Map<String, TextEditingController> _amountCtrl = {};

  bool _sending = false;
  String _sendNote = '';

  @override
  void initState() {
    super.initState();
    _restoreFeesCfg();
  }

  Future<void> _restoreFeesCfg() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneId = _envPhoneId.isNotEmpty ? _envPhoneId : (prefs.getString(_feesCfgPhoneIdKey) ?? '');
    final token = _envAccessToken.isNotEmpty ? _envAccessToken : (prefs.getString(_feesCfgAccessTokenKey) ?? '');
    if (!mounted) return;
    setState(() {
      _phoneIdCtrl.text = phoneId;
      _accessTokenCtrl.text = token;
    });
  }

  Future<void> _saveFeesCfg() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feesCfgPhoneIdKey, _phoneIdCtrl.text.trim());
    await prefs.setString(_feesCfgAccessTokenKey, _accessTokenCtrl.text.trim());
  }

  @override
  void dispose() {
    _phoneIdCtrl.dispose();
    _accessTokenCtrl.dispose();
    for (final c in _amountCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _idFor(Map<String, dynamic> x) => (x['studentId'] ?? x['id'] ?? x['_id'] ?? '').toString().trim();

  Iterable<Map<String, dynamic>> _filteredStudents() {
    return widget.students.where((x) {
      final klass = (x['class'] ?? '').toString();
      final stream = (x['stream'] ?? '').toString();
      if (_filterClass.isNotEmpty && klass != _filterClass) return false;
      if (_filterStream.isNotEmpty && stream != _filterStream) return false;
      return true;
    });
  }

  Uint8List _buildFeeReminderPdfBytes({
    required String studentId,
    required String studentName,
    required String month,
    required String amount,
  }) {
    final doc = PdfDocument();
    final page = doc.pages.add();

    final fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final fontBold = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);

    final size = page.getClientSize();
    final w = size.width;

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(137, 217, 9)),
      bounds: Rect.fromLTWH(0, 0, w, 70),
    );

    page.graphics.drawString(
      'DEMO INSTITUTE',
      fontTitle,
      bounds: Rect.fromLTWH(0, 18, w, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    page.graphics.drawString(
      'Fee Reminder',
      font,
      bounds: Rect.fromLTWH(0, 44, w, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    var y = 95.0;
    page.graphics.drawString('Student Details', fontHeader, bounds: Rect.fromLTWH(40, y, w - 80, 20));
    y += 28;

    void row(String label, String value) {
      page.graphics.drawString(label, fontBold, bounds: Rect.fromLTWH(40, y, 140, 18));
      page.graphics.drawString(value, font, bounds: Rect.fromLTWH(180, y, w - 220, 18));
      y += 20;
    }

    row('Student Name:', studentName);
    row('Student ID:', studentId);
    row('Month:', month);
    row('Amount:', 'Rs. $amount');

    y += 14;
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(241, 245, 249)),
      pen: PdfPen(PdfColor(203, 213, 225)),
      bounds: Rect.fromLTWH(40, y, w - 80, 70),
    );
    page.graphics.drawString('Please pay your pending fees at the earliest.', font, bounds: Rect.fromLTWH(54, y + 20, w - 108, 18));
    page.graphics.drawString('If already paid, please ignore this reminder.', font, bounds: Rect.fromLTWH(54, y + 42, w - 108, 18));

    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return bytes;
  }

  Future<String> _uploadPdfToBotclapGetMediaId({
    required Uint8List pdfBytes,
    required String filename,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('https://botclap.com/getMediaID'));
    req.fields['PhonenumberID'] = phoneNumberId;
    req.fields['PermanentAccessToken'] = accessToken;
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: filename,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('getMediaID failed: HTTP ${res.statusCode} ${res.body}');
    }

    final obj = jsonDecode(res.body);
    final mediaId = (obj is Map) ? (obj['MediaID'] ?? '').toString().trim() : '';
    if (mediaId.isEmpty) throw Exception('Failed to obtain MediaID');
    return mediaId;
  }

  Future<void> _sendBotclapWhatsAppTemplate({
    required String studentNumber,
    required String studentName,
    required String month,
    required String amount,
    required String mediaId,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    final var1 = Uri.encodeComponent(studentName);
    final var2 = Uri.encodeComponent(month);
    final var3 = Uri.encodeComponent(amount);

    final url =
        'https://botclap.com/apinotification/764610403118927/919875386318/fee_demo/UTILITY/$studentNumber/DEMO-INSTITUTE-Invoice/$accessToken/$phoneNumberId'
        '?mediaURL=$mediaId&body1=$var1&body2=$var2&body3=$var3';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('WhatsApp send failed: HTTP ${res.statusCode} ${res.body}');
    }
  }

  Future<void> _sendSelected() async {
    if (_sending) return;
    final selectedIds = _selected.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one student.')));
      return;
    }

    final phoneId = (_envPhoneId.isNotEmpty ? _envPhoneId : _phoneIdCtrl.text).trim();
    final accessToken = (_envAccessToken.isNotEmpty ? _envAccessToken : _accessTokenCtrl.text).trim();
    if (phoneId.isEmpty || accessToken.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set PhoneNumberID and PermanentAccessToken in Advanced settings.')),
      );
      return;
    }

    await _saveFeesCfg();

    final jobs = <({String number, String name, String month, String amount, String studentId})>[];
    var skipped = 0;

    for (final id in selectedIds) {
      final st = widget.students.firstWhere(
        (x) => _idFor(x) == id,
        orElse: () => const <String, dynamic>{},
      );
      final name = (st['name'] ?? '').toString().trim();
      final numberRaw = (st['number'] ?? '').toString().trim();
      final number = numberRaw.replaceAll(RegExp(r'[^0-9]'), '');

      final months = (_selectedMonths[id] ?? <String>{}).toList()..sort();
      final amount = (_amountCtrl[id]?.text ?? '').trim();

      if (number.isEmpty || name.isEmpty || months.isEmpty || amount.isEmpty) {
        skipped += 1;
        continue;
      }

      for (final m in months) {
        jobs.add((number: number, name: name, month: m, amount: amount, studentId: id));
      }
    }

    if (jobs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid selections. Make sure number, month and amount are filled.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _sending = true;
      _sendNote = 'Sending 0/${jobs.length}…';
    });

    var sent = 0;
    var failed = 0;

    for (var i = 0; i < jobs.length; i += 1) {
      final j = jobs[i];
      if (!mounted) break;
      setState(() {
        _sendNote = 'Sending ${i + 1}/${jobs.length}…';
      });
      try {
        final pdfBytes = _buildFeeReminderPdfBytes(
          studentId: j.studentId,
          studentName: j.name,
          month: j.month,
          amount: j.amount,
        );
        final filename = 'fee-reminder-${j.studentId}-${j.month}.pdf';
        final mediaId = await _uploadPdfToBotclapGetMediaId(
          pdfBytes: pdfBytes,
          filename: filename,
          phoneNumberId: phoneId,
          accessToken: accessToken,
        );
        await _sendBotclapWhatsAppTemplate(
          studentNumber: j.number,
          studentName: j.name,
          month: j.month,
          amount: j.amount,
          mediaId: mediaId,
          phoneNumberId: phoneId,
          accessToken: accessToken,
        );
        sent += 1;
      } catch (_) {
        failed += 1;
      }
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendNote = 'Done. Sent: $sent. Failed: $failed.';
    });

    if (!mounted) return;
    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skipped $skipped student(s) due to missing number/month/amount.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.students;
    final classOptions = <String>{};
    final streamOptions = <String>{};
    for (final x in all) {
      final klass = (x['class'] ?? '').toString();
      final stream = (x['stream'] ?? '').toString();
      if (klass.isNotEmpty) classOptions.add(klass);
      if (stream.isNotEmpty) streamOptions.add(stream);
    }
    final classes = classOptions.toList()..sort();
    final streams = streamOptions.toList()..sort();

    final rows = _filteredStudents().toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Fee Management', style: Theme.of(context).textTheme.titleMedium)),
                      FilledButton(
                        onPressed: (widget.loading || _sending) ? null : _sendSelected,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                  if (_sendNote.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_sendNote, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterClass.isEmpty ? null : _filterClass,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All')),
                            ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          ],
                          onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStream.isEmpty ? null : _filterStream,
                          decoration: const InputDecoration(labelText: 'Stream'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All')),
                            ...streams.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          ],
                          onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                        ),
                      ),
                    ],
                  ),
                  if (_envPhoneId.isEmpty || _envAccessToken.isEmpty) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Advanced WhatsApp Settings'),
                      children: [
                        TextField(
                          controller: _phoneIdCtrl,
                          decoration: const InputDecoration(labelText: 'PhonenumberID'),
                          enabled: !widget.loading && !_sending,
                          onChanged: (_) => _saveFeesCfg(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _accessTokenCtrl,
                          decoration: const InputDecoration(labelText: 'PermanentAccessToken'),
                          enabled: !widget.loading && !_sending,
                          onChanged: (_) => _saveFeesCfg(),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Center(child: Text('No students')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 82,
                  dataRowMaxHeight: 108,
                  dividerThickness: 0.9,
                  headingRowColor: WidgetStateProperty.all(AppTheme.surface2.withValues(alpha: 0.95)),
                  headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                  dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                  columns: const [
                    DataColumn(label: Text('SELECT')),
                    DataColumn(label: Text('STUDENT-ID')),
                    DataColumn(label: Text('NAME')),
                    DataColumn(label: Text('PHOTO')),
                    DataColumn(label: Text('NUMBER')),
                    DataColumn(label: Text('MONTH')),
                    DataColumn(label: Text('AMOUNT')),
                    DataColumn(label: Text('CLASS')),
                    DataColumn(label: Text('STREAM')),
                  ],
                  rows: rows.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final x = entry.value;
                  final id = _idFor(x);
                  final name = (x['name'] ?? '').toString();
                  final klass = (x['class'] ?? '').toString();
                  final stream = (x['stream'] ?? '').toString();
                  final number = (x['number'] ?? '').toString();
                  final photoBase64 = (x['photoBase64'] ?? '').toString();

                  _amountCtrl.putIfAbsent(id, () => TextEditingController());
                  _selectedMonths.putIfAbsent(id, () => <String>{});
                  _selected.putIfAbsent(id, () => false);

                  ImageProvider? photo;
                  if (photoBase64.trim().isNotEmpty) {
                    try {
                      final bytes = photoBase64.trim().startsWith('data:')
                          ? UriData.parse(photoBase64.trim()).contentAsBytes()
                          : base64Decode(photoBase64.contains('base64,') ? photoBase64.split('base64,').last : photoBase64);
                      photo = MemoryImage(bytes);
                    } catch (_) {
                      photo = null;
                    }
                  }

                  return DataRow(
                    color: WidgetStateProperty.resolveWith(
                      (states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.brandPrimaryDark.withValues(alpha: 0.28);
                        }
                        return rowIndex.isEven
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.06);
                      },
                    ),
                    cells: [
                      DataCell(
                        Transform.scale(
                          scale: 1.05,
                          child: Checkbox(
                            value: _selected[id] ?? false,
                            onChanged: widget.loading ? null : (v) => setState(() => _selected[id] = v ?? false),
                            activeColor: AppTheme.brandPrimary,
                          ),
                        ),
                      ),
                      DataCell(Text(id.isEmpty ? '—' : id)),
                      DataCell(Text(name.isEmpty ? '—' : name)),
                      DataCell(
                        photo == null
                            ? const Text('—')
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image(image: photo, width: 42, height: 42, fit: BoxFit.cover),
                              ),
                      ),
                      DataCell(Text(number.isEmpty ? '—' : number)),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<String>(
                                value: null,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  hintText: 'Select months',
                                ),
                                items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: widget.loading
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() {
                                          final set = _selectedMonths[id] ?? <String>{};
                                          if (set.contains(v)) set.remove(v);
                                          else set.add(v);
                                          _selectedMonths[id] = set;
                                        });
                                      },
                              ),
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final selected = (_selectedMonths[id] ?? <String>{}).toList()..sort();
                                  if (selected.isEmpty) {
                                    return Text('—', style: Theme.of(context).textTheme.bodySmall);
                                  }

                                  final shown = selected.take(3).toList();
                                  final remaining = selected.length - shown.length;
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...shown.map(
                                        (m) => Chip(
                                          label: Text(m, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          backgroundColor: AppTheme.surface2.withValues(alpha: 0.95),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      if (remaining > 0)
                                        Chip(
                                          label: Text('+$remaining', style: const TextStyle(fontWeight: FontWeight.w900)),
                                          backgroundColor: AppTheme.brandPrimaryDark.withValues(alpha: 0.35),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _amountCtrl[id],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Amount'),
                        ),
                      ),
                    ),
                    DataCell(Text(klass.isEmpty ? '—' : klass)),
                    DataCell(Text(stream.isEmpty ? '—' : stream)),
                  ],
                );
              }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  static const _prefsKey = 'optimum_admin_cfg_v1';
  static const _prefsCurrentSessionKey = 'optimum_admin_current_session_v1';

  final _api = DemoApi();

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String _note = '';

  String _user = '';
  String _pass = '';

  String _currentSession = '';

  List<Map<String, dynamic>> _lectures = const [];
  List<Map<String, dynamic>> _announcements = const [];
  List<Map<String, dynamic>> _sessions = const [];
  List<Map<String, dynamic>> _classes = const [];
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _materials = const [];
  List<Map<String, dynamic>> _timetables = const [];

  @override
  void initState() {
    super.initState();
    _restoreLogin();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey) ?? '';
    final currentSession = prefs.getString(_prefsCurrentSessionKey) ?? '';

    String user = '';
    String pass = '';
    try {
      if (raw.isNotEmpty) {
        final map = (raw is String) ? raw : '';
        final decoded = map.isNotEmpty ? _tryDecodeJson(map) : null;
        if (decoded != null) {
          user = (decoded['user'] ?? '').toString();
          pass = (decoded['pass'] ?? '').toString();
        }
      }
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _pass = pass;
      _currentSession = currentSession;
      _userCtrl.text = user;
      _passCtrl.text = pass;
    });

    if (_user.isNotEmpty && _pass.isNotEmpty) {
      await _loadAll();
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final obj = DemoApiJson.decode(raw);
      if (obj is Map<String, dynamic>) return obj;
      if (obj is Map) return obj.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLogin({required String user, required String pass}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, DemoApiJson.encode({'user': user, 'pass': pass}));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    if (!mounted) return;
    setState(() {
      _user = '';
      _pass = '';
      _note = 'Logged out.';
      _lectures = const [];
      _announcements = const [];
      _sessions = const [];
      _classes = const [];
      _students = const [];
      _materials = const [];
      _timetables = const [];
    });
  }

  Future<void> _setCurrentSession(String session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCurrentSessionKey, session);
    if (!mounted) return;
    setState(() {
      _currentSession = session;
    });
    await _loadClasses();
  }

  Future<void> _withLoading(Future<void> Function() fn) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _note = '';
    });
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _note = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _login() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() {
        _note = 'Enter username and password.';
      });
      return;
    }

    await _withLoading(() async {
      await _api.adminGetLectures(user: u, pass: p);
      await _saveLogin(user: u, pass: p);
      if (!mounted) return;
      setState(() {
        _user = u;
        _pass = p;
        _note = 'Logged in.';
      });
      await _loadAll();
    });
  }

  Future<void> _loadAll() async {
    if (_user.isEmpty || _pass.isEmpty) return;
    await _withLoading(() async {
      await Future.wait([
        _loadLectures(),
        _loadAnnouncements(),
        _loadSessions(),
        _loadStudents(),
        _loadMaterials(),
        _loadTimetables(),
      ]);

      if (_currentSession.isEmpty) {
        final first = _sessions.isNotEmpty ? (_sessions.first['name'] ?? '').toString().trim() : '';
        if (first.isNotEmpty) {
          await _setCurrentSession(first);
        }
      } else {
        await _loadClasses();
      }
    });
  }

  Future<void> _loadLectures() async {
    final items = await _api.adminGetLectures(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _lectures = items;
    });
  }

  Future<void> _loadAnnouncements() async {
    final items = await _api.adminGetAnnouncements(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _announcements = items;
    });
  }

  Future<void> _loadSessions() async {
    final items = await _api.adminGetSessions(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _sessions = items;
    });
  }

  Future<void> _loadClasses() async {
    if (_currentSession.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _classes = const [];
      });
      return;
    }
    final items = await _api.adminGetClasses(user: _user, pass: _pass, session: _currentSession);
    if (!mounted) return;
    setState(() {
      _classes = items;
    });
  }

  Future<void> _loadStudents() async {
    final items = await _api.adminGetStudents(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _students = items;
    });
  }

  Future<void> _loadMaterials() async {
    final items = await _api.adminGetMaterials(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _materials = items;
    });
  }

  Future<void> _loadTimetables() async {
    final items = await _api.adminGetTimetables(user: _user, pass: _pass);
    if (!mounted) return;
    setState(() {
      _timetables = items;
    });
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final set = <String>{};
    for (final v in values) {
      final s = v.trim();
      if (s.isEmpty) continue;
      set.add(s);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _user.isNotEmpty && _pass.isNotEmpty;

    return AppScaffold(
      title: 'Admin Dashboard',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _note,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_loading) const SizedBox(width: 16),
                if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
            if (!isLoggedIn) _buildLogin(context),
            if (isLoggedIn) Expanded(child: _buildDashboard(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _userCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Admin Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                onSubmitted: (_) => _login(),
                decoration: const InputDecoration(labelText: 'Admin Password'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _currentSession.isEmpty ? null : _currentSession,
                  decoration: const InputDecoration(labelText: 'Current Session'),
                  items: _uniqueSorted(_sessions.map((x) => (x['name'] ?? '').toString()))
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v == null) return;
                          _setCurrentSession(v);
                        },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _loading ? null : _loadAll,
                child: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loading ? null : _logout,
                child: const Text('Log out'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Lectures'),
              Tab(text: 'Announcements'),
              Tab(text: 'Sessions'),
              Tab(text: 'Classes'),
              Tab(text: 'Students'),
              Tab(text: 'Materials'),
              Tab(text: 'Time-table'),
              Tab(text: 'Fees'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildLecturesTab(context),
                _buildAnnouncementsTab(context),
                _buildSessionsTab(context),
                _buildClassesTab(context),
                _buildStudentsTab(context),
                _buildMaterialsTab(context),
                _buildTimetablesTab(context),
                _buildFeesTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _classOptions() {
    return _uniqueSorted(_classes.map((x) => (x['class'] ?? x['klass'] ?? '').toString()));
  }

  List<String> _streamOptionsForClass(String klass) {
    final streams = _classes
        .where((x) => (x['class'] ?? x['klass'] ?? '').toString().trim() == klass.trim())
        .map((x) => (x['stream'] ?? x['section'] ?? '').toString());
    return _uniqueSorted(streams);
  }

  Widget _buildLecturesTab(BuildContext context) {
    return _LecturePanel(
      loading: _loading,
      classOptions: _classOptions(),
      streamsForClass: _streamOptionsForClass,
      items: _lectures,
      onCreate: (payload) => _withLoading(() async {
        await _api.adminCreateLecture(user: _user, pass: _pass, payload: payload);
        await _loadLectures();
      }),
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteLecture(user: _user, pass: _pass, id: id);
        await _loadLectures();
      }),
    );
  }

  Widget _buildAnnouncementsTab(BuildContext context) {
    return _AnnouncementPanel(
      loading: _loading,
      classOptions: _classOptions(),
      streamsForClass: _streamOptionsForClass,
      items: _announcements,
      onCreate: (payload) => _withLoading(() async {
        await _api.adminCreateAnnouncement(user: _user, pass: _pass, payload: payload);
        await _loadAnnouncements();
      }),
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteAnnouncement(user: _user, pass: _pass, id: id);
        await _loadAnnouncements();
      }),
    );
  }

  Widget _buildSessionsTab(BuildContext context) {
    return _SessionsPanel(
      loading: _loading,
      items: _sessions,
      onCreate: (name) => _withLoading(() async {
        await _api.adminCreateSession(user: _user, pass: _pass, name: name);
        await _loadSessions();
      }),
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteSession(user: _user, pass: _pass, id: id);
        await _loadSessions();
      }),
    );
  }

  Widget _buildClassesTab(BuildContext context) {
    return _ClassesPanel(
      loading: _loading,
      currentSession: _currentSession,
      items: _classes,
      onCreate: ({required String klass, required String stream}) => _withLoading(() async {
        await _api.adminCreateClass(user: _user, pass: _pass, session: _currentSession, klass: klass, stream: stream);
        await _loadClasses();
      }),
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteClass(user: _user, pass: _pass, id: id);
        await _loadClasses();
      }),
    );
  }

  Widget _buildStudentsTab(BuildContext context) {
    return _StudentsPanel(
      loading: _loading,
      items: _students,
      onPatch: (id, payload) => _withLoading(() async {
        await _api.adminPatchStudent(user: _user, pass: _pass, id: id, payload: payload);
        await _loadStudents();
      }),
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteStudent(user: _user, pass: _pass, id: id);
        await _loadStudents();
      }),
    );
  }

  Widget _buildMaterialsTab(BuildContext context) {
    return _MaterialsUploadPanel(
      loading: _loading,
      classOptions: _classOptions(),
      streamsForClass: _streamOptionsForClass,
      items: _materials,
      onUpload: ({
        required PlatformFile file,
        required String category,
        required String klass,
        required String section,
        required String subject,
        required String title,
        required String year,
        required String chapter,
        required void Function(double p) onProgress,
      }) async {
        final start = await _api.adminStartResumableUpload(
          user: _user,
          pass: _pass,
          startPath: '/admin/materials/resumable/start',
          fileName: file.name,
          mimeType: 'application/pdf',
          size: file.size,
        );
        final uploadUrl = (start['uploadUrl'] ?? '').toString();
        if (uploadUrl.isEmpty) throw Exception('Missing uploadUrl');

        final bytes = file.bytes;
        if (bytes == null) throw Exception('Failed to read file bytes');

        const chunkSize = 4 * 1024 * 1024;
        int offset = 0;
        String fileId = '';
        while (offset < bytes.length) {
          final end = (offset + chunkSize) > bytes.length ? bytes.length : (offset + chunkSize);
          final chunk = bytes.sublist(offset, end);
          final resp = await _api.adminUploadResumableChunk(
            user: _user,
            pass: _pass,
            chunkPath: '/admin/materials/resumable/chunk',
            uploadUrl: uploadUrl,
            bytes: chunk,
            start: offset,
            endExclusive: end,
            total: bytes.length,
          );
          final st = int.tryParse((resp['status'] ?? '0').toString()) ?? 0;
          if (st == 308) {
            offset = end;
            onProgress(offset / bytes.length);
            continue;
          }
          if (st >= 200 && st < 300) {
            fileId = ((resp['data'] ?? const {}) is Map ? (resp['data'] as Map)['id'] : null)?.toString() ?? '';
            if (fileId.isEmpty) throw Exception('Upload finished but missing Drive file id');
            offset = bytes.length;
            onProgress(1);
            break;
          }
          throw Exception('Chunk upload failed (Drive status $st)');
        }

        final payload = <String, dynamic>{
          'category': category.trim(),
          'class': klass.trim(),
          'section': section.trim(),
          'subject': subject.trim(),
          'title': title.trim(),
          'year': year.trim(),
          'chapter': chapter.trim(),
          'fileId': fileId,
          'fileName': file.name,
        };
        await _api.adminFinalizeResumableUpload(
          user: _user,
          pass: _pass,
          finalizePath: '/admin/materials/resumable/finalize',
          payload: payload,
        );
        await _loadMaterials();
      },
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteMaterial(user: _user, pass: _pass, id: id);
        await _loadMaterials();
      }),
    );
  }

  Widget _buildTimetablesTab(BuildContext context) {
    return _TimetableUploadPanel(
      loading: _loading,
      classOptions: _classOptions(),
      streamsForClass: _streamOptionsForClass,
      items: _timetables,
      onUpload: ({required PlatformFile file, required String klass, required String section, required String title, required void Function(double p) onProgress}) async {
        final start = await _api.adminStartResumableUpload(
          user: _user,
          pass: _pass,
          startPath: '/admin/timetables/resumable/start',
          fileName: file.name,
          mimeType: 'application/pdf',
          size: file.size,
        );
        final uploadUrl = (start['uploadUrl'] ?? '').toString();
        if (uploadUrl.isEmpty) throw Exception('Missing uploadUrl');

        final bytes = file.bytes;
        if (bytes == null) throw Exception('Failed to read file bytes');

        const chunkSize = 4 * 1024 * 1024;
        int offset = 0;
        String fileId = '';
        while (offset < bytes.length) {
          final end = (offset + chunkSize) > bytes.length ? bytes.length : (offset + chunkSize);
          final chunk = bytes.sublist(offset, end);
          final resp = await _api.adminUploadResumableChunk(
            user: _user,
            pass: _pass,
            chunkPath: '/admin/timetables/resumable/chunk',
            uploadUrl: uploadUrl,
            bytes: chunk,
            start: offset,
            endExclusive: end,
            total: bytes.length,
          );
          final st = int.tryParse((resp['status'] ?? '0').toString()) ?? 0;
          if (st == 308) {
            offset = end;
            onProgress(offset / bytes.length);
            continue;
          }
          if (st >= 200 && st < 300) {
            fileId = ((resp['data'] ?? const {}) is Map ? (resp['data'] as Map)['id'] : null)?.toString() ?? '';
            if (fileId.isEmpty) throw Exception('Upload finished but missing Drive file id');
            offset = bytes.length;
            onProgress(1);
            break;
          }
          throw Exception('Chunk upload failed (Drive status $st)');
        }

        final payload = <String, dynamic>{
          'class': klass.trim(),
          'section': section.trim(),
          'title': title.trim(),
          'fileId': fileId,
          'fileName': file.name,
        };
        await _api.adminFinalizeResumableUpload(
          user: _user,
          pass: _pass,
          finalizePath: '/admin/timetables/resumable/finalize',
          payload: payload,
        );
        await _loadTimetables();
      },
      onDelete: (id) => _withLoading(() async {
        await _api.adminDeleteTimetable(user: _user, pass: _pass, id: id);
        await _loadTimetables();
      }),
    );
  }

  Widget _buildFeesTab(BuildContext context) {
    return _FeesPanel(
      loading: _loading,
      students: _students,
    );
  }
}

class _TimetableUploadPanel extends StatefulWidget {
  const _TimetableUploadPanel({
    required this.loading,
    required this.classOptions,
    required this.streamsForClass,
    required this.items,
    required this.onUpload,
    required this.onDelete,
  });

  final bool loading;
  final List<String> classOptions;
  final List<String> Function(String klass) streamsForClass;
  final List<Map<String, dynamic>> items;

  final Future<void> Function({
    required PlatformFile file,
    required String klass,
    required String section,
    required String title,
    required void Function(double p) onProgress,
  }) onUpload;

  final Future<void> Function(String id) onDelete;

  @override
  State<_TimetableUploadPanel> createState() => _TimetableUploadPanelState();
}

class _TimetableUploadPanelState extends State<_TimetableUploadPanel> {
  PlatformFile? _file;
  double _progress = 0;

  String _klass = '';
  String _section = '';
  final _titleCtrl = TextEditingController();

  String _filterClass = '';
  String _filterStream = '';

  String _timetablePdfUrl(Map<String, dynamic> x) {
    final fileId = (x['fileId'] ?? x['driveId'] ?? x['gdriveId'] ?? '').toString().trim();
    if (fileId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=${Uri.encodeComponent(fileId)}';
    }

    final candidates = <String>[
      (x['bestLink'] ?? '').toString(),
      (x['url'] ?? '').toString(),
      (x['link'] ?? '').toString(),
      (x['fileUrl'] ?? '').toString(),
      (x['pdfUrl'] ?? '').toString(),
      (x['downloadUrl'] ?? '').toString(),
    ];
    for (final c in candidates) {
      final u = c.trim();
      if (u.isNotEmpty) return u;
    }
    return '';
  }

  Future<void> _openTimetablePdf(BuildContext context, Map<String, dynamic> x) async {
    final title = (x['title'] ?? x['fileName'] ?? 'Time-table').toString().trim();
    final url = _timetablePdfUrl(x);
    if (url.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing timetable PDF link')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title.isEmpty ? 'Time-table' : title)),
          body: SfPdfViewer.network(url),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    final f = res?.files.isNotEmpty == true ? res!.files.first : null;
    setState(() {
      _file = f;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final streams = _klass.isEmpty ? const <String>[] : widget.streamsForClass(_klass);

    final classOptions = <String>{};
    final streamOptions = <String>{};
    for (final x in widget.items) {
      final c = (x['class'] ?? '').toString().trim();
      final s = (x['section'] ?? x['stream'] ?? '').toString().trim();
      if (c.isNotEmpty) classOptions.add(c);
      if (s.isNotEmpty) streamOptions.add(s);
    }
    final classes = classOptions.toList()..sort();
    final streamList = streamOptions.toList()..sort();

    final filteredItems = widget.items.where((x) {
      final c = (x['class'] ?? '').toString();
      final s = (x['section'] ?? x['stream'] ?? '').toString();
      if (_filterClass.isNotEmpty && c != _filterClass) return false;
      if (_filterStream.isNotEmpty && s != _filterStream) return false;
      return true;
    }).toList();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Upload Time-table (PDF)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _klass.isEmpty ? null : _klass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: widget.loading
                      ? null
                      : (v) {
                          setState(() {
                            _klass = v ?? '';
                            _section = '';
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _section.isEmpty ? null : _section,
                  decoration: const InputDecoration(labelText: 'Stream'),
                  items: streams.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.loading ? null : (v) => setState(() => _section = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title (optional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.loading ? null : _pickPdf,
                        child: Text(_file == null ? 'Choose PDF' : 'Selected: ${_file!.name}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: widget.loading || _file == null || _klass.isEmpty || _section.isEmpty
                          ? null
                          : () async {
                              setState(() => _progress = 0);
                              await widget.onUpload(
                                file: _file!,
                                klass: _klass,
                                section: _section,
                                title: _titleCtrl.text,
                                onProgress: (p) {
                                  if (!mounted) return;
                                  setState(() => _progress = p);
                                },
                              );
                              if (!mounted) return;
                              setState(() {
                                _file = null;
                                _progress = 0;
                                _titleCtrl.clear();
                              });
                            },
                      child: const Text('Upload PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: widget.loading ? null : (_progress <= 0 ? 0 : _progress)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Time-tables', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterClass.isEmpty ? null : _filterClass,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStream.isEmpty ? null : _filterStream,
                    decoration: const InputDecoration(labelText: 'Stream'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...streamList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...filteredItems.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final title = (x['title'] ?? x['fileName'] ?? '').toString();
          final klass = (x['class'] ?? '').toString();
          final section = (x['section'] ?? '').toString();
          final extra = <String>[
            if (klass.isNotEmpty) 'Class $klass',
            if (section.isNotEmpty) section,
          ].join(' • ');
          return Card(
            child: ListTile(
              title: Text(title.isEmpty ? '(Untitled)' : title),
              subtitle: extra.isEmpty ? null : Text(extra),
              onTap: _timetablePdfUrl(x).trim().isEmpty ? null : () => _openTimetablePdf(context, x),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'View',
                    onPressed: _timetablePdfUrl(x).trim().isEmpty ? null : () => _openTimetablePdf(context, x),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No items')),
          ),
      ],
    );
  }
}

class _MaterialsUploadPanel extends StatefulWidget {
  const _MaterialsUploadPanel({
    required this.loading,
    required this.classOptions,
    required this.streamsForClass,
    required this.items,
    required this.onUpload,
    required this.onDelete,
  });

  final bool loading;
  final List<String> classOptions;
  final List<String> Function(String klass) streamsForClass;
  final List<Map<String, dynamic>> items;

  final Future<void> Function({
    required PlatformFile file,
    required String category,
    required String klass,
    required String section,
    required String subject,
    required String title,
    required String year,
    required String chapter,
    required void Function(double p) onProgress,
  }) onUpload;

  final Future<void> Function(String id) onDelete;

  @override
  State<_MaterialsUploadPanel> createState() => _MaterialsUploadPanelState();
}

class _MaterialsUploadPanelState extends State<_MaterialsUploadPanel> {
  PlatformFile? _file;
  double _progress = 0;

  String _category = 'materials';
  String _klass = '';
  String _section = '';

  String _filterClass = '';
  String _filterStream = '';
  String _filterSubject = '';
  String _filterCategory = '';

  String _materialPdfUrl(Map<String, dynamic> x) {
    final fileId = (x['fileId'] ?? x['driveId'] ?? x['gdriveId'] ?? '').toString().trim();
    if (fileId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=${Uri.encodeComponent(fileId)}';
    }

    final candidates = <String>[
      (x['bestLink'] ?? '').toString(),
      (x['url'] ?? '').toString(),
      (x['link'] ?? '').toString(),
      (x['fileUrl'] ?? '').toString(),
      (x['pdfUrl'] ?? '').toString(),
      (x['downloadUrl'] ?? '').toString(),
    ];
    for (final c in candidates) {
      final u = c.trim();
      if (u.isNotEmpty) return u;
    }
    return '';
  }

  Future<void> _openMaterialPdf(BuildContext context, Map<String, dynamic> x) async {
    final title = (x['title'] ?? x['fileName'] ?? 'Material').toString().trim();
    final url = _materialPdfUrl(x);
    if (url.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing PDF link')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title.isEmpty ? 'Material' : title)),
          body: SfPdfViewer.network(url),
        ),
      ),
    );
  }

  final _subjectCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _titleCtrl.dispose();
    _yearCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    final f = res?.files.isNotEmpty == true ? res!.files.first : null;
    setState(() {
      _file = f;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final streams = _klass.isEmpty ? const <String>[] : widget.streamsForClass(_klass);
    final showTitle = _category == 'materials' || _category == 'yearspapers' || _category == 'chaptersolutions';
    final showYear = _category == 'yearspapers';
    final showChapter = _category == 'chaptersolutions';
    final requireYear = _category == 'yearspapers';

    final classOptions = <String>{};
    final streamOptions = <String>{};
    final subjectOptions = <String>{};
    final categoryOptions = <String>{};
    for (final x in widget.items) {
      final c = (x['class'] ?? '').toString().trim();
      final s = (x['section'] ?? '').toString().trim();
      final subj = (x['subject'] ?? '').toString().trim();
      final cat = (x['category'] ?? '').toString().trim();
      if (c.isNotEmpty) classOptions.add(c);
      if (s.isNotEmpty) streamOptions.add(s);
      if (subj.isNotEmpty) subjectOptions.add(subj);
      if (cat.isNotEmpty) categoryOptions.add(cat);
    }
    final classList = classOptions.toList()..sort();
    final streamList = streamOptions.toList()..sort();
    final subjectList = subjectOptions.toList()..sort();
    final categoryList = categoryOptions.toList()..sort();

    final filteredItems = widget.items.where((x) {
      final c = (x['class'] ?? '').toString();
      final s = (x['section'] ?? '').toString();
      final subj = (x['subject'] ?? '').toString();
      final cat = (x['category'] ?? '').toString();
      if (_filterClass.isNotEmpty && c != _filterClass) return false;
      if (_filterStream.isNotEmpty && s != _filterStream) return false;
      if (_filterSubject.isNotEmpty && subj != _filterSubject) return false;
      if (_filterCategory.isNotEmpty && cat != _filterCategory) return false;
      return true;
    }).toList();
    final canUpload =
        _file != null &&
        _klass.isNotEmpty &&
        _section.isNotEmpty &&
        _subjectCtrl.text.trim().isNotEmpty &&
        (!requireYear || _yearCtrl.text.trim().isNotEmpty);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Upload Study Material / Year\'s Paper / Chapter Solution (PDF)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'materials', child: Text('Study Materials')),
                    DropdownMenuItem(value: 'yearspapers', child: Text("Year's Papers")),
                    DropdownMenuItem(value: 'chaptersolutions', child: Text('Chapter Solutions')),
                  ],
                  onChanged: widget.loading
                      ? null
                      : (v) {
                          final next = v ?? 'materials';
                          setState(() {
                            _category = next;
                            if (next != 'yearspapers') _yearCtrl.clear();
                            if (next != 'chaptersolutions') _chapterCtrl.clear();
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _klass.isEmpty ? null : _klass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: widget.loading
                      ? null
                      : (v) {
                          setState(() {
                            _klass = v ?? '';
                            _section = '';
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _section.isEmpty ? null : _section,
                  decoration: const InputDecoration(labelText: 'Stream'),
                  items: streams.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.loading ? null : (v) => setState(() => _section = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subjectCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                if (showTitle) ...[
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title (optional)'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (showYear) ...[
                  TextField(
                    controller: _yearCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (showChapter) ...[
                  TextField(
                    controller: _chapterCtrl,
                    decoration: const InputDecoration(labelText: 'Chapter (optional)'),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.loading ? null : _pickPdf,
                        child: Text(_file == null ? 'Choose PDF' : 'Selected: ${_file!.name}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: widget.loading || !canUpload
                          ? null
                          : () async {
                              setState(() => _progress = 0);
                              await widget.onUpload(
                                file: _file!,
                                category: _category,
                                klass: _klass,
                                section: _section,
                                subject: _subjectCtrl.text,
                                title: _titleCtrl.text,
                                year: _yearCtrl.text,
                                chapter: _chapterCtrl.text,
                                onProgress: (p) {
                                  if (!mounted) return;
                                  setState(() => _progress = p);
                                },
                              );
                              if (!mounted) return;
                              setState(() {
                                _file = null;
                                _progress = 0;
                                _subjectCtrl.clear();
                                _titleCtrl.clear();
                                _yearCtrl.clear();
                                _chapterCtrl.clear();
                              });
                            },
                      child: const Text('Upload PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: widget.loading ? null : (_progress <= 0 ? 0 : _progress)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Materials', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterClass.isEmpty ? null : _filterClass,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...classList.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStream.isEmpty ? null : _filterStream,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Stream'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...streamList.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterCategory.isEmpty ? null : _filterCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          const DropdownMenuItem(value: 'materials', child: Text('Study Materials')),
                          const DropdownMenuItem(value: 'yearspapers', child: Text("Year's Papers")),
                          const DropdownMenuItem(value: 'chaptersolutions', child: Text('Chapter Solutions')),
                          ...categoryList
                              .where((c) => c != 'materials' && c != 'yearspapers' && c != 'chaptersolutions')
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterCategory = (v ?? '')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterSubject.isEmpty ? null : _filterSubject,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...subjectList.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterSubject = (v ?? '')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...filteredItems.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final title = (x['title'] ?? x['fileName'] ?? '').toString();
          final klass = (x['class'] ?? '').toString();
          final section = (x['section'] ?? '').toString();
          final subject = (x['subject'] ?? '').toString();
          final category = (x['category'] ?? '').toString();
          final extra = <String>[
            if (category.isNotEmpty) category,
            if (klass.isNotEmpty) 'Class $klass',
            if (section.isNotEmpty) section,
            if (subject.isNotEmpty) subject,
          ].join(' • ');
          return Card(
            child: ListTile(
              title: Text(title.isEmpty ? '(Untitled)' : title),
              subtitle: extra.isEmpty ? null : Text(extra),
              onTap: _materialPdfUrl(x).trim().isEmpty ? null : () => _openMaterialPdf(context, x),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'View',
                    onPressed: _materialPdfUrl(x).trim().isEmpty ? null : () => _openMaterialPdf(context, x),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No items')),
          ),
      ],
    );
  }
}

enum _PdfFieldKind { text, textOptional, category }

class _PdfField {
  const _PdfField({required this.keyName, required this.label, required this.kind});
  final String keyName;
  final String label;
  final _PdfFieldKind kind;
}

class _ResumablePdfPanel extends StatefulWidget {
  const _ResumablePdfPanel({
    required this.loading,
    required this.title,
    required this.uploadButtonText,
    required this.itemsTitle,
    required this.items,
    required this.extraFields,
    required this.onUpload,
    required this.onDelete,
  });

  final bool loading;
  final String title;
  final String uploadButtonText;
  final String itemsTitle;
  final List<Map<String, dynamic>> items;
  final List<_PdfField> extraFields;

  final Future<void> Function({
    required PlatformFile file,
    required Map<String, String> fields,
    required void Function(double p) onProgress,
  }) onUpload;

  final Future<void> Function(String id) onDelete;

  @override
  State<_ResumablePdfPanel> createState() => _ResumablePdfPanelState();
}

class _ResumablePdfPanelState extends State<_ResumablePdfPanel> {
  PlatformFile? _file;
  double _progress = 0;

  final Map<String, TextEditingController> _ctrl = {};
  String _category = 'materials';

  @override
  void initState() {
    super.initState();
    for (final f in widget.extraFields) {
      if (f.kind == _PdfFieldKind.category) continue;
      _ctrl[f.keyName] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _fields() {
    final m = <String, String>{};
    for (final f in widget.extraFields) {
      if (f.kind == _PdfFieldKind.category) {
        m[f.keyName] = _category;
      } else {
        m[f.keyName] = (_ctrl[f.keyName]?.text ?? '').trim();
      }
    }
    return m;
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    final f = res?.files.isNotEmpty == true ? res!.files.first : null;
    setState(() {
      _file = f;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...widget.extraFields.map((f) {
                  if (f.kind == _PdfFieldKind.category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(labelText: f.label),
                        items: const [
                          DropdownMenuItem(value: 'materials', child: Text('Study Materials')),
                          DropdownMenuItem(value: 'yearspapers', child: Text("Year's Papers")),
                          DropdownMenuItem(value: 'chaptersolutions', child: Text('Chapter Solutions')),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _category = v ?? 'materials'),
                      ),
                    );
                  }

                  final c = _ctrl[f.keyName]!;
                  final optional = f.kind == _PdfFieldKind.textOptional;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: c,
                      decoration: InputDecoration(labelText: f.label + (optional ? '' : '')),
                    ),
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.loading ? null : _pickPdf,
                        child: Text(_file == null ? 'Choose PDF' : 'Selected: ${_file!.name}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: widget.loading || _file == null
                          ? null
                          : () async {
                              setState(() => _progress = 0);
                              await widget.onUpload(
                                file: _file!,
                                fields: _fields(),
                                onProgress: (p) {
                                  if (!mounted) return;
                                  setState(() => _progress = p);
                                },
                              );
                              if (!mounted) return;
                              setState(() {
                                _file = null;
                                _progress = 0;
                                for (final c in _ctrl.values) {
                                  c.clear();
                                }
                              });
                            },
                      child: Text(widget.uploadButtonText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: widget.loading ? null : (_progress <= 0 ? 0 : _progress)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(widget.itemsTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        ...widget.items.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final title = (x['title'] ?? x['fileName'] ?? '').toString();
          final klass = (x['class'] ?? '').toString();
          final section = (x['section'] ?? x['stream'] ?? '').toString();
          final subject = (x['subject'] ?? '').toString();
          final category = (x['category'] ?? '').toString();
          final extra = <String>[
            if (category.isNotEmpty) category,
            if (klass.isNotEmpty) 'Class $klass',
            if (section.isNotEmpty) section,
            if (subject.isNotEmpty) subject,
          ].join(' • ');
          return Card(
            child: ListTile(
              title: Text(title.isEmpty ? '(Untitled)' : title),
              subtitle: extra.isEmpty ? null : Text(extra),
              trailing: IconButton(
                onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
        if (widget.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No items')),
          ),
      ],
    );
  }
}

class DemoApiJson {
  static dynamic decode(String raw) => jsonDecode(raw);
  static String encode(Object? obj) => jsonEncode(obj);
}

class _LecturePanel extends StatefulWidget {
  const _LecturePanel({
    required this.loading,
    required this.classOptions,
    required this.streamsForClass,
    required this.items,
    required this.onCreate,
    required this.onDelete,
  });

  final bool loading;
  final List<String> classOptions;
  final List<String> Function(String klass) streamsForClass;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> payload) onCreate;
  final Future<void> Function(String id) onDelete;

  @override
  State<_LecturePanel> createState() => _LecturePanelState();
}

class _LecturePanelState extends State<_LecturePanel> {
  final _subjectCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  String _klass = '';
  String _section = '';

  String _filterClass = '';
  String _filterStream = '';
  String _filterSubject = '';

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _showYoutubePlayer(BuildContext context, String youtubeUrl) async {
    final url = youtubeUrl.trim();
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null || videoId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid YouTube URL')),
      );
      return;
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _YoutubePlayerPage(controller: controller),
      ),
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streams = _klass.isEmpty ? const <String>[] : widget.streamsForClass(_klass);

    final classOptions = <String>{};
    final streamOptions = <String>{};
    final subjectOptions = <String>{};
    for (final x in widget.items) {
      final c = (x['class'] ?? '').toString().trim();
      final s = (x['section'] ?? x['stream'] ?? '').toString().trim();
      final subj = (x['subject'] ?? '').toString().trim();
      if (c.isNotEmpty) classOptions.add(c);
      if (s.isNotEmpty) streamOptions.add(s);
      if (subj.isNotEmpty) subjectOptions.add(subj);
    }
    final classes = classOptions.toList()..sort();
    final streamList = streamOptions.toList()..sort();
    final subjectList = subjectOptions.toList()..sort();

    final filteredItems = widget.items.where((x) {
      final c = (x['class'] ?? '').toString();
      final s = (x['section'] ?? x['stream'] ?? '').toString();
      final subj = (x['subject'] ?? '').toString();
      if (_filterClass.isNotEmpty && c != _filterClass) return false;
      if (_filterStream.isNotEmpty && s != _filterStream) return false;
      if (_filterSubject.isNotEmpty && subj != _filterSubject) return false;
      return true;
    }).toList();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Lecture', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _klass.isEmpty ? null : _klass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: widget.loading
                      ? null
                      : (v) {
                          setState(() {
                            _klass = v ?? '';
                            _section = '';
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _section.isEmpty ? null : _section,
                  decoration: const InputDecoration(labelText: 'Stream'),
                  items: streams.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.loading ? null : (v) => setState(() => _section = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(labelText: 'YouTube URL'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.loading
                      ? null
                      : () async {
                          await widget.onCreate({
                            'class': _klass,
                            'section': _section,
                            'subject': _subjectCtrl.text.trim(),
                            'youtubeUrl': _urlCtrl.text.trim(),
                          });
                          _subjectCtrl.clear();
                          _urlCtrl.clear();
                        },
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterClass.isEmpty ? null : _filterClass,
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStream.isEmpty ? null : _filterStream,
                        decoration: const InputDecoration(labelText: 'Stream'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...streamList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filterSubject.isEmpty ? null : _filterSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    ...subjectList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: widget.loading ? null : (v) => setState(() => _filterSubject = (v ?? '')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...filteredItems.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final title = 'Class ${x['class'] ?? ''} • ${x['section'] ?? ''} • ${x['subject'] ?? ''}';
          final url = (x['youtubeUrl'] ?? '').toString();
          final createdAt = (x['createdAt'] ?? '').toString();
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (url.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final videoId = YoutubePlayer.convertUrlToId(url.trim());
                        if (videoId == null || videoId.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final thumbUrl = 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              thumbUrl,
                              width: 120,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (createdAt.isNotEmpty) Text(createdAt),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Play',
                    onPressed: widget.loading || url.trim().isEmpty ? null : () => _showYoutubePlayer(context, url),
                    icon: const Icon(Icons.play_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No lectures')),
          ),
      ],
    );
  }
}

class _YoutubePlayerPage extends StatelessWidget {
  const _YoutubePlayerPage({required this.controller});
  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Lecture'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Center(child: player),
          ),
        );
      },
    );
  }
}

class _AnnouncementPanel extends StatefulWidget {
  const _AnnouncementPanel({
    required this.loading,
    required this.classOptions,
    required this.streamsForClass,
    required this.items,
    required this.onCreate,
    required this.onDelete,
  });

  final bool loading;
  final List<String> classOptions;
  final List<String> Function(String klass) streamsForClass;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> payload) onCreate;
  final Future<void> Function(String id) onDelete;

  @override
  State<_AnnouncementPanel> createState() => _AnnouncementPanelState();
}

class _AnnouncementPanelState extends State<_AnnouncementPanel> {
  final _textCtrl = TextEditingController();
  String _klass = '';
  String _section = '';

  String _filterClass = '';
  String _filterStream = '';
  final _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streams = _klass.isEmpty ? const <String>[] : widget.streamsForClass(_klass);

    final classOptions = <String>{};
    final streamOptions = <String>{};
    for (final x in widget.items) {
      final c = (x['class'] ?? '').toString().trim();
      final s = (x['section'] ?? x['stream'] ?? '').toString().trim();
      if (c.isNotEmpty) classOptions.add(c);
      if (s.isNotEmpty) streamOptions.add(s);
    }
    final classes = classOptions.toList()..sort();
    final streamList = streamOptions.toList()..sort();

    final q = _filterCtrl.text.trim().toLowerCase();
    final filteredItems = widget.items.where((x) {
      final c = (x['class'] ?? '').toString();
      final s = (x['section'] ?? x['stream'] ?? '').toString();
      final text = (x['text'] ?? '').toString().toLowerCase();
      if (_filterClass.isNotEmpty && c != _filterClass) return false;
      if (_filterStream.isNotEmpty && s != _filterStream) return false;
      if (q.isNotEmpty && !text.contains(q)) return false;
      return true;
    }).toList();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Announcement', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _klass.isEmpty ? null : _klass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: widget.loading
                      ? null
                      : (v) {
                          setState(() {
                            _klass = v ?? '';
                            _section = '';
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _section.isEmpty ? null : _section,
                  decoration: const InputDecoration(labelText: 'Stream'),
                  items: streams.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.loading ? null : (v) => setState(() => _section = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Announcement'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.loading
                      ? null
                      : () async {
                          await widget.onCreate({
                            'class': _klass,
                            'section': _section,
                            'text': _textCtrl.text.trim(),
                          });
                          _textCtrl.clear();
                        },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterClass.isEmpty ? null : _filterClass,
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStream.isEmpty ? null : _filterStream,
                        decoration: const InputDecoration(labelText: 'Stream'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...streamList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _filterCtrl,
                  decoration: const InputDecoration(labelText: 'Keyword'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...filteredItems.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final title = 'Class ${x['class'] ?? ''} • ${x['section'] ?? ''}';
          final text = (x['text'] ?? '').toString();
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text(text),
              trailing: IconButton(
                onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
        if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No announcements')),
          ),
      ],
    );
  }
}

class _SessionsPanel extends StatefulWidget {
  const _SessionsPanel({
    required this.loading,
    required this.items,
    required this.onCreate,
    required this.onDelete,
  });

  final bool loading;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(String id) onDelete;

  @override
  State<_SessionsPanel> createState() => _SessionsPanelState();
}

class _SessionsPanelState extends State<_SessionsPanel> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Session', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Session (e.g. 2025-26)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.loading
                      ? null
                      : () async {
                          final v = _nameCtrl.text.trim();
                          if (v.isEmpty) return;
                          await widget.onCreate(v);
                          _nameCtrl.clear();
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.items.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final name = (x['name'] ?? '').toString();
          return Card(
            child: ListTile(
              title: Text(name.isEmpty ? id : name),
              trailing: IconButton(
                onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
        if (widget.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No sessions')),
          ),
      ],
    );
  }
}

class _ClassesPanel extends StatefulWidget {
  const _ClassesPanel({
    required this.loading,
    required this.currentSession,
    required this.items,
    required this.onCreate,
    required this.onDelete,
  });

  final bool loading;
  final String currentSession;
  final List<Map<String, dynamic>> items;
  final Future<void> Function({required String klass, required String stream}) onCreate;
  final Future<void> Function(String id) onDelete;

  @override
  State<_ClassesPanel> createState() => _ClassesPanelState();
}

class _ClassesPanelState extends State<_ClassesPanel> {
  final _classCtrl = TextEditingController();
  final _streamCtrl = TextEditingController();

  @override
  void dispose() {
    _classCtrl.dispose();
    _streamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.currentSession.trim();
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Class', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Current session: ${session.isEmpty ? '(not selected)' : session}'),
                const SizedBox(height: 12),
                TextField(
                  controller: _classCtrl,
                  decoration: const InputDecoration(labelText: 'Class'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _streamCtrl,
                  decoration: const InputDecoration(labelText: 'Stream'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.loading || session.isEmpty
                      ? null
                      : () async {
                          final c = _classCtrl.text.trim();
                          final s = _streamCtrl.text.trim();
                          if (c.isEmpty || s.isEmpty) return;
                          await widget.onCreate(klass: c, stream: s);
                          _classCtrl.clear();
                          _streamCtrl.clear();
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.items.map((x) {
          final id = (x['id'] ?? x['_id'] ?? '').toString();
          final klass = (x['class'] ?? '').toString();
          final stream = (x['stream'] ?? '').toString();
          return Card(
            child: ListTile(
              title: Text('Class $klass • $stream'),
              trailing: IconButton(
                onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
        if (widget.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No classes')),
          ),
      ],
    );
  }
}

class _StudentsPanel extends StatefulWidget {
  const _StudentsPanel({
    required this.loading,
    required this.items,
    required this.onPatch,
    required this.onDelete,
  });

  final bool loading;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String id, Map<String, dynamic> payload) onPatch;
  final Future<void> Function(String id) onDelete;

  @override
  State<_StudentsPanel> createState() => _StudentsPanelState();
}

class _StudentsPanelState extends State<_StudentsPanel> {
  static const _statuses = ['active', 'inactive', 'left'];

  String _filterClass = '';
  String _filterStream = '';

  ImageProvider? _photoProvider(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final bytes = s.startsWith('data:')
          ? UriData.parse(s).contentAsBytes()
          : (s.contains('base64,') ? base64Decode(s.split('base64,').last) : base64Decode(s));
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Iterable<Map<String, dynamic>> _filteredItems() {
    return widget.items.where((x) {
      final klass = (x['class'] ?? '').toString();
      final stream = (x['stream'] ?? '').toString();
      if (_filterClass.isNotEmpty && klass != _filterClass) return false;
      if (_filterStream.isNotEmpty && stream != _filterStream) return false;
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No students')),
          ),
        ],
      );
    }

    final classOptions = <String>{};
    final streamOptions = <String>{};
    for (final x in widget.items) {
      final klass = (x['class'] ?? '').toString().trim();
      final stream = (x['stream'] ?? '').toString().trim();
      if (klass.isNotEmpty) classOptions.add(klass);
      if (stream.isNotEmpty) streamOptions.add(stream);
    }
    final classes = classOptions.toList()..sort();
    final streams = streamOptions.toList()..sort();

    final filtered = _filteredItems().toList();

    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900);
    final rowTextStyle = Theme.of(context).textTheme.bodyMedium;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterClass.isEmpty ? null : _filterClass,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: widget.loading ? null : (v) => setState(() => _filterClass = (v ?? '')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStream.isEmpty ? null : _filterStream,
                    decoration: const InputDecoration(labelText: 'Stream'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...streams.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: widget.loading ? null : (v) => setState(() => _filterStream = (v ?? '')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text('No students')),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: headerStyle,
              dataTextStyle: rowTextStyle,
              columns: const [
                DataColumn(label: Text('STUDENT-ID')),
                DataColumn(label: Text('JOINING DATE')),
                DataColumn(label: Text('PHOTO')),
                DataColumn(label: Text('NAME')),
                DataColumn(label: Text('CLASS')),
                DataColumn(label: Text('STREAM')),
                DataColumn(label: Text('NUMBER')),
                DataColumn(label: Text('ADDRESS')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: filtered.map((x) {
            final id = (x['id'] ?? x['_id'] ?? '').toString();
            final studentId = (x['studentId'] ?? '').toString();
            final joiningDateRaw = (x['joiningDate'] ?? x['createdAt'] ?? '').toString();
            final joiningDate = joiningDateRaw.length >= 10 ? joiningDateRaw.substring(0, 10) : joiningDateRaw;
            final photoBase64 = (x['photoBase64'] ?? '').toString();
            final name = (x['name'] ?? '').toString();
            final klass = (x['class'] ?? '').toString();
            final stream = (x['stream'] ?? '').toString();
            final number = (x['number'] ?? '').toString();
            final address = (x['address'] ?? '').toString();
            final status = (x['status'] ?? '').toString().trim().toLowerCase();

            final photo = _photoProvider(photoBase64);
            final statusValue = _statuses.contains(status) ? status : (_statuses.contains('active') ? 'active' : null);

            return DataRow(
              cells: [
                DataCell(Text(studentId.isEmpty ? '—' : studentId)),
                DataCell(Text(joiningDate.isEmpty ? '—' : joiningDate)),
                DataCell(
                  photo == null
                      ? const Text('—')
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: photo,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                DataCell(Text(name.isEmpty ? '—' : name)),
                DataCell(Text(klass.isEmpty ? '—' : klass)),
                DataCell(Text(stream.isEmpty ? '—' : stream)),
                DataCell(Text(number.isEmpty ? '—' : number)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(address.isEmpty ? '—' : address, overflow: TextOverflow.ellipsis, maxLines: 2),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: statusValue,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: widget.loading || id.isEmpty
                          ? null
                          : (v) {
                              if (v == null) return;
                              widget.onPatch(id, {'status': v});
                            },
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.loading || id.isEmpty ? null : () => widget.onDelete(id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
