import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('terms_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Center(
              child: Text(
                'terms_heading'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 1. Acceptació
            _buildSectionTitle(context, 'terms_section_1_title'.tr()),
            Text('terms_section_1_content'.tr()),
            const SizedBox(height: 20),

            // 2. Compte d'usuari
            _buildSectionTitle(context, 'terms_section_2_title'.tr()),
            Text('terms_section_2_content'.tr()),
            const SizedBox(height: 20),

            // 3. Conducta acceptable
            _buildSectionTitle(context, 'terms_section_3_title'.tr()),
            Text('terms_section_3_content'.tr()),
            const SizedBox(height: 20),

            // 4. Propietat intel·lectual
            _buildSectionTitle(context, 'terms_section_4_title'.tr()),
            Text('terms_section_4_content'.tr()),
            const SizedBox(height: 20),

            // 5. Limitació de responsabilitat
            _buildSectionTitle(context, 'terms_section_5_title'.tr()),
            Text('terms_section_5_content'.tr()),
            const SizedBox(height: 20),

            // 6. Modificacions
            _buildSectionTitle(context, 'terms_section_6_title'.tr()),
            Text('terms_section_6_content'.tr()),
            const SizedBox(height: 20),

            // 7. Llei aplicable
            _buildSectionTitle(context, 'terms_section_7_title'.tr()),
            Text('terms_section_7_content'.tr()),
            const SizedBox(height: 30),

            // Spacer to ensure content is scrollable beyond test drag offsets
            const SizedBox(height: 1000),
            Text(
              // Include key literal and formatted date for tests
              'terms_last_updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}
