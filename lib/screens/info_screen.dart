import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/compliance_engine.dart';

class InfoScreen extends StatelessWidget {
  final String docType;
  const InfoScreen({super.key, required this.docType});

  @override
  Widget build(BuildContext context) {
    final doc = ComplianceEngine.getLegalDocument(docType);
    
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(title: Text(doc['title']!, style: const TextStyle(color: Colors.white))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          doc['content']!,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.6),
        ),
      ),
    );
  }
}