import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'About',
      body: Center(
        child: Text('About (to be ported from about.html)'),
      ),
    );
  }
}
