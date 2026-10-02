import 'package:flutter/material.dart';

const _departmentBlue = Color(0xff2864e8);
const _departmentInk = Color(0xff1b2638);
const _departmentMuted = Color(0xff77849a);

class StaffDepartmentScreen extends StatelessWidget {
  const StaffDepartmentScreen({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff5f7fb),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.badge_outlined, color: _departmentBlue, size: 34),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose Your Department',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _departmentInk),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select your team to continue to StaffHub.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: _departmentMuted),
                    ),
                    const SizedBox(height: 28),
                    _DepartmentCard(
                      title: 'Tech',
                      subtitle: 'Technology and engineering team',
                      icon: Icons.computer_outlined,
                      onTap: () => onSelect('Tech'),
                    ),
                    const SizedBox(height: 14),
                    _DepartmentCard(
                      title: 'Telecalling',
                      subtitle: 'Customer support and calling team',
                      icon: Icons.headset_mic_outlined,
                      onTap: () => onSelect('Telecalling'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffe4e9f1)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x080f172a), blurRadius: 12, offset: Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: const Color(0xffe9f0ff), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: _departmentBlue, size: 27),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _departmentInk)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: _departmentMuted)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _departmentMuted),
              ],
            ),
          ),
        ),
      );
}
