import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';

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
  final Future<void> Function(String email, String password, String workMode,
      LocationCapture? location) onSignIn;
  final VoidCallback? onBack;

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  bool _locating = false;
  bool _permanentlyDenied = false;
  String _workMode = 'Office';
  String? _locationError;
  LocationCapture? _location;

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

  Future<void> _selectWorkMode(String mode) async {
    setState(() {
      _workMode = mode;
      _location = null;
      _locationError = null;
      _permanentlyDenied = false;
    });
    if (mode == 'Work From Home') await _detectLocation();
  }

  Future<void> _detectLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _location = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationMessage(
            'Please enable location services to continue.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const _LocationMessage(
            'Location permission is required for Work From Home sign-in.');
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _permanentlyDenied = true);
        throw const _LocationMessage(
            'Location permission is blocked. Enable it in app settings to continue.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      var address =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
            place.country
          ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet()
              .toList();
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {
        // Coordinates are still the real device location if reverse geocoding is unavailable.
      }
      if (mounted)
        setState(() => _location = LocationCapture(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address));
    } on _LocationMessage catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (error) {
      if (mounted)
        setState(() => _locationError = error is TimeoutException
            ? 'Location detection timed out. Please retry.'
            : 'Unable to detect your location. Check location settings and retry.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _locating) return;
    if (_workMode == 'Work From Home' && _location == null) {
      setState(() => _locationError ??=
          'Location permission is required for Work From Home sign-in.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSignIn(_emailController.text, _passwordController.text,
          _workMode, _location);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
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
                    if (_workMode == 'Work From Home') ...[
                      const SizedBox(height: 11),
                      _locationCard(),
                    ],
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
                          onPressed: _busy ||
                                  _locating ||
                                  (_workMode == 'Work From Home' &&
                                      _location == null)
                              ? null
                              : _submit,
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

  Widget _locationCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffe4e9f1)),
            borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined, color: _blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Current Location',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                const SizedBox(height: 4),
                if (_locating)
                  const Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Detecting location...',
                        style: TextStyle(fontSize: 12, color: _muted))
                  ]),
                if (!_locating && _location != null)
                  Text(_location!.address,
                      style: const TextStyle(fontSize: 13, color: _ink)),
                if (!_locating && _location != null)
                  const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('✓ Location detected',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xff198754)))),
                if (!_locating && _locationError != null)
                  Text(_locationError!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xffc0392b))),
                if (!_locating && _permanentlyDenied)
                  TextButton.icon(
                      onPressed: Geolocator.openAppSettings,
                      icon: const Icon(Icons.settings_outlined, size: 15),
                      label: const Text('Open app settings'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact)),
              ])),
          if (!_locating)
            IconButton(
                onPressed: _detectLocation,
                tooltip: 'Retry location detection',
                icon: const Icon(Icons.refresh, size: 19, color: _blue),
                visualDensity: VisualDensity.compact),
        ]),
      );

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

class _LocationMessage implements Exception {
  const _LocationMessage(this.message);
  final String message;
}
