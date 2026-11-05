import 'package:flutter/material.dart';

const _blue = Color(0xff2864e8);
const _ink = Color(0xff1b2638);
const _muted = Color(0xff77849a);

class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({
    super.key,
    required this.selectedDepartment,
    required this.onSignIn,
    this.onBack,
  });
  final String selectedDepartment;
  final Future<void> Function(
    String email,
    String password,
    String workMode,
  ) onSignIn;
  final VoidCallback? onBack;

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String _workMode = 'Office';

  @override
  void initState() {
    super.initState();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectWorkMode(String mode) {
    setState(() {
      _workMode = mode;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid work email.')));
      return;
    }
    if (password.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your password.')));
      return;
    }
    if (_workMode != 'Office' && _workMode != 'Work From Home') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a work mode.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final workModeCode = _workMode == 'Office' ? 'OFFICE' : 'WORK_FROM_HOME';
      await widget.onSignIn(email, password, workModeCode);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const ValueKey('sign-in-back-button'),
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back, color: _ink),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                        onPressed: _handleBack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                        child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: _ink,
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.badge_outlined,
                                color: Colors.white, size: 27))),
                    const SizedBox(height: 12),
                    Center(
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                                color: const Color(0xffe9f0ff),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                '●  ${widget.selectedDepartment.toUpperCase()} WORKSPACE',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _blue,
                                    letterSpacing: .5,
                                    fontWeight: FontWeight.w700)))),
                    const SizedBox(height: 10),
                    const Center(
                        child: Text('Welcome back 👋',
                            style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: _ink))),
                    const SizedBox(height: 4),
                    const Center(
                        child: Text('Sign in to continue to your workspace',
                            style: TextStyle(fontSize: 14, color: _muted))),
                    const SizedBox(height: 20),
                    _label('Work Mode'),
                    const SizedBox(height: 7),
                    Row(children: [
                      Expanded(
                          child:
                              _modeButton('Office', Icons.business_outlined)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: _modeButton(
                              'Work From Home', Icons.home_work_outlined)),
                    ]),
                    const SizedBox(height: 16),
                    _label('Work Email'),
                    const SizedBox(height: 6),
                    _input(_emailController,
                        icon: Icons.mail_outline,
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _label('Password'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: _decoration(
                              icon: Icons.lock_outline,
                              hint: 'Enter your password')
                          .copyWith(
                        suffixIcon: IconButton(
                            icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 17),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const SizedBox.shrink(),
                          label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_busy ? 'Signing In...' : 'Sign In'),
                                const SizedBox(width: 7),
                                if (!_busy) const Icon(Icons.login, size: 16)
                              ]),
                          style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                        )),
                    const SizedBox(height: 24),
                    const Center(
                        child: Text(
                            'StaffHub Systems Inc. • Internal Access Only',
                            style: TextStyle(fontSize: 11, color: _muted))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String mode, IconData icon) {
    final selected = _workMode == mode;
    return OutlinedButton.icon(
      onPressed: _busy ? null : () => _selectWorkMode(mode),
      icon: Icon(icon, size: 17),
      label: Text(mode, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? _blue : _ink,
        backgroundColor: selected ? const Color(0xffe9f0ff) : Colors.white,
        side: BorderSide(color: selected ? _blue : const Color(0xffe4e9f1)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14, color: _muted, fontWeight: FontWeight.w600));

  Widget _input(TextEditingController controller,
          {required IconData icon,
          required String hint,
          TextInputType? keyboardType}) =>
      TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _decoration(icon: icon, hint: hint));

  InputDecoration _decoration({required IconData icon, required String hint}) =>
      InputDecoration(
        prefixIcon: Icon(icon, size: 17),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffe4e9f1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffe4e9f1))),
      );
}
