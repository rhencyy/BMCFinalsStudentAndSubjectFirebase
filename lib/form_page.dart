import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const kIndigo = Color(0xFF4F46E5);
const kViolet = Color(0xFF7C3AED);
const kCoral = Color(0xFFFF7A59);
const kInk = Color(0xFF1E1B4B);

class SubjectEntry {
  final TextEditingController name = TextEditingController();
  TimeOfDay? start;
  TimeOfDay? end;
}

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _detailsKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _section = TextEditingController();
  final _course = TextEditingController();
  final List<SubjectEntry> _subjects = [SubjectEntry()];

  int _step = 0;
  bool _saving = false;
  String? _subjectError;

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _course.dispose();
    for (final s in _subjects) {
      s.name.dispose();
    }
    super.dispose();
  }

  // ---------- helpers ----------
  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  String _fmt(TimeOfDay? t) => t == null ? 'Tap to choose' : t.format(context);

  String _duration(SubjectEntry s) {
    if (s.start == null || s.end == null) return '';
    final d = _mins(s.end!) - _mins(s.start!);
    if (d <= 0) return '';
    return '${d ~/ 60}h ${d % 60}m';
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kIndigo),
      filled: true,
      fillColor: const Color(0xFFF4F3FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIndigo, width: 2),
      ),
    );
  }

  Future<void> _pickTime(SubjectEntry s, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? s.start : s.end) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => isStart ? s.start = picked : s.end = picked);
    }
  }

  // ---------- navigation ----------
  Future<void> _next() async {
    if (_step == 0) {
      if (!_detailsKey.currentState!.validate()) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      for (final s in _subjects) {
        if (s.name.text.trim().isEmpty || s.start == null || s.end == null) {
          setState(
            () => _subjectError =
                'Fill in the name, start and end time for every subject.',
          );
          return;
        }
        if (_mins(s.end!) <= _mins(s.start!)) {
          setState(
            () => _subjectError =
                '"${s.name.text.trim()}" must end after it starts.',
          );
          return;
        }
      }
      setState(() {
        _subjectError = null;
        _step = 2;
      });
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('student_profiles').add({
        'name': _name.text.trim(),
        'section': _section.text.trim(),
        'course': _course.text.trim(),
        'subjects': _subjects
            .map(
              (s) => {
                'subject': s.name.text.trim(),
                'start': s.start!.format(context),
                'end': s.end!.format(context),
                'startMinutes': _mins(s.start!),
                'endMinutes': _mins(s.end!),
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(Icons.check_circle, color: kIndigo, size: 48),
          title: const Text('Profile saved!'),
          content: const Text('Your details were stored in Firebase.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      _reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    _name.clear();
    _section.clear();
    _course.clear();
    setState(() {
      _subjects
        ..clear()
        ..add(SubjectEntry());
      _step = 0;
      _subjectError = null;
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kIndigo, kViolet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Student Profile Setup',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _stepper(),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _body(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _navButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    const labels = ['Details', 'Subjects', 'Review'];
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: i <= _step ? kIndigo : Colors.grey.shade300,
                child: i < _step
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: i <= _step
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  color: i <= _step ? kIndigo : Colors.grey,
                ),
              ),
            ],
          ),
          if (i < 2)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < _step ? kIndigo : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _detailsStep();
      case 1:
        return _subjectsStep();
      default:
        return _reviewStep();
    }
  }

  // Step 1
  Widget _detailsStep() {
    String? req(String? v, String msg) =>
        (v == null || v.trim().isEmpty) ? msg : null;
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.badge_outlined,
            title: 'About you',
            subtitle: 'Tell us a little about your enrollment.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            decoration: _dec('Full name', Icons.person_outline),
            validator: (v) => req(v, 'Please enter your name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _section,
            decoration: _dec('Section', Icons.groups_2_outlined),
            validator: (v) => req(v, 'Please enter your section'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _course,
            decoration: _dec('Course', Icons.school_outlined),
            validator: (v) => req(v, 'Please enter your course'),
          ),
        ],
      ),
    );
  }

  // Step 2
  Widget _subjectsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.calendar_month_outlined,
          title: 'Class schedule',
          subtitle: 'Add each subject with its start and end time.',
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < _subjects.length; i++) _subjectCard(i),
        OutlinedButton.icon(
          onPressed: () => setState(() => _subjects.add(SubjectEntry())),
          icon: const Icon(Icons.add),
          label: const Text('Add another subject'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: kIndigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_subjectError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _subjectError!,

              style: const TextStyle(color: Colors.red, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  Widget _subjectCard(int i) {
    final s = _subjects[i];
    final dur = _duration(s);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kIndigo.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: kCoral,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Subject ${i + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              const Spacer(),
              if (dur.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dur,
                    style: const TextStyle(fontSize: 12, color: kIndigo),
                  ),
                ),
              if (_subjects.length > 1)
                IconButton(
                  onPressed: () => setState(() => _subjects.removeAt(i)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: s.name,
            decoration: _dec('Subject name', Icons.menu_book_outlined),
          ),
          const SizedBox(height: 10),
          _timeTile(
            'Start time',
            Icons.play_circle_outline,
            s.start,
            () => _pickTime(s, true),
          ),
          const SizedBox(height: 10),
          _timeTile(
            'End time',
            Icons.flag_outlined,
            s.end,
            () => _pickTime(s, false),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(
    String label,
    IconData icon,
    TimeOfDay? value,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(
          label,
          icon,
        ).copyWith(suffixIcon: const Icon(Icons.access_time, color: kCoral)),
        child: Text(
          _fmt(value),
          style: TextStyle(color: value == null ? Colors.grey : kInk),
        ),
      ),
    );
  }

  // Step 3
  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.fact_check_outlined,
          title: 'Review your details',
          subtitle: 'Make sure everything looks right before saving.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F3FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _reviewRow(Icons.person_outline, 'Name', _name.text.trim()),
              _reviewRow(
                Icons.groups_2_outlined,
                'Section',
                _section.text.trim(),
              ),
              _reviewRow(Icons.school_outlined, 'Course', _course.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Class schedule',
          style: TextStyle(fontWeight: FontWeight.w800, color: kInk),
        ),
        const SizedBox(height: 8),
        for (final s in _subjects)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: kIndigo.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: kCoral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name.text.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${s.start!.format(context)} - ${s.end!.format(context)}  (${_duration(s)})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kIndigo),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _navButtons() {
    final isLast = _step == 2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          TextButton.icon(
            onPressed: _saving ? null : () => setState(() => _step--),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          )
        else
          const SizedBox(),
        FilledButton.icon(
          onPressed: _saving ? null : _next,
          style: FilledButton.styleFrom(
            backgroundColor: kCoral,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isLast ? Icons.cloud_upload_outlined : Icons.chevron_right,
                ),
          label: Text(_step == 0 ? 'Next' : (isLast ? 'Save' : 'Review')),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kIndigo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
