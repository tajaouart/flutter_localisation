import 'package:example/generated_translation_methods.dart';
import 'package:example/localization/generated/app_localizations.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:material_ui/material_ui.dart';

import 'main.dart';

const _languages = [
  (Locale('en'), 'English'),
  (Locale('es'), 'Español'),
  (Locale('es', 'MX'), 'Español (México)'),
  (Locale('fr'), 'Français'),
  (Locale('ar'), 'العربية'),
  (Locale.fromSubtags(languageCode: 'zh'), '简体中文'),
  (Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), '繁體中文'),
];

const _genders = [('male', 'He'), ('female', 'She'), ('other', 'They')];
const _quickCounts = [0, 1, 2, 3, 11, 100];
const _pluralForms = ['zero', 'one', 'two', 'few', 'many', 'other'];

const _sampleName = 'Sam';
final _lastSeen = DateTime(2026, 3, 14);
final _eventStart = DateTime(2026, 12, 3, 18, 30);
const _orderTotal = 1234.5;
const _downloads = 15300;
const _progress = 0.875;

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.flavorName,
    required this.onLanguageChange,
  });

  final String flavorName;
  final ValueChanged<Locale> onLanguageChange;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _count = 2;
  String _gender = 'female';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context);
    final tr = context.tr;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr.appTitle,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${widget.flavorName} flavor',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 36),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(locale),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.simpleGreeting,
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr.welcomeMessage(_sampleName),
                    style: text.titleMedium?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _LanguagePicker(
              current: locale,
              onChanged: widget.onLanguageChange,
            ),
            const SizedBox(height: 32),
            const _SectionTitle('Strings'),
            _Panel(
              children: [
                _StringRow(arbKey: 'appTitle', value: tr.appTitle),
                _StringRow(arbKey: 'simpleGreeting', value: tr.simpleGreeting),
                _StringRow(arbKey: 'hello', value: tr.hello(_sampleName)),
                _StringRow(
                  arbKey: 'welcomeMessage',
                  value: tr.welcomeMessage(_sampleName),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Plurals'),
            _PluralPanel(
              count: _count,
              label: tr.itemsInCart(_count),
              onChanged: (value) => setState(() => _count = value),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Select and nested messages'),
            _Panel(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _Segmented(
                    options: _genders,
                    selected: _gender,
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                ),
                _StringRow(
                  arbKey: 'notificationFrom',
                  value: tr.notificationFrom(_gender),
                ),
                _StringRow(
                  arbKey: 'friendsInvited',
                  value: tr.friendsInvited(_gender, _count),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Dates and numbers'),
            _Panel(
              children: [
                _StringRow(arbKey: 'lastSeen', value: tr.lastSeen(_lastSeen)),
                _StringRow(
                  arbKey: 'eventStarts',
                  value: tr.eventStarts(_eventStart),
                ),
                _StringRow(
                  arbKey: 'orderTotal',
                  value: tr.orderTotal(_orderTotal),
                ),
                _StringRow(
                  arbKey: 'downloads',
                  value: tr.downloads(_downloads),
                ),
                _StringRow(arbKey: 'progress', value: tr.progress(_progress)),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Live updates'),
            const _LivePanel(),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.current, required this.onChanged});

  final Locale current;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (locale, name) in _languages)
          Semantics(
            button: true,
            selected: locale == current,
            child: Material(
              color: locale == current ? palette.ink : palette.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: locale == current ? palette.ink : palette.line,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(locale),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    name,
                    style: text.labelLarge?.copyWith(
                      color: locale == current ? palette.surface : palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: Material(
                  color: value == selected
                      ? palette.surface
                      : Colors.transparent,
                  elevation: value == selected ? 1 : 0,
                  shadowColor: palette.line,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onChanged(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(
                          color: value == selected
                              ? palette.ink
                              : palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: palette.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

TextStyle _keyStyle(Palette palette, {bool active = false}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      color: active ? palette.accent : palette.muted,
    );

/// Whether [key] currently comes from a live update for [locale], checking
/// the regional or script variant before the language, like the translator.
bool _isLive(BuildContext context, String key) {
  final service = context.translations;
  if (service == null) return false;
  final locale = Localizations.localeOf(context);
  final candidates = [
    if (locale.scriptCode != null)
      '${locale.languageCode}-${locale.scriptCode}',
    if (locale.countryCode != null)
      '${locale.languageCode}-${locale.countryCode}',
    locale.languageCode,
  ];
  return candidates.any(
    (tag) =>
        service.hasOverride(tag, key) ||
        service.hasOverride(tag.replaceAll('-', '_'), key),
  );
}

/// One ARB entry: its key, the resolved text, and a marker when the text
/// comes from a live update instead of the bundled ARB.
class _StringRow extends StatelessWidget {
  const _StringRow({required this.arbKey, required this.value});

  final String arbKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(arbKey, style: _keyStyle(palette)),
                const SizedBox(height: 4),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
          if (_isLive(context, arbKey)) _Tag(label: 'Live', palette: palette),
        ],
      ),
    );
  }
}

class _PluralPanel extends StatelessWidget {
  const _PluralPanel({
    required this.count,
    required this.label,
    required this.onChanged,
  });

  static const _max = 1000;

  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;
    // The CLDR category of the count in this language. The message itself
    // may still answer with an exact =0, =1 or =2 case.
    final category = Intl.pluralLogic(
      count,
      locale: AppLocalizations.of(context).localeName,
      zero: 'zero',
      one: 'one',
      two: 'two',
      few: 'few',
      many: 'many',
      other: 'other',
      useExplicitNumberCases: false,
    );

    return _Panel(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('itemsInCart', style: _keyStyle(palette)),
                  ),
                  if (_isLive(context, 'itemsInCart'))
                    _Tag(label: 'Live', palette: palette),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.remove,
                    tooltip: 'Remove one',
                    onPressed: count > 0 ? () => onChanged(count - 1) : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    tooltip: 'Add one',
                    onPressed: count < _max ? () => onChanged(count + 1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final value in _quickCounts)
                    _Chip(
                      label: '$value',
                      active: value == count,
                      onTap: () => onChanged(value),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: palette.line),
              const SizedBox(height: 14),
              Text(
                'Plural category of $count',
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in _pluralForms)
                    _Chip(label: name, active: name == category),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    return IconButton.outlined(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.line),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? palette.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? palette.accent : palette.line),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: _keyStyle(palette, active: active),
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _LivePanel extends StatefulWidget {
  const _LivePanel();

  @override
  State<_LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<_LivePanel> {
  bool _refreshing = false;
  DateTime? _checkedAt;

  Future<void> _refresh(TranslationService service) async {
    setState(() => _refreshing = true);
    await service.refresh();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _checkedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<Palette>()!;
    final text = Theme.of(context).textTheme;
    final service = context.translations!;
    final configured = service.isApiConfigured;
    final overrides = service.getCacheStatus()
      ..removeWhere((_, count) => count == 0);
    final edits = [
      for (final MapEntry(:key, :value) in overrides.entries)
        '$value ${value == 1 ? 'string' : 'strings'} updated in $key',
    ].join('\n');

    final String status;
    final String detail;
    if (!configured) {
      status = 'Off';
      detail = [
        if (edits.isNotEmpty) 'Showing edits saved from the last sync:\n$edits',
        'Run the app with FL_SECRET_KEY and FL_PROJECT_ID to pull new '
            'edits from your dashboard.',
      ].join('\n\n');
    } else if (overrides.isEmpty) {
      status = 'Connected';
      detail =
          'No edits yet. Change a string in the dashboard and refresh '
          'to see it here.';
    } else {
      status = 'Connected';
      detail = edits;
    }

    return _Panel(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: configured ? palette.accent : palette.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_checkedAt != null)
                    Text(
                      'Checked ${TimeOfDay.fromDateTime(_checkedAt!).format(context)}',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textDirection: TextDirection.ltr,
                style: text.bodyMedium?.copyWith(
                  color: palette.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: configured && !_refreshing
                      ? () => _refresh(service)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _refreshing
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.surface,
                          ),
                        )
                      : Text(context.tr.refreshTranslations),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.palette});

  final String label;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: palette.accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}
