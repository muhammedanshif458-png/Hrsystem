import 'package:flutter/material.dart';

const _ink       = Color(0xff1b2638);
const _muted     = Color(0xff77849a);
const _cardBg    = Color(0xfffff5f5);
const _teleGreen = Color(0xff10b981);
const _border    = Color(0xffe8dede);

class StaffDepartmentScreen extends StatelessWidget {
  const StaffDepartmentScreen({
    super.key,
    required this.onSelect,
    this.selectedDepartment,
  });

  final ValueChanged<String> onSelect;
  final String? selectedDepartment;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff5f7fb),
        body: Column(
          children: [
            // ── Main scrollable body ──
            Expanded(
              child: LayoutBuilder(builder: (context, outer) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    // Ensure content fills the viewport so it's truly centered
                    constraints: BoxConstraints(minHeight: outer.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Heading ──
                              const Text(
                                'Choose Your Department',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Welcome to StaffHub. Please select your division to authenticate and launch\nyour specialized operational workspace.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14.5, color: _muted, height: 1.5),
                              ),
                              const SizedBox(height: 44),

                              // ── Department Cards ──
                              LayoutBuilder(builder: (ctx, inner) {
                                final isWide = inner.maxWidth > 520;
                                final tech = _DepartmentCard(
                                  title: 'Tech',
                                  subtitle: 'Technology and engineering team.',
                                  isTech: true,
                                  buttonLabel: 'Continue as Tech',
                                  isFilled: true,
                                  onTap: () => onSelect('Tech'),
                                );
                                final tele = _DepartmentCard(
                                  title: 'Telecalling',
                                  subtitle: 'Customer support and calling team.',
                                  isTech: false,
                                  buttonLabel: 'Continue as Telecalling',
                                  isFilled: false,
                                  onTap: () => onSelect('Telecalling'),
                                );
                                if (isWide) {
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: tech),
                                        const SizedBox(width: 20),
                                        Expanded(child: tele),
                                      ],
                                    ),
                                  );
                                }
                                return Column(children: [
                                  tech,
                                  const SizedBox(height: 20),
                                  tele,
                                ]);
                              }),

                              const SizedBox(height: 28),

                              // ── Remember checkbox ──
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    value: true,
                                    onChanged: (_) {},
                                    activeColor: const Color(0xff4f6ef7),
                                    side: const BorderSide(color: Color(0xffc0c8d8)),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const Text(
                                    'Remember workspace preference on this device',
                                    style: TextStyle(fontSize: 13, color: _ink),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // ── Footer info ──
                              const Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _FooterChip(
                                    icon: Icons.headset_mic_outlined,
                                    text: 'Need assistance? IT Desk (Ext: 4402)',
                                  ),
                                  Text('•', style: TextStyle(color: _muted)),
                                  _FooterChip(
                                    icon: Icons.info_outline,
                                    text: 'Session ID: SH-8924-US-EAST',
                                    isAccent: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const _FooterChip(
                                icon: Icons.shield_outlined,
                                text: 'Protected by Zero-Trust Architecture',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            // ── Bottom bar ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              child: Row(
                children: [
                  const Text(
                    '© 2025 StaffHub Technologies Inc. All rights reserved.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const Spacer(),
                  _BarLink(label: 'Security & Compliance', onTap: () {}),
                  const SizedBox(width: 20),
                  _BarLink(label: 'Privacy Policy', onTap: () {}),
                  const SizedBox(width: 20),
                  _BarLink(label: 'Terms of Service', onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Department Card  (StatefulWidget so it tracks hover)
// ════════════════════════════════════════════════════════════════════════════

class _DepartmentCard extends StatefulWidget {
  const _DepartmentCard({
    required this.title,
    required this.subtitle,
    required this.isTech,
    required this.buttonLabel,
    required this.isFilled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isTech;        // true → Tech card, false → Telecalling card
  final String buttonLabel;
  final bool isFilled;
  final VoidCallback onTap;

  @override
  State<_DepartmentCard> createState() => _DepartmentCardState();
}

class _DepartmentCardState extends State<_DepartmentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: const Color(0x140f172a),
              blurRadius: _hovered ? 24 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,   // ← centered
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // ── Icon box — turns black on Tech hover ──
            _IconBox(isTech: widget.isTech, hovered: _hovered),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),

            // ── Subtitle ──
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _muted),
            ),
            const SizedBox(height: 28),

            // ── Button ──
            _HoverButton(
              label: widget.buttonLabel,
              isFilled: widget.isFilled,
              hovered: _hovered,
              onTap: widget.onTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Icon Box  — Tech icon turns black on hover; Telecalling stays green
// ════════════════════════════════════════════════════════════════════════════

class _IconBox extends StatelessWidget {
  const _IconBox({required this.isTech, required this.hovered});
  final bool isTech;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    if (isTech) {
      // Default: pink bg + red text  |  Hover: black bg + white text
      final Color bg   = hovered ? Colors.black          : const Color(0xfffce8e8);
      final Color text = hovered ? Colors.white          : const Color(0xffcb4f4f);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: text,
            ),
            child: const Text('</>'),
          ),
        ),
      );
    } else {
      // Telecalling: light green bg + green icon  |  Hover: solid green bg + white icon
      final Color bg        = hovered ? _teleGreen               : const Color(0xffe6f9f3);
      final Color iconColor = hovered ? Colors.white             : _teleGreen;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.phone_outlined, color: iconColor, size: 27),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Hover-aware Button
// ════════════════════════════════════════════════════════════════════════════

class _HoverButton extends StatelessWidget {
  const _HoverButton({
    required this.label,
    required this.isFilled,
    required this.hovered,
    required this.onTap,
  });

  final String label;
  final bool   isFilled;
  final bool   hovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final Border border;

    if (isFilled) {
      // Tech: solid black by default; slightly lighter on hover (ripple effect)
      bgColor = hovered ? const Color(0xff222222) : Colors.black;
      fgColor = Colors.white;
      border  = Border.all(color: Colors.transparent);
    } else {
      // Telecalling: outlined → solid green on hover
      bgColor = hovered ? _teleGreen : Colors.white;
      fgColor = hovered ? Colors.white : _ink;
      border  = Border.all(
        color: hovered ? _teleGreen : const Color(0xffd0d6e2),
        width: 1.5,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
              child: Text(label),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: fgColor,
                size: 18,
                key: ValueKey(fgColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ════════════════════════════════════════════════════════════════════════════

class _FooterChip extends StatelessWidget {
  const _FooterChip({required this.icon, required this.text, this.isAccent = false});
  final IconData icon;
  final String   text;
  final bool     isAccent;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isAccent ? const Color(0xff4f6ef7) : _muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isAccent ? const Color(0xff4f6ef7) : _muted,
            ),
          ),
        ],
      );
}

class _BarLink extends StatelessWidget {
  const _BarLink({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
      );
}
