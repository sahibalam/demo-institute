import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Contact',
      body: Center(
        child: Text('Contact (to be ported from contact.html)'),
      ),
    );
  }
}
