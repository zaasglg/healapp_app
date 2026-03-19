import 'package:flutter/material.dart';
import 'package:healapp_mobile/screens/legal/legal_document_viewer.dart';

class AgreementPage extends StatelessWidget {
  static const String routeName = '/agreement';

  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentViewer(
      assetPath: 'assets/documents/agreement.pdf',
      title: 'Пользовательское соглашение',
    );
  }
}
