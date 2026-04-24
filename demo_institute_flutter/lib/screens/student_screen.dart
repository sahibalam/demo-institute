import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Student Dashboard',
      body: _StudentDashboardBody(),
    );
  }
}

class _StudentDashboardBody extends StatelessWidget {
  const _StudentDashboardBody();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? args : null;
    final programTitle = (map?['programTitle'] ?? '').toString().trim();
    final klass = (map?['class'] ?? '').toString().trim();

    final subtitle = [
      if (programTitle.isNotEmpty) programTitle,
      if (klass.isNotEmpty) 'Class $klass',
    ].join(' • ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Student Dashboard (to be ported from student.html)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle.isEmpty ? 'Select a program from Home → Programs.' : subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
