import 'package:flutter/material.dart';
import 'package:healapp_mobile/screens/legal/legal_document_viewer.dart';

class PolicyPage extends StatelessWidget {
  static const String routeName = '/policy';

  const PolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentViewer(
      assetPath: 'assets/documents/policy.pdf',
      title: 'Политика конфиденциальности',
    );
  }
}
