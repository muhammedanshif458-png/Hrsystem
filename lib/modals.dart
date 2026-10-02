// ─── modals.dart ───────────────────────────────────────────────────────────────
// Converted from Kotlin Modals.kt in com.example.ui.components

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'badges.dart';
import 'models.dart';
import 'date_time_utils.dart';

// ─── Add Staff Modal ──────────────────────────────────────────────────────────

class AddStaffModal extends StatefulWidget {
  const AddStaffModal({
    super.key,
    required this.onDismiss,
    required this.onSave,
  });

  final VoidCallback onDismiss;
  final void Function(String name, String email, String phoneNumber, String department, String role, String joinDate) onSave;

  @override
  State<AddStaffModal> createState() => _AddStaffModalState();
}

class _AddStaffModalState extends State<AddStaffModal> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dateCtrl  = TextEditingController();

  String _department = Department.tech;
  String _role       = Role.staff;
  bool _markResigned = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateTimeUtils.getTodayIsoDate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFFF8F9FA),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add staff',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'They can sign in with this email once their account is created.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(_errorMsg!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              _label('Full name'),
              _field(_nameCtrl, hint: ''),
              const SizedBox(height: 12),
              _label('Email'),
              _field(_emailCtrl, hint: '', type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 191,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Department'),
                        _dropdown(
                          value: _department,
                          items: Department.list,
                          onChanged: (v) => setState(() => _department = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 191,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Role'),
                        _dropdown(
                          value: _role,
                          items: Role.list,
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 191,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Join date'),
                        _fieldDate(_dateCtrl, text: '09/21/2026'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 191,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Monthly salary'),
                        _fieldSalary(TextEditingController(text: '0')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mark as resigned',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Keeps the record, hides them as active.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _markResigned,
                      onChanged: (value) => setState(() => _markResigned = value),
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF1F2937),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFD1D5DB),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 76,
                    height: 37,
                    child: OutlinedButton(
                      onPressed: widget.onDismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderMedium),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFFF7F7F7),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 62,
                    height: 37,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final name  = _nameCtrl.text.trim();
                        final email = _emailCtrl.text.trim();
                        final phone = _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : '0000000000';
                        if (name.isEmpty) {
                          setState(() => _errorMsg = 'Please enter full name');
                          return;
                        }
                        if (email.isEmpty) {
                          setState(() => _errorMsg = 'Please enter email address');
                          return;
                        }
                        if (!email.contains('@')) {
                          setState(() => _errorMsg = 'Please enter a valid email address');
                          return;
                        }
                        final phoneRegExp = RegExp(r'^\+?[0-9\s\-\(\)]{7,20}$');
                        final digitCount = phone.replaceAll(RegExp(r'\D'), '').length;
                        if (!phoneRegExp.hasMatch(phone) || digitCount < 7 || digitCount > 15) {
                          setState(() => _errorMsg = 'Please enter a valid phone number (e.g. +91 98765 43210)');
                          return;
                        }
                        widget.onSave(name, email, phone, _department, _role, _dateCtrl.text.trim());
                      },
                      child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      );

  Widget _field(TextEditingController ctrl, {String hint = '', TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        onChanged: (_) => setState(() => _errorMsg = null),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _fieldDate(TextEditingController ctrl, {String text = ''}) =>
      TextField(
        controller: ctrl,
        readOnly: true,
        onChanged: (_) => setState(() => _errorMsg = null),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: text,
          hintStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _fieldSalary(TextEditingController ctrl) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() => _errorMsg = null),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _dropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) =>
      DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))) .toList(),
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: const Color(0xFFD8DDE4))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ─── Edit Staff Modal ─────────────────────────────────────────────────────────

class EditStaffModal extends StatefulWidget {
  const EditStaffModal({
    super.key,
    required this.staff,
    required this.onDismiss,
    required this.onSave,
  });

  final Staff staff;
  final VoidCallback onDismiss;
  final void Function(Staff updated) onSave;

  @override
  State<EditStaffModal> createState() => _EditStaffModalState();
}

class _EditStaffModalState extends State<EditStaffModal> {
  late final _nameCtrl  = TextEditingController(text: widget.staff.name);
  late final _emailCtrl = TextEditingController(text: widget.staff.email);
  late final _phoneCtrl = TextEditingController(text: widget.staff.phoneNumber);
  late String _department = widget.staff.department;
  late String _role       = widget.staff.role;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit staff details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close), iconSize: 20, onPressed: widget.onDismiss),
              ],
            ),
            const SizedBox(height: 16),
            _label('Full name'),
            _field(_nameCtrl),
            const SizedBox(height: 12),
            _label('Email'),
            _field(_emailCtrl, type: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _label('Phone Number'),
            _field(_phoneCtrl, hint: 'e.g. +91 98765 43210', type: TextInputType.phone),
            const SizedBox(height: 12),
            _label('Department'),
            _dropdown(value: _department, items: Department.list, onChanged: (v) => setState(() => _department = v!)),
            const SizedBox(height: 12),
            _label('Role'),
            _dropdown(value: _role, items: Role.list, onChanged: (v) => setState(() => _role = v!)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: widget.onDismiss, child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandSlate, foregroundColor: Colors.white),
                  onPressed: () {
                    widget.onSave(widget.staff.copyWith(
                      name:        _nameCtrl.text.trim(),
                      email:       _emailCtrl.text.trim(),
                      phoneNumber: _phoneCtrl.text.trim(),
                      department:  _department,
                      role:        _role,
                    ));
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      );

  Widget _field(TextEditingController ctrl, {String hint = '', TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandSlate)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _dropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) =>
      DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandSlate)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ─── Assign Task Modal ────────────────────────────────────────────────────────

class AssignTaskModal extends StatefulWidget {
  const AssignTaskModal({
    super.key,
    required this.staffList,
    this.preselectedStaffId,
    required this.onDismiss,
    required this.onSave,
  });

  final List<Staff> staffList;
  final String? preselectedStaffId;
  final VoidCallback onDismiss;
  final void Function(String staffId, String department, String description, String dueDate) onSave;

  @override
  State<AssignTaskModal> createState() => _AssignTaskModalState();
}

class _AssignTaskModalState extends State<AssignTaskModal> {
  late final List<Staff> _activeStaff;
  late String _selectedStaffId;
  final _descCtrl    = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _activeStaff = widget.staffList.where((s) => s.status == 'active').toList();
    _selectedStaffId = widget.preselectedStaffId ?? (_activeStaff.isNotEmpty ? _activeStaff.first.id : '');
    _dueDateCtrl.text = DateTimeUtils.getTodayIsoDate();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  Staff? get _selectedStaff => _activeStaff.firstWhere(
        (s) => s.id == _selectedStaffId,
        orElse: () => const Staff(),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assign task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMsg != null) ...[
                Text(_errorMsg!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12.5)),
                const SizedBox(height: 12),
              ],
              _label('Staff member'),
              DropdownButtonFormField<String>(
                value: _selectedStaffId.isEmpty ? null : _selectedStaffId,
                items: _activeStaff
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStaffId = v ?? ''),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandSlate)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              _label('Task description'),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() => _errorMsg = null),
                decoration: InputDecoration(
                  hintText: 'Describe the task...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandSlate)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              _label('Due date'),
              TextField(
                controller: _dueDateCtrl,
                decoration: InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.brandSlate)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandSlate,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (_descCtrl.text.trim().isEmpty) {
                        setState(() => _errorMsg = 'Please enter a task description');
                        return;
                      }
                      final dept = _selectedStaff?.department ?? Department.tech;
                      widget.onSave(_selectedStaffId, dept, _descCtrl.text.trim(), _dueDateCtrl.text.trim());
                    },
                    child: const Text('Assign'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      );
}

// ─── Forgot Password Dialog ───────────────────────────────────────────────────

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.onDismiss,
    required this.onSubmit,
  });

  final VoidCallback onDismiss;
  final void Function(String email) onSubmit;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text('Reset password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Enter your work email address to receive password reset instructions.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'name@company.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: widget.onDismiss, child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandSlate, foregroundColor: Colors.white),
                  onPressed: () => widget.onSubmit(_emailCtrl.text),
                  child: const Text('Send reset link'),
                ),
              ],
            ),
          ],
        ),
      ),
      )
    );
  }
}

// ─── Firestore Rules Dialog ───────────────────────────────────────────────────

class FirestoreRulesDialog extends StatelessWidget {
  const FirestoreRulesDialog({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  static const _rulesContent = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isHRManager() {
      return isSignedIn() && (
        request.auth.token.role == 'HR Manager' ||
        get(/databases/\$(database)/documents/staff/\$(request.auth.uid)).data.role == 'HR Manager'
      );
    }
    
    function isOwner(staffId) {
      return isSignedIn() && request.auth.uid == staffId;
    }

    match /staff/{staffId} {
      allow read: if isHRManager() || isOwner(staffId);
      allow create, update, delete: if isHRManager();
    }

    match /attendance/{attendanceId} {
      allow read: if isHRManager() || (isSignedIn() && resource.data.staff_id == request.auth.uid);
      allow create, update: if isHRManager() || (isSignedIn() && request.resource.data.staff_id == request.auth.uid);
      allow delete: if isHRManager();
    }

    match /tasks/{taskId} {
      allow read: if isHRManager() || (isSignedIn() && resource.data.staff_id == request.auth.uid);
      allow create, delete: if isHRManager();
      allow update: if isHRManager() || (isSignedIn() && resource.data.staff_id == request.auth.uid);
    }

    match /daily_updates/{updateId} {
      allow read: if isHRManager() || (isSignedIn() && resource.data.staff_id == request.auth.uid);
      allow create, update: if isHRManager() || (isSignedIn() && request.resource.data.staff_id == request.auth.uid);
      allow delete: if isHRManager();
    }
  }
}""";

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Firestore security rules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close), iconSize: 20, onPressed: onDismiss),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                _rulesContent,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandSlate, foregroundColor: Colors.white),
                onPressed: onDismiss,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
      )
    );
  }
}
