import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const _blue    = Color(0xff2864e8);
const _ink     = Color(0xff1b2638);
const _muted   = Color(0xff77849a);
const _border  = Color(0xffe4e9f1);
const _bg      = Color(0xfff4f6fb);

class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({
    super.key,
    required this.selectedDepartment,
    required this.onSignIn,
    this.onBack,
  });
  final String selectedDepartment;
  final Future<void> Function(String email, String password, String workMode) onSignIn;
  final VoidCallback? onBack;

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _hidePassword  = true;
  bool _busy          = false;
  bool _rememberMe    = false;
  String _workMode    = 'Office';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _snack('Please enter a valid work email.');
      return;
    }
    if (password.trim().isEmpty) {
      _snack('Please enter your password.');
      return;
    }
    setState(() => _busy = true);
    try {
      final code = _workMode == 'Office' ? 'OFFICE' : 'WORK_FROM_HOME';
      await widget.onSignIn(email, password, code);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── dept label mapping ──
  String get _deptLabel {
    final d = widget.selectedDepartment.toLowerCase();
    if (d.contains('tech')) return 'Engineering & Tech (DIV-01)';
    if (d.contains('tele') || d.contains('call')) return 'Telecalling & CRM (DIV-02)';
    return widget.selectedDepartment;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleBack(); },
      child: Scaffold(
        backgroundColor: _bg,
        body: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          if (isWide) {
            return _wideLayout();
          }
          return _narrowLayout();
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Wide layout: left form + right gradient panel
  // ══════════════════════════════════════════════════════════════
  Widget _wideLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 620),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 40, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            // ── Left form panel ──
            Expanded(
              flex: 10,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: _formPanel(),
              ),
            ),
            // ── Right gradient panel ──
            Expanded(
              flex: 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: _gradientPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Narrow layout: just the form
  // ══════════════════════════════════════════════════════════════
  Widget _narrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _formContent(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Form panel (white left side)
  // ══════════════════════════════════════════════════════════════
  Widget _formPanel() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: _formContent(),
      ),
    );
  }

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top bar: logo left, language right ──
        Row(
          children: [
            // Logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'StaffHub',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xffe9f0ff),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'HRMS',
                style: TextStyle(fontSize: 10, color: _blue, fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ),
            const Spacer(),
            // Language selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_outlined, size: 15, color: _muted),
                  SizedBox(width: 4),
                  Text('EN', style: TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w500)),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _muted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Title ──
        const Text(
          'Login',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome, let\'s get started with your workspace',
          style: TextStyle(fontSize: 13.5, color: _muted),
        ),
        const SizedBox(height: 20),

        // ── Department + Work Mode badge row ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xfff8f9fc),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              // Green dot + dept name
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xff22c55e),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _deptLabel,
                  style: const TextStyle(fontSize: 12.5, color: _ink, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              // Office pill (selected)
              _WorkPill(
                label: 'Office',
                selected: _workMode == 'Office',
                onTap: _busy ? null : () => setState(() => _workMode = 'Office'),
              ),
              const SizedBox(width: 6),
              // Remote pill
              _WorkPill(
                label: 'Remote',
                selected: _workMode == 'Work From Home',
                onTap: _busy ? null : () => setState(() => _workMode = 'Work From Home'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── EMAIL ──
        const _FieldLabel(text: 'EMAIL'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: _inputDecoration(hint: 'Enter email'),
        ),
        const SizedBox(height: 14),

        // ── PASSWORD ──
        const _FieldLabel(text: 'PASSWORD'),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _hidePassword,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: _inputDecoration(hint: 'Enter password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: _muted,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Remember me + Forgot password ──
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                side: const BorderSide(color: Color(0xffcbd5e1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Remember me', style: TextStyle(fontSize: 13, color: _ink)),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 13, color: _blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Login button ──
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0f172a),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xff334155),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Login'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: _muted),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      );

  // ══════════════════════════════════════════════════════════════
  // Right gradient panel
  // ══════════════════════════════════════════════════════════════
  Widget _gradientPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Multi-color blurred gradient background
        CustomPaint(painter: _GradientPainter()),
        // Blur overlay
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: const SizedBox.expand(),
        ),
        // Centered text
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hey There!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [Shadow(color: Color(0x40000000), blurRadius: 12)],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Create your account now and step\ninto an amazing new journey.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.55,
                    shadows: [Shadow(color: Color(0x30000000), blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Gradient painter — matches the blurred orange/teal/red panel
// ════════════════════════════════════════════════════════════════
class _GradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base: deep teal/dark overlay
    canvas.drawRect(rect, Paint()..color = const Color(0xff0d3d3a));

    // Orange blob — bottom left
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.2, size.height * 0.75), width: size.width * 1.1, height: size.height * 0.9),
      Paint()
        ..color = const Color(0xffee6c3a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // Red blob — right
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.85, size.height * 0.5), width: size.width * 0.8, height: size.height * 0.9),
      Paint()
        ..color = const Color(0xffdc2626)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );

    // Teal/cyan highlight — top center
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.15), width: size.width * 0.7, height: size.height * 0.5),
      Paint()
        ..color = const Color(0xff0d9488)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );

    // Warm amber — center
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.45, size.height * 0.6), width: size.width * 0.5, height: size.height * 0.4),
      Paint()
        ..color = const Color(0xfff59e0b)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
    );

    // Dark vignette overlay
    final vignette = const RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [Colors.transparent, Color(0x80000000)],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════
// Work mode pill (Office / Remote)
// ════════════════════════════════════════════════════════════════
class _WorkPill extends StatelessWidget {
  const _WorkPill({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _muted,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Field label (EMAIL, PASSWORD in small caps style)
// ════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.6,
        ),
      );
}
