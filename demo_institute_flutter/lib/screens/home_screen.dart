import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../routes.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../models/announcement.dart';
import '../models/lecture_item.dart';
import '../models/material_item.dart';
import '../models/timetable_item.dart';
import '../services/demo_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = DemoApi();

  final _scrollController = ScrollController();
  final _materialsKey = GlobalKey();
  bool _handledInitialNavIntent = false;

  static const int _programsSlideCount = 3;

  static const String _leadPrefsKey = 'demo_institute_lead_state';
  Timer? _leadTimer;

  late final PageController _programsController;
  int _programsIndex = 0;
  Timer? _programsTimer;

  String? _annClass;
  String? _annSection;
  bool _annLoading = false;
  String? _annError;
  List<Announcement> _annItems = const [];
  List<String> _annClasses = const [];
  List<String> _annSections = const [];

  String? _ttClass;
  String? _ttSection;
  bool _ttLoading = false;
  String? _ttError;
  List<TimetableItem> _ttItems = const [];
  List<String> _ttClasses = const [];
  List<String> _ttSections = const [];

  String _materialsCategory = 'chaptersolutions';
  String _materialsClass = '10';
  bool _materialsLoading = false;
  String? _materialsError;
  List<MaterialItem> _materials = const [];

  String _lecturesClass = '10';
  bool _lecturesLoading = false;
  String? _lecturesError;
  List<LectureItem> _lectures = const [];

  @override
  void initState() {
    super.initState();
    _programsController = PageController();
    _programsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_programsController.hasClients) return;
      final next = (_programsIndex + 1) % _programsSlideCount;
      _programsController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
    _loadAnnouncements();
    _loadTimetables();
    _loadMaterials();
    _loadLectures();

    _leadTimer = Timer(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      _maybeAutoShowLeadDialog();
    });
  }

  @override
  void dispose() {
    _programsTimer?.cancel();
    _leadTimer?.cancel();
    _programsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialNavIntent) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final intent = args['intent'];
      if (intent == 'scrollToMaterials') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMaterials());
        _handledInitialNavIntent = true;
      } else if (intent == 'openLeadDialog') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showLeadDialog());
        _handledInitialNavIntent = true;
      } else if (intent == 'openAdmissionDialog') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showAdmissionDialog());
        _handledInitialNavIntent = true;
      }
    }
  }

  Future<void> _openTimetable(TimetableItem it) async {
    final title = it.title.trim().isNotEmpty ? it.title.trim() : 'Time-table';

    String url = '';
    if (it.fileId.isNotEmpty) {
      url = 'https://drive.google.com/uc?export=download&id=${Uri.encodeComponent(it.fileId)}';
    } else {
      url = it.bestLink;
    }

    if (url.trim().isEmpty) return;

    try {
      await _openPdfInApp(title: title, url: url);
    } catch (_) {
      await _openLink(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'DEMO INSTITUTE',
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadAnnouncements(),
            _loadTimetables(),
            _loadMaterials(),
            _loadLectures(),
          ]);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _HeroCard(
              onPrimaryCta: _showLeadDialog,
            ),
            const SizedBox(height: 16),
            const _MetricsRow(),
            const SizedBox(height: 18),
            _ProgramsSection(
              controller: _programsController,
              index: _programsIndex,
              onIndexChanged: (i) => setState(() => _programsIndex = i),
              onSlideTap: (slide) {
                Navigator.of(context).pushNamed(
                  AppRoutes.studentDashboard,
                  arguments: {
                    'programTitle': slide.title,
                    'class': slide.defaultClass,
                  },
                );
              },
            ),
            const SizedBox(height: 18),
            _AnnouncementsAndTimetableSection(
              annLoading: _annLoading,
              annError: _annError,
              annItems: _annItems,
              annClass: _annClass,
              annSection: _annSection,
              annClasses: _annClasses,
              annSections: _annSections,
              onAnnClassChanged: (v) {
                setState(() => _annClass = v);
                _loadAnnouncements();
              },
              onAnnSectionChanged: (v) {
                setState(() => _annSection = v);
                _loadAnnouncements();
              },
              ttLoading: _ttLoading,
              ttError: _ttError,
              ttItems: _ttItems,
              ttClass: _ttClass,
              ttSection: _ttSection,
              ttClasses: _ttClasses,
              ttSections: _ttSections,
              onTtClassChanged: (v) {
                setState(() => _ttClass = v);
                _loadTimetables();
              },
              onTtSectionChanged: (v) {
                setState(() => _ttSection = v);
                _loadTimetables();
              },
              onTtRefresh: _loadTimetables,
              onOpenTimetable: _openTimetable,
            ),
            const SizedBox(height: 18),
            const _TutoringSection(),
            const SizedBox(height: 18),
            KeyedSubtree(
              key: _materialsKey,
              child: _MaterialsSection(
                category: _materialsCategory,
                klass: _materialsClass,
                loading: _materialsLoading,
                error: _materialsError,
                items: _materials,
                onCategoryChanged: (c) {
                  setState(() => _materialsCategory = c);
                  _loadMaterials();
                },
                onClassChanged: (c) {
                  setState(() => _materialsClass = c);
                  _loadMaterials();
                },
                onOpen: _openMaterial,
              ),
            ),
            const SizedBox(height: 18),
            _LecturesSection(
              klass: _lecturesClass,
              loading: _lecturesLoading,
              error: _lecturesError,
              items: _lectures,
              onClassChanged: (c) {
                setState(() => _lecturesClass = c);
                _loadLectures();
              },
              onPlay: _openLecture,
            ),
            const SizedBox(height: 18),
            const _StudentHighlightsSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(String link) async {
    final s = link.trim();
    if (s.isEmpty) return;
    final uri = Uri.tryParse(s);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openLecture(String youtubeUrl) async {
    final url = youtubeUrl.trim();
    if (url.isEmpty) return;
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null || videoId.isEmpty) {
      await _openLink(url);
      return;
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _YoutubePlayerPage(controller: controller),
      ),
    );

    controller.dispose();
  }

  Future<void> _openPdfInApp({required String title, required String url}) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PdfViewerPage(title: title, url: uri.toString()),
      ),
    );
  }

  Future<void> _openMaterial(MaterialItem it) async {
    final title = it.title.isNotEmpty ? it.title : (it.subject.isNotEmpty ? it.subject : 'Material');

    String url = '';
    if (it.fileId.isNotEmpty) {
      url = 'https://drive.google.com/uc?export=download&id=${Uri.encodeComponent(it.fileId)}';
    } else {
      url = it.bestLink;
    }

    if (url.trim().isEmpty) return;

    try {
      await _openPdfInApp(title: title, url: url);
    } catch (_) {
      await _openLink(url);
    }
  }

  Future<void> _scrollToMaterials() async {
    final ctx = _materialsKey.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  static List<String> _uniqSorted(Iterable<String> values) {
    final set = <String>{};
    for (final v in values) {
      final s = v.trim();
      if (s.isEmpty) continue;
      set.add(s);
    }
    final out = set.toList();
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _annLoading = true;
      _annError = null;
    });
    try {
      final items = await _api.getAnnouncements(
        klass: _annClass,
        section: _annSection,
      );
      final classes = _uniqSorted(items.map((x) => x.klass));
      final sections = _uniqSorted(items.map((x) => x.section));
      if (!mounted) return;
      setState(() {
        _annItems = items;
        if (_annClasses.isEmpty) _annClasses = classes;
        if (_annSections.isEmpty) _annSections = sections;
        _annLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _annError = e.toString();
        _annItems = const [];
        _annLoading = false;
      });
    }
  }

  Future<void> _loadTimetables() async {
    setState(() {
      _ttLoading = true;
      _ttError = null;
    });
    try {
      final items = await _api.getTimetables(
        klass: _ttClass,
        section: _ttSection,
      );
      final classes = _uniqSorted(items.map((x) => x.klass));
      final sections = _uniqSorted(items.map((x) => x.section));
      if (!mounted) return;
      setState(() {
        _ttItems = items;
        if (_ttClasses.isEmpty) _ttClasses = classes;
        if (_ttSections.isEmpty) _ttSections = sections;
        _ttLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ttError = e.toString();
        _ttItems = const [];
        _ttLoading = false;
      });
    }
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _materialsLoading = true;
      _materialsError = null;
    });
    try {
      final items = await _api.getMaterials(
        category: _materialsCategory,
        klass: _materialsClass,
      );
      if (!mounted) return;
      setState(() {
        _materials = items;
        _materialsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _materialsError = e.toString();
        _materials = const [];
        _materialsLoading = false;
      });
    }
  }

  Future<void> _loadLectures() async {
    setState(() {
      _lecturesLoading = true;
      _lecturesError = null;
    });
    try {
      final items = await _api.getLectures(klass: _lecturesClass);
      if (!mounted) return;
      setState(() {
        _lectures = items;
        _lecturesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lecturesError = e.toString();
        _lectures = const [];
        _lecturesLoading = false;
      });
    }
  }

  Future<void> _maybeAutoShowLeadDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final state = (prefs.getString(_leadPrefsKey) ?? '').trim().toLowerCase();
    if (state == 'dismissed' || state == 'submitted') return;
    await _showLeadDialog();
  }

  Future<void> _setLeadState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_leadPrefsKey, state);
  }

  Future<void> _showLeadDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _LeadDialog(
          onDismissed: () => _setLeadState('dismissed'),
          onSubmitted: () => _setLeadState('submitted'),
          submit: ({required name, required phone}) => _api.submitLead(name: name, phone: phone),
        );
      },
    );
  }

  Future<void> _showAdmissionDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _AdmissionDialog(
          api: _api,
        );
      },
    );
  }
}

class _AdmissionDialog extends StatefulWidget {
  const _AdmissionDialog({required this.api});

  final DemoApi api;

  @override
  State<_AdmissionDialog> createState() => _AdmissionDialogState();
}

class _AdmissionDialogState extends State<_AdmissionDialog> {
  final _formKey = GlobalKey<FormState>();

  final _studentName = TextEditingController();
  final _studentPhone = TextEditingController();
  final _address = TextEditingController();
  final _guardianName = TextEditingController();
  final _relation = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _courses = TextEditingController();
  final _notes = TextEditingController();

  String _gender = '';
  String _classGrade = '';
  String _stream = '';

  bool _loadingOptions = false;
  List<String> _classes = const [];
  Map<String, List<String>> _streamsByClass = const {};

  bool _submitting = false;
  String? _note;

  String _photoBase64 = '';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _studentName.dispose();
    _studentPhone.dispose();
    _address.dispose();
    _guardianName.dispose();
    _relation.dispose();
    _guardianPhone.dispose();
    _courses.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _note = null;
    });
    try {
      final data = await widget.api.getAdmissionOptions();
      final classes = (data['classes'] is List)
          ? (data['classes'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : <String>[];
      final sbc = <String, List<String>>{};
      final raw = data['streamsByClass'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is List) {
            sbc[key] = val.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _streamsByClass = sbc;
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _note = 'Failed to load options.';
      });
    }
  }

  List<String> _streamsForSelectedClass() {
    final v = _classGrade.trim();
    return _streamsByClass[v] ?? const [];
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      if (!mounted) return;
      setState(() {
        _photoBase64 = 'data:image/jpeg;base64,$b64';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _note = 'Failed to pick photo.';
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _submitting = true;
      _note = 'Submitting...';
    });

    try {
      final data = <String, dynamic>{
        'studentName': _studentName.text.trim(),
        'gender': _gender,
        'studentPhone': _studentPhone.text.trim(),
        'classGrade': _classGrade,
        'stream': _stream,
        'address': _address.text.trim(),
        'guardianName': _guardianName.text.trim(),
        'relation': _relation.text.trim(),
        'guardianPhone': _guardianPhone.text.trim(),
        'courses': _courses.text.trim(),
        'notes': _notes.text.trim(),
      };

      await widget.api.submitAdmission(data: data, photoBase64: _photoBase64);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _note = 'Submission failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admission Form'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingOptions) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _studentName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Student Full Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _gender.isEmpty ? null : _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() => _gender = v ?? '');
                        },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _studentPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Student Contact Number'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _classGrade.isEmpty ? null : _classGrade,
                  decoration: const InputDecoration(labelText: 'Class / Grade'),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() {
                            _classGrade = v ?? '';
                            _stream = '';
                          });
                        },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _stream.isEmpty ? null : _stream,
                  decoration: const InputDecoration(labelText: 'Stream'),
                  items: _streamsForSelectedClass().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() => _stream = v ?? '');
                        },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _address,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _guardianName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Guardian Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _relation,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Relation'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _guardianPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Guardian Contact Number'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _courses,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Course / Subjects Applied For'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Special Notes / Requirements'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _pickPhoto,
                        child: Text(_photoBase64.isEmpty ? 'Choose Photo' : 'Photo Selected'),
                      ),
                    ),
                  ],
                ),
                if (_note != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _note!,
                    style: TextStyle(
                      color: _submitting ? Colors.white.withValues(alpha: 0.8) : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _ProgramsSection extends StatelessWidget {
  const _ProgramsSection({
    required this.controller,
    required this.index,
    required this.onIndexChanged,
    required this.onSlideTap,
  });

  final PageController controller;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<_ProgramSlide> onSlideTap;

  @override
  Widget build(BuildContext context) {
    final slides = <_ProgramSlide>[
      const _ProgramSlide(
        asset: 'assets/carousel/c1.png',
        title: 'Foundation (Class 5–8)',
        subtitle: 'Strong basics • Regular worksheets • Weekly tests',
        defaultClass: '8',
      ),
      const _ProgramSlide(
        asset: 'assets/carousel/c2.png',
        title: 'Boards (Class 9–10)',
        subtitle: 'Concept clarity • Answer writing • Mock exams',
        defaultClass: '10',
      ),
      const _ProgramSlide(
        asset: 'assets/carousel/c24.png',
        title: 'Class 11–12',
        subtitle: 'PCM / PCB / Commerce • Doubt support • Strategy',
        defaultClass: '12',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Programs',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Focused batches, concept clarity, and regular assessment.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: controller,
            itemCount: slides.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, i) {
              final it = slides[i];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSlideTap(it),
                  child: _Card(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(it.asset, fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  it.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Open dashboard ›',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final selected = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: selected ? 22 : 8,
              decoration: BoxDecoration(
                color: selected ? AppTheme.brandPrimary : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ProgramSlide {
  const _ProgramSlide({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.defaultClass,
  });

  final String asset;
  final String title;
  final String subtitle;
  final String defaultClass;
}

class _AnnouncementsAndTimetableSection extends StatelessWidget {
  const _AnnouncementsAndTimetableSection({
    required this.annLoading,
    required this.annError,
    required this.annItems,
    required this.annClass,
    required this.annSection,
    required this.annClasses,
    required this.annSections,
    required this.onAnnClassChanged,
    required this.onAnnSectionChanged,
    required this.ttLoading,
    required this.ttError,
    required this.ttItems,
    required this.ttClass,
    required this.ttSection,
    required this.ttClasses,
    required this.ttSections,
    required this.onTtClassChanged,
    required this.onTtSectionChanged,
    required this.onTtRefresh,
    required this.onOpenTimetable,
  });

  final bool annLoading;
  final String? annError;
  final List<Announcement> annItems;
  final String? annClass;
  final String? annSection;
  final List<String> annClasses;
  final List<String> annSections;
  final ValueChanged<String?> onAnnClassChanged;
  final ValueChanged<String?> onAnnSectionChanged;

  final bool ttLoading;
  final String? ttError;
  final List<TimetableItem> ttItems;
  final String? ttClass;
  final String? ttSection;
  final List<String> ttClasses;
  final List<String> ttSections;
  final ValueChanged<String?> onTtClassChanged;
  final ValueChanged<String?> onTtSectionChanged;
  final Future<void> Function() onTtRefresh;
  final Future<void> Function(TimetableItem item) onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Announcements & Time-table',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Latest updates, notices, and class schedules in one place.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Dropdown(
                      label: 'Class',
                      value: annClass,
                      includeAll: true,
                      items: annClasses,
                      onChanged: onAnnClassChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Dropdown(
                      label: 'Section',
                      value: annSection,
                      includeAll: true,
                      items: annSections,
                      onChanged: onAnnSectionChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (annLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!annLoading && annError != null)
                Text(
                  'Failed to load announcements.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!annLoading && annError == null && annItems.isEmpty) const Text('No announcements yet.'),
              if (!annLoading && annItems.isNotEmpty)
                _AutoScrollAnnouncements(
                  items: annItems,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Time-table',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: ttLoading ? null : onTtRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _Dropdown(
                      label: 'Class',
                      value: ttClass,
                      includeAll: false,
                      items: ttClasses,
                      onChanged: onTtClassChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Dropdown(
                      label: 'Section',
                      value: ttSection,
                      includeAll: false,
                      items: ttSections,
                      onChanged: onTtSectionChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (ttLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!ttLoading && ttError != null)
                Text(
                  'Failed to load time-table.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!ttLoading && ttError == null && ttItems.isEmpty) const Text('No time-table uploaded yet.'),
              if (!ttLoading && ttItems.isNotEmpty)
                Column(
                  children: ttItems
                      .take(8)
                      .map(
                        (it) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('Class ${it.klass}${it.section.isNotEmpty ? ' • ${it.section}' : ''}'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: (it.fileId.isEmpty && it.bestLink.isEmpty) ? null : () => onOpenTimetable(it),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoScrollAnnouncements extends StatefulWidget {
  const _AutoScrollAnnouncements({required this.items});

  final List<Announcement> items;

  @override
  State<_AutoScrollAnnouncements> createState() => _AutoScrollAnnouncementsState();
}

class _AutoScrollAnnouncementsState extends State<_AutoScrollAnnouncements> {
  late final ScrollController _controller;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollAnnouncements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.hasClients) _controller.jumpTo(0);
      });
    }
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;

    const frame = Duration(milliseconds: 16);
    const step = 0.65;

    while (mounted && _running) {
      if (!_controller.hasClients) {
        await Future<void>.delayed(frame);
        continue;
      }

      final pos = _controller.position;
      if (pos.maxScrollExtent <= 0) {
        await Future<void>.delayed(frame);
        continue;
      }

      final half = pos.maxScrollExtent / 2;
      if (_controller.offset >= half) {
        _controller.jumpTo(_controller.offset - half);
      }

      final target = (_controller.offset + step).clamp(0.0, pos.maxScrollExtent);
      await _controller.animateTo(
        target,
        duration: frame,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.items.take(10).toList();
    if (base.isEmpty) return const SizedBox.shrink();

    final infinite = (base.length <= 1) ? base : [...base, ...base];

    return SizedBox(
      height: 230,
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.only(top: 6),
        itemCount: infinite.length,
        itemBuilder: (context, i) {
          final it = infinite[i % infinite.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NoticeTile(
              title: 'Class ${it.klass}${it.section.isNotEmpty ? ' • ${it.section}' : ''}',
              body: it.text,
            ),
          );
        },
      ),
    );
  }
}

class _TutoringSection extends StatelessWidget {
  const _TutoringSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'One-to-One Tutoring',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 178,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _TutoringCard(
                emoji: '🧾',
                title: 'Boards made simpler',
                body: 'Focused lessons, better answers, higher scores.',
              ),
              _TutoringCard(
                emoji: '🎯',
                title: 'Excel in Science',
                body: 'Strong concepts, numericals, exam confidence.',
              ),
              _TutoringCard(
                emoji: '🎓',
                title: 'Master Commerce',
                body: 'Concepts, numericals, and exam writing.',
              ),
              _TutoringCard(
                emoji: '💻',
                title: 'Java & Python',
                body: 'Basics to projects with real examples.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutoringCard extends StatelessWidget {
  const _TutoringCard({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78))),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Find personal tutor ›',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialsSection extends StatelessWidget {
  const _MaterialsSection({
    required this.category,
    required this.klass,
    required this.loading,
    required this.error,
    required this.items,
    required this.onCategoryChanged,
    required this.onClassChanged,
    required this.onOpen,
  });

  final String category;
  final String klass;
  final bool loading;
  final String? error;
  final List<MaterialItem> items;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onClassChanged;
  final Future<void> Function(MaterialItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final classes = ['12', '11', '10', '9', '8', '7', '6', '5'];
    final categories = <({String key, String label})>[
      (key: 'materials', label: 'Revision Notes'),
      (key: 'yearspapers', label: "Year's Papers"),
      (key: 'chaptersolutions', label: 'Chapters Solution'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study materials & resources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = classes[i];
              final selected = c == klass;
              return ChoiceChip(
                selected: selected,
                label: Text('Class $c'),
                onSelected: (_) => onClassChanged(c),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = categories[i];
              final selected = c.key == category;
              return ChoiceChip(
                selected: selected,
                label: Text(c.label),
                onSelected: (_) => onCategoryChanged(c.key),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!loading && error != null)
          Text('Failed to load materials.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!loading && error == null && items.isEmpty) const Text('No notes yet.'),
        if (!loading && items.isNotEmpty)
          SizedBox(
            height: 162,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length.clamp(0, 12),
              itemBuilder: (context, i) {
                final it = items[i];
                final title = it.title.isNotEmpty ? it.title : (it.subject.isNotEmpty ? it.subject : 'Material');
                final subtitle = it.chapter.isNotEmpty
                    ? it.chapter
                    : it.year.isNotEmpty
                        ? it.year
                        : 'Tap to open';
                final thumb = it.fileId.isNotEmpty
                    ? 'https://drive.google.com/thumbnail?id=${Uri.encodeComponent(it.fileId)}&sz=w320'
                    : 'assets/notes/note1.png';
                return SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: (it.fileId.isEmpty && it.bestLink.isEmpty) ? null : () => onOpen(it),
                      child: _Card(
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _AnyImage(
                                urlOrAsset: thumb,
                                width: 82,
                                height: 120,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LecturesSection extends StatelessWidget {
  const _LecturesSection({
    required this.klass,
    required this.loading,
    required this.error,
    required this.items,
    required this.onClassChanged,
    required this.onPlay,
  });

  final String klass;
  final bool loading;
  final String? error;
  final List<LectureItem> items;
  final ValueChanged<String> onClassChanged;
  final Future<void> Function(String youtubeUrl) onPlay;

  @override
  Widget build(BuildContext context) {
    final classes = ['12', '11', '10', '9', '8', '7', '6', '5'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recorded Lectures',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = classes[i];
              final selected = c == klass;
              return ChoiceChip(
                selected: selected,
                label: Text('Class $c'),
                onSelected: (_) => onClassChanged(c),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!loading && error != null)
          Text('Failed to load lectures.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!loading && error == null && items.isEmpty) const Text('No lectures yet.'),
        if (!loading && items.isNotEmpty)
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length.clamp(0, 12),
              itemBuilder: (context, i) {
                final it = items[i];
                final vid = it.youtubeUrl.isEmpty ? null : YoutubePlayer.convertUrlToId(it.youtubeUrl);
                final thumbUrl = (vid == null || vid.isEmpty) ? '' : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
                return SizedBox(
                  width: 260,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: it.youtubeUrl.isEmpty ? null : () => onPlay(it.youtubeUrl),
                      child: _Card(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 96,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (thumbUrl.isNotEmpty)
                                      Image.network(
                                        thumbUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            color: const Color(0xFFDBEAFE),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.play_arrow, color: Color(0xFF1D4ED8)),
                                          );
                                        },
                                      )
                                    else
                                      Container(
                                        color: const Color(0xFFDBEAFE),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.play_arrow, color: Color(0xFF1D4ED8)),
                                      ),
                                    Container(color: Colors.black.withOpacity(0.18)),
                                    const Center(
                                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                it.subject.isNotEmpty ? it.subject : 'Lecture',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Class ${it.klass}${it.section.isNotEmpty ? ' • ${it.section}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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

class _PdfViewerPage extends StatelessWidget {
  const _PdfViewerPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SfPdfViewer.network(url),
    );
  }
}

class _StudentHighlightsSection extends StatefulWidget {
  const _StudentHighlightsSection();

  @override
  State<_StudentHighlightsSection> createState() => _StudentHighlightsSectionState();
}

class _StudentHighlightsSectionState extends State<_StudentHighlightsSection> {
  late final ScrollController _controller;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    if (_running) return;
    _running = true;
    _tick();
  }

  Future<void> _tick() async {
    const step = 0.6;
    const frame = Duration(milliseconds: 16);

    while (mounted && _running) {
      if (!_controller.hasClients) {
        await Future<void>.delayed(frame);
        continue;
      }

      final pos = _controller.position;
      if (pos.maxScrollExtent <= 0) {
        await Future<void>.delayed(frame);
        continue;
      }

      final half = pos.maxScrollExtent / 2;
      if (pos.pixels >= half) {
        _controller.jumpTo(pos.pixels - half);
      }

      final target = (_controller.offset + step).clamp(0.0, pos.maxScrollExtent);
      await _controller.animateTo(
        target,
        duration: frame,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <({String asset, String name, String pill, String role, String inst})>[
      (asset: 'assets/STUDENTS/akshat.jpg', name: 'Akshat', pill: 'ICSE • 96%', role: 'Class 10 Board Result', inst: 'Maths • Science'),
      (asset: 'assets/STUDENTS/arya.jpg', name: 'Arya', pill: 'ISC • 94%', role: 'Class 12 Board Result', inst: 'Science Stream'),
      (asset: 'assets/STUDENTS/chandvI.jpg', name: 'Chandvi', pill: 'CBSE • 95%', role: 'Class 10 Board Result', inst: 'English • SST'),
      (asset: 'assets/STUDENTS/ritika.jpg', name: 'Ritika', pill: 'ISC • 93%', role: 'Class 12 Board Result', inst: 'Commerce Stream'),
      (asset: 'assets/STUDENTS/senin.jpg', name: 'Senin', pill: 'CBSE • 92%', role: 'Class 12 Board Result', inst: 'Computer Science'),
    ];

    final infinite = List.generate(items.length * 20, (i) => items[i % items.length]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student highlights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: infinite.length,
            itemBuilder: (context, i) {
              final it = infinite[i];
              return SizedBox(
                width: 260,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: Image.asset(
                            it.asset,
                            height: 96,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    it.pill,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  it.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  it.inst,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.includeAll,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final dropdownItems = <DropdownMenuItem<String?>>[];
    dropdownItems.add(
      DropdownMenuItem<String?>(
        value: null,
        child: Text(includeAll ? 'All' : 'Select'),
      ),
    );
    dropdownItems.addAll(
      items.map(
        (x) => DropdownMenuItem<String?>(
          value: x,
          child: Text(x),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          value: value,
          items: dropdownItems,
          onChanged: onChanged,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surface2,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}

class _AnyImage extends StatelessWidget {
  const _AnyImage({
    required this.urlOrAsset,
    required this.width,
    required this.height,
  });

  final String urlOrAsset;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final src = urlOrAsset.trim();
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/notes/note1.png',
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      src,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onPrimaryCta});

  final VoidCallback onPrimaryCta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.brandPrimary.withValues(alpha: 0.14),
            cs.surface,
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admissions Open 2026–27',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Limited Seats • Free Counselling',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Trusted coaching for Classes 5–12 & competitive exams.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'We focus on concept clarity, disciplined practice, and personal mentoring—so students learn faster, score better, and stay confident.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                'assets/exam-girl.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.25),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Free Demo Classes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppTheme.brandPrimary.withValues(alpha: 0.35)),
                  ),
                  child: const Text('View Courses'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeadDialog extends StatefulWidget {
  const _LeadDialog({
    required this.submit,
    required this.onDismissed,
    required this.onSubmitted,
  });

  final Future<void> Function({required String name, required String phone}) submit;
  final VoidCallback onDismissed;
  final VoidCallback onSubmitted;

  @override
  State<_LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<_LeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  String? _note;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '☎',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get a call back',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Leave your details and we will contact you shortly.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(context, 'Free counselling'),
                _badge(context, 'Fast response'),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Your full name',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Enter your name';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '10-digit number',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Enter phone number';
                if (s.length < 8) return 'Enter a valid phone number';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_note != null) ...[
              const SizedBox(height: 10),
              Text(
                _note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _note!.toLowerCase().startsWith('submitted')
                          ? AppTheme.brandPrimary
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  widget.onDismissed();
                  Navigator.of(context).pop();
                },
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.brandPrimary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _note = 'Submitting…';
    });
    try {
      final name = _name.text;
      final phone = _phone.text;

      await widget.submit(name: name, phone: phone);

      // Best-effort: do NOT block the UI on the Botclap webhook.
      unawaited(() async {
        try {
          await DemoApi().submitBotclapLead(name: name.trim(), phone: phone.trim());
          if (kDebugMode) debugPrint('Lead: Botclap webhook OK');
        } catch (e) {
          if (kDebugMode) debugPrint('Lead: Botclap webhook FAILED: $e');
        }
      }());

      widget.onSubmitted();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('Lead: /leads submit FAILED: $e');
      setState(() {
        _loading = false;
        _note = kDebugMode ? 'Failed to submit. (debug) $e' : 'Failed to submit. Please try again.';
      });
    }
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MetricCard(
            value: '10+',
            label: 'Years of\nExperience',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: '1200+',
            label: 'Students\nTaught',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: '95%',
            label: 'Parents\nRecommend',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brandPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  height: 1.15,
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PopularCoursesGrid extends StatelessWidget {
  const _PopularCoursesGrid();

  @override
  Widget build(BuildContext context) {
    final items = <({String emoji, String title, String subtitle})>[
      (emoji: '🧮', title: 'Foundation', subtitle: 'Class 5–8'),
      (emoji: '📘', title: 'Boards', subtitle: 'Class 9–10'),
      (emoji: '🧪', title: '11–12', subtitle: 'PCM/PCB/Commerce'),
      (emoji: '🏆', title: 'Competitive', subtitle: 'Mocks + Strategy'),
      (emoji: '🗣️', title: 'Spoken English', subtitle: 'Confidence'),
      (emoji: '👤', title: 'One-to-One', subtitle: 'Personal'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).cardTheme.color,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.brandPrimary.withValues(alpha: 0.10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
