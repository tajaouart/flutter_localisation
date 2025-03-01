import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'localization/generated/app_localizations.dart';

class MyHomePage extends StatelessWidget {
  final Function(Locale) onLocaleChange;

  const MyHomePage({super.key, required this.onLocaleChange});

  @override
  Widget build(BuildContext context) {
    Locale currentLocale = Localizations.localeOf(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.title,
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [_buildLanguageSelector(currentLocale)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated Lottie Illustration for better UX
            const SizedBox(height: 20),

            // Greeting Section
            _buildInfoCard(
              title: loc.greeting('Mounir'),
              subtitle: loc.hello_worl('Mounir', '15', '4'),
              icon: Icons.translate,
            ),

            const SizedBox(height: 20),

            // Another Example Card
            _buildInfoCard(
              title: loc.thankYou,
              subtitle: loc.goodbyeMessage,
              icon: Icons.favorite,
            ),
          ],
        ),
      ),
    );
  }

  // Builds the Language Selector Dropdown
  Widget _buildLanguageSelector(Locale currentLocale) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: DropdownButton<Locale>(
        value: currentLocale,
        icon: const Icon(Icons.language, color: Colors.white),
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.grey[850],
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            onLocaleChange(newLocale);
          }
        },
        items: const [
          DropdownMenuItem(value: Locale('en'), child: Text('🇬🇧 English')),
          DropdownMenuItem(value: Locale('fr'), child: Text('🇫🇷 Français')),
          DropdownMenuItem(value: Locale('es'), child: Text('🇪🇸 Español')),
        ],
      ),
    );
  }

  // Card UI for Better Presentation
  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 32),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 14)),
      ),
    );
  }
}
