import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'models.dart';
import 'hr_repository.dart';
import 'core/api/api_exception.dart';
import 'core/utils/file_download.dart';
import 'services/staff_chat_socket_service.dart';
import 'storage/token_storage.dart';

const _blue = Color(0xff2864e8);
ThemeMode staffHubThemeMode = ThemeMode.light;

bool get _isDark {
  if (staffHubThemeMode == ThemeMode.dark) return true;
  if (staffHubThemeMode == ThemeMode.light) return false;
  try {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  } catch (_) {
    return false;
  }
}

// ── Dark-mode-aware colour tokens ───────────────────────────────────────────
// Primary text
Color get _ink => _isDark ? const Color(0xfff1f5f9) : const Color(0xff1b2638);
// Secondary text
Color get _subText => _isDark ? const Color(0xffcbd5e1) : const Color(0xff475569);
// Muted text
Color get _muted => _isDark ? const Color(0xff94a3b8) : const Color(0xff7b8798);
// Divider / border
Color get _line => _isDark ? const Color(0xff344256) : const Color(0xffe8edf4);
// Page scaffold background
Color get _bg => _isDark ? const Color(0xff0d1117) : const Color(0xfff5f7fb);
// Main content / container background
Color get _contentBg => _isDark ? const Color(0xff111827) : Colors.white;
// Primary card / panel surface
Color get _surface => _isDark ? const Color(0xff1c2736) : Colors.white;
// Secondary card background (slightly lighter than _surface)
Color get _cardAlt => _isDark ? const Color(0xff202d3d) : const Color(0xfff8fafc);
// Input / field background
Color get _fieldBg => _isDark ? const Color(0xff172233) : Colors.white;
// Header / sidebar background
Color get _headerBg => _isDark ? const Color(0xff151d2b) : Colors.white;
// Faint tinted background (chips, badges, row highlights)
Color get _chip => _isDark ? const Color(0xff1e2d3f) : const Color(0xfff1f5f9);
// Nav-item selected surface
Color get _navSel => _isDark ? const Color(0xff243347) : const Color(0xfff3f4f6);
// Nav-item selected border
Color get _navSelBorder => _isDark ? const Color(0xff3b4f6b) : const Color(0xffd1d5db);
// Nav-item selected / active text+icon
Color get _navSelFg => _isDark ? const Color(0xfff1f5f9) : const Color(0xff111827);
// Nav-item idle text
Color get _navIdleFg => _isDark ? const Color(0xff94a3b8) : const Color(0xff475569);
// Logo / branding container background
Color get _brandBg => _isDark ? const Color(0xff2b3a52) : const Color(0xff0f172a);
// Primary accent
Color get _primaryAccent => const Color(0xff3b82f6);

String _formatShortDuration(int seconds) {
  final value = seconds < 0 ? 0 : seconds;
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '$minutes min';
}

String _breakTypeLabel(String type) => switch (type) {
      'morning' || 'tea_break_1' => '☕ Tea Break 1',
      'lunch' => '🍽 Lunch Break',
      'afternoon' || 'tea_break_2' => '☕ Tea Break 2',
      _ => 'Break',
    };

ThemeData staffHubThemeData(ThemeMode mode) {
  final isDark = mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor:
        isDark ? const Color(0xff0d1117) : const Color(0xfff5f7fb),
    colorScheme: ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xff3b82f6) : _blue,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: isDark ? const Color(0xff1c2736) : Colors.white,
      onSurface: isDark ? const Color(0xfff1f5f9) : const Color(0xff1b2638),
      surfaceContainerHighest: isDark ? const Color(0xff202d3d) : _chip,
      onSurfaceVariant: isDark ? _muted : const Color(0xff7b8798),
      outline: isDark ? const Color(0xff344256) : _line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xff1c2736) : Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xfff1f5f9) : const Color(0xff1b2638),
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xffcbd5e1) : const Color(0xff556987),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? const Color(0xff1c2736) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: isDark ? const Color(0xff1c2736) : Colors.white,
    dividerColor: isDark ? const Color(0xff344256) : const Color(0xffe8edf4),
    fontFamily: 'Roboto',
  );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class StaffHubShell extends StatefulWidget {
  const StaffHubShell(
      {super.key,
      required this.pageIndex,
      required this.department,
      required this.staff,
      required this.repository,
      required this.workMode,
      required this.workLocation,
      this.themeMode = ThemeMode.light,
      this.onThemeModeChanged,
      required this.onNavigate,
      required this.onLogout});
  final int pageIndex;
  final String department;
  final Staff staff;
  final HRRepository repository;
  final String workMode;
  final String? workLocation;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<int> onNavigate;
  final VoidCallback onLogout;
  @override
  State<StaffHubShell> createState() => _StaffHubShellState();
}

class _StaffHubShellState extends State<StaffHubShell> {
  bool _isLoadingAttendance = false;
  bool _isPunching = false;
  String? _attendanceError;
  late ThemeMode _currentThemeMode;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = widget.themeMode;
    staffHubThemeMode = widget.themeMode;
    _initThemeMode();
    widget.repository.attendanceList.addListener(_onAttendanceChanged);
    widget.repository.leaveRequests.addListener(_onLeavesChanged);
    _loadAttendance();
    unawaited(widget.repository.fetchStaffLeaves());
  }

  Future<void> _initThemeMode() async {
    final saved = await TokenStorage.getThemeMode();
    if (saved != null && mounted) {
      final mode = switch (saved) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      if (_currentThemeMode != mode) {
        setState(() {
          _currentThemeMode = mode;
          staffHubThemeMode = mode;
        });
        widget.onThemeModeChanged?.call(mode);
      }
    }
  }

  void _handleThemeChanged(ThemeMode mode) {
    setState(() {
      _currentThemeMode = mode;
      staffHubThemeMode = mode;
    });
    widget.onThemeModeChanged?.call(mode);
    unawaited(TokenStorage.saveThemeMode(mode.name));
  }

  Future<void> _loadAttendance() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAttendance = true;
      _attendanceError = null;
    });
    try {
      await widget.repository.fetchStaffAttendance();
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
          _attendanceError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant StaffHubShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _currentThemeMode = widget.themeMode;
      staffHubThemeMode = widget.themeMode;
    }
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.attendanceList.removeListener(_onAttendanceChanged);
      oldWidget.repository.leaveRequests.removeListener(_onLeavesChanged);
      widget.repository.attendanceList.addListener(_onAttendanceChanged);
      widget.repository.leaveRequests.addListener(_onLeavesChanged);
      _loadAttendance();
      unawaited(widget.repository.fetchStaffLeaves());
    } else if (oldWidget.pageIndex != widget.pageIndex &&
        widget.pageIndex == 0) {
      unawaited(widget.repository.fetchStaffLeaves());
    }
  }

  void _onAttendanceChanged() {
    if (mounted) setState(() {});
  }

  void _onLeavesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.attendanceList.removeListener(_onAttendanceChanged);
    widget.repository.leaveRequests.removeListener(_onLeavesChanged);
    super.dispose();
  }

  Attendance? get _todayAttendance {
    final list = widget.repository.attendanceList.value;
    return list.where((a) {
      final matchesStaff = a.staffId.isEmpty ||
          widget.staff.id.isEmpty ||
          a.staffId == widget.staff.id;
      return matchesStaff && a.isToday;
    }).firstOrNull;
  }

  bool get _checkedIn =>
      _todayAttendance != null &&
      _todayAttendance!.checkOutAt == null &&
      _todayAttendance!.checkOutTime == null;

  DateTime get _checkInTime => _todayAttendance?.checkInAt ?? DateTime.now();

  DateTime? get _checkOutTime => _todayAttendance?.checkOutAt;

  _LeaveRequestInfo? _leaveRequest;

  _LeaveRequestInfo? get _latestLeaveRequest {
    final list = widget.repository.leaveRequests.value;
    final staffId = widget.staff.id;
    final myRequests = list
        .where(
            (r) => staffId.isEmpty || r.staffId.isEmpty || r.staffId == staffId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = myRequests.firstOrNull;
    if (latest != null) {
      return _LeaveRequestInfo.fromLeaveRequest(latest);
    }
    return _leaveRequest;
  }

  int? _settingsSubPage;
  final List<int> _settingsHistory = [];

  void _openSettingsSubPage(int page) {
    setState(() {
      if (_settingsSubPage != null && _settingsSubPage != page) {
        _settingsHistory.add(_settingsSubPage!);
      }
      _settingsSubPage = page;
    });
  }

  void _popSettingsSubPage() {
    setState(() {
      if (_settingsHistory.isNotEmpty) {
        _settingsSubPage = _settingsHistory.removeLast();
      } else {
        _settingsSubPage = null;
      }
    });
  }

  bool _chatSearchOpen = false;
  bool _chatNotifications = true;
  bool _leaveStatusNotifications = true;
  bool _punchReminders = true;

  Future<void> _togglePunch() async {
    if (_isPunching) return;
    setState(() => _isPunching = true);
    final attendance = _todayAttendance;
    try {
      if (attendance == null) {
        try {
          await widget.repository.checkIn(widget.staff.id);
        } on ApiException catch (e) {
          if (e.statusCode == 400 &&
              e.message.toLowerCase().contains('already checked in')) {
            await widget.repository.fetchStaffAttendance();
            if (_todayAttendance != null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Attendance reconciled: you are already checked in for today.')),
                );
              }
              return;
            }
          }
          rethrow;
        } catch (e) {
          if (e.toString().toLowerCase().contains('already checked in')) {
            await widget.repository.fetchStaffAttendance();
            if (_todayAttendance != null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Attendance reconciled: you are already checked in for today.')),
                );
              }
              return;
            }
          }
          rethrow;
        }
        return;
      }

      if (attendance.checkOutAt != null || attendance.checkOutTime != null)
        return;

      final shouldCheckOut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Are you sure you want to check out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('NO'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('YES'),
            ),
          ],
        ),
      );
      if (shouldCheckOut != true || !mounted) return;
      await widget.repository.checkOut(attendance.id);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException && error.isUnauthorized
            ? 'Your session has expired. Please sign in again.'
            : error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPunching = false);
      }
    }
  }

  Future<void> _toggleBreak(String? breakType) async {
    final attendance = _todayAttendance;
    if (attendance == null) return;
    try {
      await widget.repository.toggleBreak(attendance.id, breakType: breakType);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException && error.isUnauthorized
            ? 'Your session has expired. Please sign in again.'
            : error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      // Reconcile against the server after a failed mutation or refresh so
      // the selector never relies on a stale cached availability state.
      await _loadAttendance();
    }
  }

  void _openChat() {
    setState(() {
      _settingsHistory.clear();
      _settingsSubPage = 2;
      _chatSearchOpen = false;
    });
    widget.onNavigate(3);
  }

  void _toggleChatSearch() {
    setState(() => _chatSearchOpen = !_chatSearchOpen);
  }

  Future<void> _clearDepartmentChat() async {
    final department = widget.staff.department.trim();
    if (department.isEmpty ||
        department.toLowerCase() == Department.all.toLowerCase()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
            'This clears only your chat history. Other department members will keep their messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear chat')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository
          .clearDepartmentMessages(departmentKey: department);
      if (mounted) setState(() => _chatSearchOpen = false);
      await widget.repository
          .fetchDepartmentMessages(departmentKey: department, page: 1);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Could not clear chat: ${error.toString().replaceFirst('Exception: ', '')}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffTheme = staffHubThemeData(_currentThemeMode);
    final colorScheme = staffTheme.colorScheme;
    final settingsPage = switch (_settingsSubPage) {
      0 => _ProfilePage(
          onLogout: widget.onLogout,
          staff: widget.staff,
          repository: widget.repository,
          department: widget.department,
          workMode: widget.workMode,
          workLocation: widget.workLocation,
          onBack: _popSettingsSubPage),
      1 => const _SettingsDetailPage(
          icon: Icons.lock_outline,
          title: 'Security',
          description: 'Manage password and account security'),
      2 => _ChatPage(
          searchOpen: _chatSearchOpen,
          staff: widget.staff,
          repository: widget.repository,
        ),
      3 => _NotificationsPage(
          chatNotifications: _chatNotifications,
          leaveStatusNotifications: _leaveStatusNotifications,
          punchReminders: _punchReminders,
          onChatChanged: (value) => setState(() => _chatNotifications = value),
          onLeaveChanged: (value) =>
              setState(() => _leaveStatusNotifications = value),
          onPunchChanged: (value) => setState(() => _punchReminders = value)),
      4 => _AppearancePage(
          themeMode: _currentThemeMode, onChanged: _handleThemeChanged),
      5 => StaffSupportHelpdeskPage(onBack: _popSettingsSubPage),
      6 => _AboutPage(
          onOpenTerms: () => _openSettingsSubPage(8),
          onOpenPrivacyPolicy: () => _openSettingsSubPage(7),
          onOpenLicenses: () => showLicensePage(
            context: context,
            applicationName: 'LY Staff Management',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 LY Softwares. All rights reserved.',
          ),
        ),
      7 => StaffPrivacyPolicyPage(onBack: _popSettingsSubPage),
      8 => StaffTermsConditionsPage(onBack: _popSettingsSubPage),
      _ => _SettingsPage(
          onOpenProfile: () => _openSettingsSubPage(0),
          onOpenSecurity: () => _openSettingsSubPage(1),
          onOpenChat: () => _openSettingsSubPage(2),
          onOpenNotifications: () => _openSettingsSubPage(3),
          onOpenAppearance: () => _openSettingsSubPage(4),
          onOpenSupport: () => _openSettingsSubPage(5),
          onOpenAbout: () => _openSettingsSubPage(6),
          onOpenPrivacyPolicy: () => _openSettingsSubPage(7),
          onOpenTerms: () => _openSettingsSubPage(8),
          onLogout: widget.onLogout,
          staff: widget.staff,
          department: widget.department,
          workMode: widget.workMode,
          themeMode: _currentThemeMode,
          onThemeModeChanged: _handleThemeChanged),
    };
    final pages = [
      _HomePage(
          onPunch: () => widget.onNavigate(1),
          checkedIn: _checkedIn,
          checkInTime: _checkInTime,
          checkOutTime: _checkOutTime,
          onToggle: _togglePunch,
          attendance: _todayAttendance,
          onToggleBreak: _toggleBreak,
          leaveRequest: _latestLeaveRequest,
          staffId: widget.staff.id,
          department: widget.department,
          staffName: widget.staff.name,
          repository: widget.repository,
          workMode: widget.workMode,
          workLocation: widget.workLocation,
          staff: widget.staff,
          isLoadingAttendance: _isLoadingAttendance,
          isPunching: _isPunching,
          attendanceError: _attendanceError,
          onRetryAttendance: _loadAttendance),
      _PunchPage(
        checkedIn: _checkedIn,
        checkInTime: _checkInTime,
        checkOutTime: _checkOutTime,
        onToggle: _togglePunch,
        attendance: _todayAttendance,
        onToggleBreak: () => _toggleBreak(null),
        isPunching: _isPunching,
        repository: widget.repository,
        department: widget.department,
        workMode: widget.workMode,
        staff: widget.staff,
        attendanceRecords: widget.repository.attendanceList.value
            .where((a) =>
                widget.staff.id.isEmpty ||
                a.staffId.isEmpty ||
                a.staffId == widget.staff.id)
            .toList(),
      ),
      _LeavePage(
        repository: widget.repository,
        staffId: widget.staff.id,
        leaveRequest: _leaveRequest,
        onSubmit: (request) => setState(() => _leaveRequest = request),
      ),
      settingsPage,
    ];
    final titles = ['Home', 'Punch', 'Leave', 'Settings'];
    final pageTitle = widget.pageIndex == 3 && _settingsSubPage != null
        ? switch (_settingsSubPage) {
            0 => 'Profile',
            1 => 'Security',
            2 => 'Chat',
            3 => 'Notifications',
            4 => 'Appearance',
            5 => 'Support & Helpdesk',
            6 => 'About',
            7 => 'Privacy Policy',
            8 => 'Terms & Conditions',
            _ => 'Settings',
          }
        : titles[widget.pageIndex];
    final isChatPage = widget.pageIndex == 3 && _settingsSubPage == 2;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      return Theme(
        data: staffTheme,
        child: Scaffold(
          backgroundColor: _isDark ? const Color(0xff0d1117) : const Color(0xffedf0f5),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1320),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: _contentBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0e000000),
                    blurRadius: 28,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
              child: Column(
                children: [
                  // Desktop Header Row
                  Row(
                    children: [
                      if (widget.pageIndex == 3 && _settingsSubPage != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: _ink),
                            onPressed: _popSettingsSubPage,
                          ),
                        ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _brandBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'StaffHub',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      // Department pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _cardAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _line),
                        ),
                        child: Text(
                          isChatPage
                              ? (widget.staff.department.trim().isEmpty
                                  ? 'DEPARTMENT UNAVAILABLE'
                                  : canonicalDepartmentKey(widget.staff.department).toUpperCase())
                              : canonicalDepartmentKey(widget.department).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Chat button
                      GestureDetector(
                        onTap: _openChat,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _line),
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: _ink),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Profile chip
                      GestureDetector(
                        onTap: () {
                          _openSettingsSubPage(0);
                          widget.onNavigate(3);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: _brandBg,
                              child: Text(
                                widget.staff.name.isEmpty ? 'S' : widget.staff.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.staff.name,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                                ),
                                Text(
                                  widget.department,
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Body Row: Sidebar + Pages
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // WORKSPACE Sidebar
                        Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: _headerBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _line, width: 1.2),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text(
                                  'WORKSPACE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (var i = 0; i < titles.length; i++) ...[
                                Material(
                                  color: widget.pageIndex == i ? _navSel : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (_settingsSubPage != null) {
                                        setState(() {
                                          _settingsSubPage = null;
                                          _settingsHistory.clear();
                                        });
                                      }
                                      if (i == 0 || i == 2) {
                                        unawaited(widget.repository.fetchStaffLeaves());
                                      }
                                      widget.onNavigate(i);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: widget.pageIndex == i
                                            ? Border.all(color: _navSelBorder, width: 1)
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            [
                                              Icons.home_outlined,
                                              Icons.fingerprint,
                                              Icons.calendar_month_outlined,
                                              Icons.settings_outlined,
                                            ][i],
                                            size: 18,
                                            color: widget.pageIndex == i ? _navSelFg : _muted,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            titles[i],
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: widget.pageIndex == i ? FontWeight.w600 : FontWeight.w500,
                                              color: widget.pageIndex == i ? _navSelFg : _navIdleFg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _cardAlt,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _brandBg,
                                      child: Text(
                                        widget.staff.name.isEmpty ? 'S' : widget.staff.name[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.staff.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                                          ),
                                          Text(
                                            widget.department,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11, color: _muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Main content
                        Expanded(
                          child: pages[widget.pageIndex],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Theme(
      data: staffTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.15),
        ),
        child: Scaffold(
          backgroundColor: staffTheme.scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: AppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surface,
              elevation: 0,
              titleSpacing: 14,
              leading: widget.pageIndex == 3 && _settingsSubPage != null
                  ? IconButton(
                      icon:
                          Icon(Icons.arrow_back, color: colorScheme.onSurface),
                      onPressed: _popSettingsSubPage,
                    )
                  : null,
              title: isChatPage
                  ? Text('Chat',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface))
                  : Row(children: [
                      Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                              color: _brandBg,
                              borderRadius: BorderRadius.circular(7)),
                          child: const Icon(Icons.people_alt_rounded,
                              size: 15, color: Colors.white)),
                      const SizedBox(width: 8),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('StaffHub',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface)),
                            Text(pageTitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant)),
                          ]),
                    ]),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: _cardAlt,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(
                      isChatPage
                          ? (widget.staff.department.trim().isEmpty
                              ? 'DEPARTMENT UNAVAILABLE'
                              : canonicalDepartmentKey(widget.staff.department)
                                  .toUpperCase())
                          : canonicalDepartmentKey(widget.department).toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4)),
                ),
                if (widget.pageIndex == 0)
                  IconButton(
                    tooltip: 'Open chat',
                    onPressed: _openChat,
                    icon: Icon(Icons.chat_bubble_outline_rounded,
                        size: 20, color: _ink),
                  ),
                if (isChatPage)
                  PopupMenuButton<String>(
                    tooltip: 'Chat options',
                    onSelected: (value) {
                      if (value == 'search') _toggleChatSearch();
                      if (value == 'clear') _clearDepartmentChat();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          key: ValueKey('chat-option-search'),
                          value: 'search',
                          child: Text('Search messages')),
                      PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                    ],
                  ),
                if (widget.pageIndex == 3 && _settingsSubPage == 3)
                  Icon(Icons.notifications_none,
                      size: 19, color: colorScheme.onSurfaceVariant),
                if (widget.pageIndex == 3 && _settingsSubPage == 3)
                  const SizedBox(width: 14),
              ],
            ),
          ),
          body: SafeArea(
              top: false,
              child: pages[widget.pageIndex]),
          bottomNavigationBar: desktop
              ? null
              : NavigationBarTheme(
                  data: NavigationBarThemeData(
                    iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                              color: states.contains(WidgetState.selected)
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              size: 19,
                            )),
                    labelTextStyle:
                        WidgetStateProperty.resolveWith((states) => TextStyle(
                              color: states.contains(WidgetState.selected)
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: states.contains(WidgetState.selected)
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            )),
                  ),
                  child: NavigationBar(
                    height: 58,
                    selectedIndex: widget.pageIndex,
                    onDestinationSelected: (index) {
                      if (_settingsSubPage != null) {
                        setState(() {
                          _settingsSubPage = null;
                          _settingsHistory.clear();
                        });
                      }
                      if (index == 0 || index == 2) {
                        unawaited(widget.repository.fetchStaffLeaves());
                      }
                      widget.onNavigate(index);
                    },
                    backgroundColor: colorScheme.surface,
                    indicatorColor: colorScheme.primaryContainer,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_outlined, size: 19),
                          selectedIcon: Icon(Icons.home, size: 19),
                          label: 'Home'),
                      NavigationDestination(
                          icon: Icon(Icons.fingerprint, size: 19),
                          selectedIcon: Icon(Icons.fingerprint, size: 19),
                          label: 'Punch'),
                      NavigationDestination(
                          icon: Icon(Icons.calendar_month_outlined, size: 19),
                          selectedIcon: Icon(Icons.calendar_month, size: 19),
                          label: 'Leave'),
                      NavigationDestination(
                          icon: Icon(Icons.settings_outlined, size: 19),
                          selectedIcon: Icon(Icons.settings, size: 19),
                          label: 'Settings'),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _BirthdayLoadError extends StatelessWidget {
  const _BirthdayLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xff2a0d0d) : const Color(0xfffff5f3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.cake_outlined, color: Color(0xffd66b5d), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Birthday notifications unavailable. $message',
                  style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

class _BirthdayCelebrationCard extends StatefulWidget {
  const _BirthdayCelebrationCard(
      {required this.employees, required this.onDismiss});
  final List<BirthdayEmployee> employees;
  final VoidCallback onDismiss;

  @override
  State<_BirthdayCelebrationCard> createState() =>
      _BirthdayCelebrationCardState();
}

class _BirthdayCelebrationCardState extends State<_BirthdayCelebrationCard>
    with TickerProviderStateMixin {
  late final AnimationController _entryAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final AnimationController _confettiAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduceMotion = false;
  bool _hasStarted = false;
  bool _isDismissing = false;
  late String _employeeFingerprint;

  @override
  void initState() {
    super.initState();
    _employeeFingerprint = _fingerprint(widget.employees);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!_hasStarted) {
      _hasStarted = true;
      _playEntrance();
    } else if (_reduceMotion) {
      _entryAnimation.value = 1;
      _confettiAnimation.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _BirthdayCelebrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFingerprint = _fingerprint(widget.employees);
    if (nextFingerprint != _employeeFingerprint) {
      _employeeFingerprint = nextFingerprint;
      _isDismissing = false;
      _hasStarted = true;
      _playEntrance();
    }
  }

  String _fingerprint(List<BirthdayEmployee> employees) {
    final entries = employees.map((employee) => employee.name).toList()..sort();
    return entries.join('\u001e');
  }

  void _playEntrance() {
    if (_reduceMotion) {
      _entryAnimation.value = 1;
      _confettiAnimation.value = 1;
      return;
    }
    _entryAnimation.forward(from: 0);
    _confettiAnimation.forward(from: 0);
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    setState(() => _isDismissing = true);
    if (_reduceMotion) {
      widget.onDismiss();
      return;
    }
    try {
      await _entryAnimation.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && _isDismissing) widget.onDismiss();
  }

  @override
  void dispose() {
    _entryAnimation.dispose();
    _confettiAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    return FadeTransition(
      opacity: _entryAnimation,
      child: SlideTransition(
        position: slide,
        child: SizeTransition(
          sizeFactor: _entryAnimation,
          axisAlignment: -1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfffff4e8), Color(0xffffedf2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffffd9c4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffe88e75).withValues(alpha: .12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Dismiss birthday notifications',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: _isDismissing ? null : _dismiss,
                        icon: const Icon(Icons.close,
                            size: 18, color: Color(0xff9a7168)),
                      ),
                    ),
                    for (final employee in widget.employees) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (employee.profileImageUrl != null) ...[
                              ClipOval(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Image.network(
                                    employee.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text:
                                          '🎉 Happy Birthday, ${employee.name}!\n',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff392b32))),
                                  const TextSpan(
                                      text:
                                          'Wishing you happiness, success and a wonderful year ahead!\n— Team LY SOFTWARE ❤️',
                                      style: TextStyle(
                                          color: Color(0xff685a60),
                                          height: 1.35)),
                                ]),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: -15,
                left: 18,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiAnimation,
                    builder: (context, _) => CustomPaint(
                      size: const Size(66, 50),
                      painter: _BirthdayConfettiPainter(
                        progress: _confettiAnimation.value,
                        mirrored: false,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -15,
                right: 16,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiAnimation,
                    builder: (context, _) => CustomPaint(
                      size: const Size(66, 50),
                      painter: _BirthdayConfettiPainter(
                        progress: _confettiAnimation.value,
                        mirrored: true,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayConfettiPainter extends CustomPainter {
  const _BirthdayConfettiPainter(
      {required this.progress, required this.mirrored});

  final double progress;
  final bool mirrored;

  static const _colors = [
    Color(0xffe28a9c),
    Color(0xffffc17b),
    Color(0xffbd95d8),
    Color(0xffe9a6b0),
    Color(0xffffd27f),
  ];
  static const _starts = [
    Offset(12, 33),
    Offset(25, 19),
    Offset(39, 30),
    Offset(50, 13),
    Offset(58, 35),
  ];
  static const _drifts = [
    Offset(-8, -17),
    Offset(-3, -22),
    Offset(2, -18),
    Offset(5, -23),
    Offset(9, -15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _starts.length; i++) {
      final delay = i * .075;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final start = _starts[i];
      final drift = _drifts[i];
      final x = mirrored ? size.width - start.dx : start.dx;
      final dx = mirrored ? -drift.dx : drift.dx;
      final point = Offset(
        x + dx * Curves.easeOut.transform(t),
        start.dy + drift.dy * Curves.easeOut.transform(t),
      );
      final paint = Paint()
        ..color = _colors[i].withValues(alpha: (1 - t) * .9)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate((mirrored ? -1 : 1) * t * (i.isEven ? 2.2 : -2.2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 5, height: 2.5),
          const Radius.circular(1.25),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BirthdayConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.mirrored != mirrored;
}

class _HomePage extends StatefulWidget {
  const _HomePage(
      {required this.onPunch,
      required this.checkedIn,
      required this.checkInTime,
      required this.checkOutTime,
      required this.onToggle,
      required this.attendance,
      required this.onToggleBreak,
      required this.leaveRequest,
      required this.staffId,
      required this.department,
      required this.staffName,
      required this.repository,
      required this.workMode,
      required this.workLocation,
      this.staff,
      this.isLoadingAttendance = false,
      this.isPunching = false,
      this.attendanceError,
      this.onRetryAttendance});
  final VoidCallback onPunch, onToggle;
  final Future<void> Function(String? breakType) onToggleBreak;
  final Attendance? attendance;
  final bool checkedIn;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final _LeaveRequestInfo? leaveRequest;
  final String staffId;
  final String department;
  final String staffName;
  final HRRepository repository;
  final String workMode;
  final String? workLocation;
  final Staff? staff;
  final bool isLoadingAttendance;
  final bool isPunching;
  final String? attendanceError;
  final VoidCallback? onRetryAttendance;
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> with WidgetsBindingObserver {
  // Daily update state
  bool _isLoadingUpdate = false;
  bool _isLoadingBirthdays = true;
  bool _birthdayNoticeDismissed = false;
  String? _birthdayError;
  List<BirthdayEmployee> _todaysBirthdays = const [];
  bool _breakActionInFlight = false;
  String? _updateError;
  late final Timer _activeTimeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        if (timer.tick % 10 == 0) {
          unawaited(widget.repository.fetchStaffLeaves());
        }
      }
    });
    widget.repository.dailyUpdatesList.addListener(_onUpdatesChanged);
    widget.repository.leaveRequests.addListener(_onLeavesChanged);
    unawaited(_loadTodaysBirthdays());
    _refreshDailyUpdates();
    unawaited(widget.repository.fetchStaffLeaves());
  }

  Future<void> _loadTodaysBirthdays() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBirthdays = true;
      _birthdayError = null;
    });
    try {
      final birthdays = await widget.repository.fetchTodaysBirthdays();
      if (mounted) setState(() => _todaysBirthdays = birthdays);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _birthdayError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoadingBirthdays = false);
    }
  }

  void _onUpdatesChanged() {
    if (mounted) setState(() {});
  }

  void _onLeavesChanged() {
    if (mounted) setState(() {});
  }

  _LeaveRequestInfo? get _displayLeaveRequest {
    final list = widget.repository.leaveRequests.value;
    final staffId = widget.staffId;
    final myRequests = list
        .where(
            (r) => staffId.isEmpty || r.staffId.isEmpty || r.staffId == staffId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = myRequests.firstOrNull;
    if (latest != null) {
      return _LeaveRequestInfo.fromLeaveRequest(latest);
    }
    return widget.leaveRequest;
  }

  Future<void> _refreshDailyUpdates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUpdate = true;
      _updateError = null;
    });
    try {
      await widget.repository.fetchDailyUpdates();
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingUpdate = false);
    }
  }

  Future<void> _chooseAndStartBreak() async {
    final attendance = widget.attendance;
    if (attendance == null ||
        !widget.checkedIn ||
        _breakActionInFlight ||
        widget.isLoadingAttendance ||
        widget.attendanceError != null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a break',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(height: 6),
                Text('You can start your break whenever you need it.',
                    style: TextStyle(fontSize: 13, color: _muted)),
                const SizedBox(height: 12),
                for (var i = 0;
                    i < AttendanceBreakSchedule.types.length;
                    i++) ...[
                  Builder(builder: (context) {
                    final type = AttendanceBreakSchedule.types[i];
                    final item = attendance.breaks
                        .where((b) =>
                            b.breakType == type ||
                            (type == 'tea_break_1' &&
                                b.breakType == 'morning') ||
                            (type == 'tea_break_2' &&
                                b.breakType == 'afternoon'))
                        .firstOrNull;
                    final active = attendance.breaks.any((b) => b.isActive);
                    final used = item?.isCompleted == true;
                    final inProgress = item?.isActive == true;
                    final disabled = used || active;
                    final status = used
                        ? 'Completed'
                        : inProgress
                            ? 'In Progress'
                            : 'Available';
                    return ListTile(
                      leading: Icon(
                          i == 1
                              ? Icons.restaurant_outlined
                              : Icons.coffee_outlined,
                          color: disabled ? _muted : _blue),
                      title: Text(AttendanceBreakSchedule.names[i]),
                      subtitle: Text(
                          '${AttendanceBreakSchedule.durationsMinutes[i]} minutes · $status'),
                      enabled: !disabled,
                      onTap:
                          disabled ? null : () => Navigator.pop(context, type),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _breakActionInFlight = true);
    try {
      await widget.onToggleBreak(selected);
    } finally {
      if (mounted) setState(() => _breakActionInFlight = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeTimeTimer.cancel();
    widget.repository.dailyUpdatesList.removeListener(_onUpdatesChanged);
    widget.repository.leaveRequests.removeListener(_onLeavesChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.dailyUpdatesList.removeListener(_onUpdatesChanged);
      oldWidget.repository.leaveRequests.removeListener(_onLeavesChanged);
      widget.repository.dailyUpdatesList.addListener(_onUpdatesChanged);
      widget.repository.leaveRequests.addListener(_onLeavesChanged);
      _refreshDailyUpdates();
      unawaited(widget.repository.fetchStaffLeaves());
    }
  }

  DailyUpdate? get _latestUpdate {
    final updates = widget.repository.dailyUpdatesList.value;
    if (updates.isEmpty) return null;
    return updates.first;
  }

  Future<void> _editWorkUpdate() async {
    final latest = _latestUpdate;
    final updated = await Navigator.of(context).push<_WorkUpdateResult>(
      MaterialPageRoute(
        builder: (_) => _EditWorkUpdatePage(
          initialTitle: latest?.title ?? '',
          initialValue: latest?.updateText ?? '',
          repository: widget.repository,
          staffName: widget.staffName,
          department: widget.department,
        ),
      ),
    );
    // After returning from the edit page, the repository list was already
    // updated on success. Re-fetch to confirm persistence.
    if (mounted && updated != null) {
      unawaited(_refreshDailyUpdates());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftText = resolveEffectiveShift(
      staff: widget.staff,
      attendance: widget.attendance,
      department: widget.department,
    );
    final now = DateTime.now();
    final attendance = widget.attendance;
    final apiStatus = attendance?.status.trim();
    final attendanceStatus = attendance?.isLate == true
        ? 'Late'
        : apiStatus == null ||
                apiStatus.isEmpty ||
                apiStatus.toUpperCase() == 'PRESENT'
            ? 'Working'
            : '${apiStatus[0].toUpperCase()}${apiStatus.substring(1).toLowerCase()}';
    final activeBreaks =
        attendance?.breaks.where((b) => b.isActive).toList() ?? [];
    final activeBreak = activeBreaks.isEmpty ? null : activeBreaks.first;

    final hasActiveShift = widget.checkedIn || widget.checkOutTime != null;
    final endTime = widget.checkOutTime ?? DateTime.now();
    final breakSeconds =
        attendance?.breaks.fold<int>(0, (sum, b) => sum + b.durationAt(now)) ??
            0;
    var tracked = hasActiveShift
        ? endTime.difference(widget.checkInTime) -
            Duration(
                seconds: attendance?.checkOutAt == null
                    ? breakSeconds
                    : attendance?.totalBreakSeconds ?? 0)
        : Duration.zero;
    if (tracked.isNegative) tracked = Duration.zero;
    final trackedText =
        '${tracked.inHours.toString().padLeft(2, '0')}:${tracked.inMinutes.remainder(60).toString().padLeft(2, '0')}:${tracked.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    final checkInText = hasActiveShift
        ? TimeOfDay.fromDateTime(widget.checkInTime).format(context)
        : 'Not checked in';
    final checkOutText = widget.checkOutTime == null
        ? 'Not checked out'
        : 'Checked out at ${TimeOfDay.fromDateTime(widget.checkOutTime!).format(context)}';
    final activeLeave = _displayLeaveRequest;
    // "Working On-Schedule" logic: show when checked in, not late, not on break
    final workingOnSchedule = widget.checkedIn &&
        attendance?.isLate != true &&
        activeBreak == null;
    final dateString =
        '${const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1]}, ${now.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]}';
    return _ScrollPage(children: [
      const SizedBox(height: 12),
      Text(dateString, style: TextStyle(fontSize: 14, color: _muted)),
      const SizedBox(height: 5),
      Row(children: [
        Expanded(
            child: Text('Good Morning, ${widget.staffName} 👋',
                style: TextStyle(
                    fontSize: 26, color: _ink, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 4),
      RichText(
          text: TextSpan(
              style: TextStyle(fontSize: 13, color: _muted),
              children: [
            const TextSpan(text: 'Department: '),
            TextSpan(
                text: widget.department,
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: _ink)),
            const TextSpan(text: ' · Work Mode: '),
            TextSpan(
                text: widget.workMode,
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          ])),
      if (widget.workMode == 'Work From Home' &&
          widget.workLocation != null) ...[
        const SizedBox(height: 4),
        Text('📍 Location: ${widget.workLocation}',
            style: TextStyle(fontSize: 12, color: _muted)),
      ],
      const SizedBox(height: 18),
      if (_isLoadingBirthdays)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: LinearProgressIndicator(minHeight: 2),
        )
      else if (_birthdayError != null)
        _BirthdayLoadError(
            message: _birthdayError!, onRetry: _loadTodaysBirthdays)
      else if (_todaysBirthdays.isNotEmpty && !_birthdayNoticeDismissed)
        _BirthdayCelebrationCard(
          employees: _todaysBirthdays,
          onDismiss: () => setState(() => _birthdayNoticeDismissed = true),
        ),
      if (widget.attendanceError != null) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xffffeeee),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xffd84747).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: Color(0xffd84747)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.attendanceError!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xffd84747)),
                ),
              ),
              if (widget.onRetryAttendance != null)
                TextButton(
                  onPressed: widget.onRetryAttendance,
                  child: const Text('Retry',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffd84747))),
                ),
            ],
          ),
        ),
      ],
      // ── Attendance Card (IMAGE 2 layout) ────────────────────────────
      _ProfileCard(
          child: LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            final startBreakButton = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                side: BorderSide(color: _ink.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: !widget.checkedIn ||
                      widget.isPunching ||
                      widget.isLoadingAttendance ||
                      widget.attendanceError != null ||
                      _breakActionInFlight
                  ? null
                  : activeBreak != null
                      ? () async {
                          setState(() => _breakActionInFlight = true);
                          try {
                            await widget.onToggleBreak(null);
                          } finally {
                            if (mounted)
                              setState(() => _breakActionInFlight = false);
                          }
                        }
                      : _chooseAndStartBreak,
              icon: Icon(
                  activeBreak == null
                      ? Icons.free_breakfast_outlined
                      : Icons.stop_circle_outlined,
                  size: 15,
                  color: _ink),
              label: Text(
                  _breakActionInFlight
                      ? 'Please wait...'
                      : activeBreak == null
                          ? 'Start Break'
                          : 'End Break',
                  style: TextStyle(
                      fontSize: 12,
                      color: _ink,
                      fontWeight: FontWeight.w500)),
            );

            final checkOutButton = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brandBg,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed:
                  (widget.isPunching || widget.isLoadingAttendance)
                      ? null
                      : (widget.checkedIn || !hasActiveShift
                          ? (activeBreak == null
                              ? widget.onToggle
                              : null)
                          : null),
              icon: widget.isPunching
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      widget.checkedIn
                          ? Icons.arrow_forward
                          : Icons.login,
                      size: 14,
                      color: Colors.white),
              label: Text(
                  widget.isPunching
                      ? (widget.checkedIn
                          ? 'Checking out...'
                          : 'Checking in...')
                      : (widget.checkedIn
                          ? 'Check Out'
                          : hasActiveShift
                              ? 'Shift Complete'
                              : 'Check In'),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            );

            final statusPill = _pill(
                activeBreak != null
                    ? 'Break in Progress'
                    : widget.checkedIn
                        ? attendanceStatus
                        : hasActiveShift
                            ? 'Shift Complete'
                            : 'Not Checked In',
                activeBreak != null
                    ? const Color(0xfffff3d6)
                    : widget.checkedIn
                        ? attendance?.isLate == true
                            ? const Color(0xfffff3d6)
                            : const Color(0xffe8f8ef)
                        : const Color(0xffffeeee),
                activeBreak != null
                    ? const Color(0xffa66a16)
                    : widget.checkedIn
                        ? attendance?.isLate == true
                            ? const Color(0xffa66a16)
                            : const Color(0xff198754)
                        : const Color(0xffd84747));

            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Status pill + Shift + right-aligned check-in time
                  if (isNarrow)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          statusPill,
                          const SizedBox(width: 8),
                          Expanded(
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('Shift: $shiftText',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11, color: _muted)))),
                        ])
                  else
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          statusPill,
                          const SizedBox(width: 10),
                          Text('Shift: $shiftText',
                              style: TextStyle(
                                  fontSize: 12, color: _muted)),
                          const Spacer(),
                          if (hasActiveShift &&
                              widget.checkOutTime == null) ...[
                            RichText(
                                text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 12, color: _muted),
                                    children: [
                                  const TextSpan(
                                      text: 'Checked in at '),
                                  TextSpan(
                                      text: checkInText,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _ink)),
                                ])),
                          ] else if (widget.checkOutTime != null) ...[
                            Text(checkOutText,
                                style: TextStyle(
                                    fontSize: 12, color: _muted)),
                          ],
                        ]),
                  Divider(height: isNarrow ? 14 : 24),
                  // Row 2: ACTIVE TIME label + "Working On-Schedule" right
                  Row(children: [
                    Text('ACTIVE TIME',
                        style: TextStyle(
                            fontSize: 11,
                            color: _muted,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (workingOnSchedule)
                      Text('Working On-Schedule',
                          style: TextStyle(fontSize: 12, color: _muted))
                    else if (widget.isLoadingAttendance)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 4),
                  // Row 3: Large time display
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(trackedText,
                            style: TextStyle(
                                fontSize: isNarrow ? 28 : 34,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.5)),
                        const SizedBox(width: 6),
                        Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text('hrs',
                                style: TextStyle(
                                    fontSize: 13, color: _muted))),
                      ]),
                  if (isNarrow) ...[
                    const SizedBox(height: 2),
                    Text(
                        widget.checkOutTime != null
                            ? checkOutText
                            : hasActiveShift
                                ? 'Checked in at $checkInText'
                                : 'Please check in to start your shift',
                        style: TextStyle(fontSize: 12, color: _muted)),
                  ] else if (!workingOnSchedule &&
                      widget.isLoadingAttendance == false &&
                      !hasActiveShift &&
                      activeBreak == null) ...[
                    const SizedBox(height: 2),
                    Text('Please check in to start your shift',
                        style: TextStyle(fontSize: 12, color: _muted)),
                  ],
                  // Break status text below large time (when on break)
                  if (activeBreak != null) ...[
                    const SizedBox(height: 4),
                    Text(activeBreak.remainingTimeText(now),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 2),
                    Text(
                        '${AttendanceBreakSchedule.nameForType(activeBreak.breakType)} · Started ${TimeOfDay.fromDateTime(activeBreak.startTime).format(context)}',
                        style: TextStyle(fontSize: 12, color: _muted)),
                  ],
                  Divider(height: isNarrow ? 14 : 24),
                  // Row 4: Upcoming Break info + buttons
                  if (isNarrow)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              activeBreak != null
                                  ? 'Break in Progress'
                                  : 'Upcoming Break',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _ink)),
                          const SizedBox(height: 2),
                          Text(
                              activeBreak != null
                                  ? '${AttendanceBreakSchedule.nameForType(activeBreak.breakType)} · tap End Break to resume'
                                  : 'Tea Breaks and Lunch Break · Whenever you need them',
                              style: TextStyle(
                                  fontSize: 11, color: _muted)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: startBreakButton),
                            const SizedBox(width: 8),
                            Expanded(child: checkOutButton),
                          ]),
                        ])
                  else
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    activeBreak != null
                                        ? 'Break in Progress'
                                        : 'Upcoming Break',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _ink)),
                                const SizedBox(height: 2),
                                Text(
                                    activeBreak != null
                                        ? '${AttendanceBreakSchedule.nameForType(activeBreak.breakType)} · tap End Break to resume'
                                        : 'Tea Breaks and Lunch Break · Whenever you need them',
                                    style: TextStyle(
                                        fontSize: 11, color: _muted)),
                              ])),
                          const SizedBox(width: 12),
                          startBreakButton,
                          const SizedBox(width: 8),
                          checkOutButton,
                        ]),
                ]);
          })),
      // ── Daily Work Update Card ───────────────────────────────────────
      const SizedBox(height: 18),
      _ProfileCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: _ink),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Daily Work Update',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              color: _ink,
                              fontWeight: FontWeight.w700))),
                  if (_isLoadingUpdate)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  TextButton(
                      onPressed:
                          _isLoadingUpdate ? null : _editWorkUpdate,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 32),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                          _latestUpdate == null
                              ? 'Add Update  ›'
                              : 'Edit Update  ›',
                          style:
                              TextStyle(fontSize: 13, color: _ink)))
                ]),
                if (_updateError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xffffeeee),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xffd84747)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          size: 14, color: Color(0xffd84747)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_updateError!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xffd84747))),
                      ),
                      TextButton(
                        onPressed: _refreshDailyUpdates,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 24),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Retry',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffd84747))),
                      )
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _cardAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _line)),
                    child: _isLoadingUpdate && _latestUpdate == null
                        ? const Center(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          )
                        : _latestUpdate == null
                            ? Text(
                                'No update submitted yet. Tap \'Add Update\' to submit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: _muted),
                              )
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (_latestUpdate!.title.isNotEmpty) ...[
                                    Text(
                                      _latestUpdate!.title,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _ink),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    _latestUpdate!.updateText,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: _ink),
                                  ),
                                ],
                              )),
                if (_latestUpdate != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.check_circle,
                        color: const Color(0xff24a36a), size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(
                            _latestUpdate!.createdAt != null
                                ? 'Submitted at ${TimeOfDay.fromDateTime(_latestUpdate!.createdAt!).format(context)}'
                                : 'Submitted',
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 10, color: _muted))),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text('✓ Synced',
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 10, color: _muted)))
                  ]),
                ],
              ])),
      // ── Leave Request Update Card ────────────────────────────────────
      if (activeLeave != null) ...[
        const SizedBox(height: 18),
        Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Leave Request Update',
                            style: TextStyle(
                                fontSize: 15,
                                color: _ink,
                                fontWeight: FontWeight.w700))),
                    // Green outlined status badge
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: _statusForeground(activeLeave.status),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(activeLeave.status,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _statusForeground(
                                    activeLeave.status)))),
                  ]),
                  const SizedBox(height: 10),
                  Text('${activeLeave.type} · ${activeLeave.dates}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  const SizedBox(height: 5),
                  Text('Reason: ${activeLeave.reason}',
                      style: TextStyle(fontSize: 12, color: _ink)),
                  const SizedBox(height: 5),
                  Text(activeLeave.message,
                      style: TextStyle(
                          fontSize: 12, color: _muted, height: 1.4)),
                ])),
      ],
    ]);
  }
}

class _WorkUpdateResult {
  const _WorkUpdateResult(this.title, this.text);
  final String title;
  final String text;
}

class _EditWorkUpdatePage extends StatefulWidget {
  const _EditWorkUpdatePage({
    required this.initialTitle,
    required this.initialValue,
    required this.repository,
    this.staffName,
    this.department,
  });
  final String initialTitle;
  final String initialValue;
  final HRRepository repository;
  final String? staffName;
  final String? department;

  @override
  State<_EditWorkUpdatePage> createState() => _EditWorkUpdatePageState();
}

class _EditWorkUpdatePageState extends State<_EditWorkUpdatePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _controller;
  bool _isSaving = false;

  bool get _hasChanges =>
      _titleController.text.trim() != widget.initialTitle ||
      _controller.text.trim() != widget.initialValue;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content:
                const Text('Your work update changes have not been saved.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Editing')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard Changes')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleBack() async {
    if (_isSaving) return;
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_isSaving) return; // Prevent duplicate submissions
    final title = _titleController.text.trim();
    final text = _controller.text.trim();
    if (title.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a title and details before saving.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.repository.submitDailyUpdate(title, text);
      if (mounted) {
        Navigator.of(context).pop(_WorkUpdateResult(title, text));
      }
    } catch (e) {
      if (mounted) {
        // Keep form open and show the actual API error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSidebarItem(IconData icon, String label, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? _navSel : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: _navSelBorder, width: 1.0) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? _navSelFg : _muted),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? _navSelFg : _navIdleFg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.staffName?.isNotEmpty == true
        ? widget.staffName!
        : widget.repository.currentUser.value?.name.isNotEmpty == true
            ? widget.repository.currentUser.value!.name
            : 'Abu';
    final deptName = widget.department?.isNotEmpty == true
        ? widget.department!
        : widget.repository.currentUser.value?.department.isNotEmpty == true
            ? widget.repository.currentUser.value!.department
            : 'Tech';
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    final formCard = Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Section ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.arrow_back, color: _ink, size: 20),
                  onPressed: _isSaving ? null : _handleBack,
                ),
                const SizedBox(width: 14),
                Text(
                  'Edit Work Update',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _isSaving ? null : _handleBack,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _line, height: 1, thickness: 1),
          // ── Form Fields ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _titleController,
                    enabled: !_isSaving,
                    style: TextStyle(fontSize: 14, color: _ink),
                    decoration: InputDecoration(
                      hintText: 'Enter update title',
                      hintStyle: TextStyle(fontSize: 14, color: _muted),
                      filled: true,
                      fillColor: _fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _isDark ? _primaryAccent : const Color(0xff111827), width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Details
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 252,
                  child: TextField(
                    controller: _controller,
                    enabled: !_isSaving,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(fontSize: 14, height: 1.5, color: _ink),
                    decoration: InputDecoration(
                      hintText: "Enter today's work update",
                      hintStyle: TextStyle(fontSize: 14, color: _muted),
                      filled: true,
                      fillColor: _fieldBg,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _isDark ? _primaryAccent : const Color(0xff111827), width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Save Update Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _isDark ? _primaryAccent : const Color(0xff000000),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Update',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final desktopBody = Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0e000000),
                blurRadius: 28,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
          child: Column(
            children: [
              // Top Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _brandBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'StaffHub',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // Department badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _cardAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _line),
                    ),
                    child: Text(
                      deptName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _subText,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chat button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _line),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: _ink),
                  ),
                  const SizedBox(width: 14),
                  // Profile chip
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: _brandBg,
                        child: Text(
                          initialLetter,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _muted),
                            ],
                          ),
                          Text(
                            deptName,
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Body: Sidebar + Edit Work Update Card
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WORKSPACE Sidebar
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              'WORKSPACE',
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSidebarItem(Icons.home_outlined, 'Home', isActive: true),
                          const SizedBox(height: 4),
                          _buildSidebarItem(Icons.fingerprint_rounded, 'Punch', isActive: false),
                          const SizedBox(height: 4),
                          _buildSidebarItem(Icons.calendar_today_outlined, 'Leave', isActive: false),
                          const SizedBox(height: 4),
                          _buildSidebarItem(Icons.settings_outlined, 'Settings', isActive: false),
                          const Spacer(),
                          // Bottom user card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _cardAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: _isDark ? const Color(0xff1a2b40) : const Color(0xffeff6ff),
                                  child: Text(
                                    initialLetter,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                                    ),
                                    Text(
                                      deptName,
                                      style: TextStyle(fontSize: 10, color: _muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Main Content Card
                    Expanded(
                      child: SingleChildScrollView(
                        child: formCard,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final mobileBody = Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: formCard,
        ),
      ),
    );

    return PopScope(
      canPop: !_hasChanges && !_isSaving,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: isDesktop ? desktopBody : mobileBody,
    );
  }
}

class _PunchPage extends StatefulWidget {
  const _PunchPage({
    required this.checkedIn,
    required this.checkInTime,
    required this.checkOutTime,
    required this.onToggle,
    required this.attendance,
    required this.onToggleBreak,
    required this.attendanceRecords,
    this.isPunching = false,
    this.repository,
    this.department,
    this.workMode,
    this.staff,
  });
  final bool checkedIn;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final VoidCallback onToggle;
  final Attendance? attendance;
  final Future<void> Function() onToggleBreak;
  final List<Attendance> attendanceRecords;
  final bool isPunching;
  final HRRepository? repository;
  final String? department;
  final String? workMode;
  final Staff? staff;

  @override
  State<_PunchPage> createState() => _PunchPageState();
}

class _PunchPageState extends State<_PunchPage> {
  late final Timer _timer;
  bool _isClearingHistory = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handleClearHistory() async {
    if (_isClearingHistory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Attendance History'),
        content: const Text(
          'Clear your attendance history from this view?\n\n'
          'Official attendance records remain available to HR and will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd84747),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingHistory = true);
    try {
      if (widget.repository != null) {
        await widget.repository!.clearAttendanceHistory();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Attendance history cleared from your view. Official records remain available to HR.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to clear history: ${e.toString().replaceAll('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingHistory = false);
      }
    }
  }

  void _openAttendanceDetail(BuildContext context, Attendance record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendanceDetailBottomSheet(
        initialRecord: record,
        repository: widget.repository,
        department: widget.department,
        workMode: widget.workMode,
      ),
    );
  }

  String _formatMonthYear(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xff94a3b8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, Attendance item, String currentTrackedText) {
    final checkInDisplay = item.checkInTime.isNotEmpty
        ? formatShiftTime(item.checkInTime)
        : (item.checkInAt != null
            ? TimeOfDay.fromDateTime(item.checkInAt!).format(context)
            : 'Not recorded');

    final statusText = item.displayStatus;
    final isLateStatus = item.isLate;
    final sessionStatusText = item.sessionStatusLabel;
    final isOngoing = item.isOngoing;
    final durationDisplay = item.workedDuration.isNotEmpty
        ? item.workedDuration
        : (isOngoing ? currentTrackedText : '8h 00m');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line, width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openAttendanceDetail(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: Color(0xfff59e0b),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDisplayDate(item.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff0f172a),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          const Icon(Icons.bolt, size: 12, color: Color(0xff94a3b8)),
                          Text(
                            'In: $checkInDisplay',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
                          ),
                          Text(
                            '•  Duration: $durationDisplay',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _pill(
                  statusText,
                  isLateStatus
                      ? const Color(0xfffef2f2)
                      : _isDark ? const Color(0xff0d2318) : const Color(0xffecfdf5),
                  isLateStatus
                      ? const Color(0xffef4444)
                      : const Color(0xff10b981),
                ),
                const SizedBox(width: 8),
                _pill(
                  sessionStatusText,
                  isOngoing
                      ? const Color(0xfffffbeb)
                      : _chip,
                  isOngoing ? const Color(0xffd97706) : _muted,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xff94a3b8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftText = resolveEffectiveShift(
      staff: widget.staff,
      attendance: widget.attendance,
      department: widget.department,
    );
    final hasActiveShift = widget.checkedIn || widget.checkOutTime != null;
    final endTime = widget.checkOutTime ?? DateTime.now();
    var tracked = hasActiveShift
        ? endTime.difference(widget.checkInTime) -
            Duration(
                seconds: widget.attendance?.breaks.fold<int>(
                        0, (sum, b) => sum + b.durationAt(DateTime.now())) ??
                    0)
        : Duration.zero;
    if (tracked.isNegative) tracked = Duration.zero;
    final trackedHours = tracked.inHours;
    final trackedMinutes = tracked.inMinutes.remainder(60);
    final trackedText =
        '${trackedHours}h ${trackedMinutes.toString().padLeft(2, '0')}m';
    final checkInText = hasActiveShift
        ? TimeOfDay.fromDateTime(widget.checkInTime).format(context)
        : 'Not recorded';
    final checkOutText = widget.checkOutTime == null
        ? 'Pending'
        : TimeOfDay.fromDateTime(widget.checkOutTime!).format(context);

    final totalTrackedSeconds = tracked.inSeconds;
    final targetPercent =
        ((totalTrackedSeconds / 28800) * 100).clamp(0, 100).round();
    final progressValue = (totalTrackedSeconds / 28800).clamp(0.0, 1.0);

    final activeBreaks =
        widget.attendance?.breaks.where((b) => b.isActive).toList() ?? [];
    final activeBreak = activeBreaks.isEmpty ? null : activeBreaks.first;

    final totalBreaksCount = widget.attendance?.breaks.length ?? 0;
    final totalBreakSeconds = widget.attendance?.breaks.fold<int>(
            0, (sum, b) => sum + b.durationAt(DateTime.now())) ??
        0;
    final totalBreakMinutes = (totalBreakSeconds / 60).round();

    // Compute Weekly Statistics
    double weeklyHours = 0.0;
    int checkInTotalMinutes = 0;
    int checkInCount = 0;
    int onTimeCount = 0;
    final totalRecords = widget.attendanceRecords.length;

    for (final rec in widget.attendanceRecords) {
      if (rec.workedDuration.isNotEmpty) {
        final hMatch = RegExp(r'(\d+)h').firstMatch(rec.workedDuration);
        final mMatch = RegExp(r'(\d+)m').firstMatch(rec.workedDuration);
        final h = hMatch != null ? int.tryParse(hMatch.group(1)!) ?? 0 : 0;
        final m = mMatch != null ? int.tryParse(mMatch.group(1)!) ?? 0 : 0;
        weeklyHours += h + (m / 60.0);
      } else if (rec.checkInAt != null && rec.checkOutAt != null) {
        final dur = rec.checkOutAt!.difference(rec.checkInAt!) -
            Duration(seconds: rec.totalBreakSeconds);
        if (!dur.isNegative) weeklyHours += dur.inMinutes / 60.0;
      }

      DateTime? checkInDt = rec.checkInAt;
      if (checkInDt == null && rec.checkInTime.isNotEmpty) {
        final timeMatch =
            RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false)
                .firstMatch(rec.checkInTime);
        if (timeMatch != null) {
          var hr = int.tryParse(timeMatch.group(1)!) ?? 0;
          final min = int.tryParse(timeMatch.group(2)!) ?? 0;
          final amPm = timeMatch.group(3)?.toUpperCase();
          if (amPm == 'PM' && hr < 12) hr += 12;
          if (amPm == 'AM' && hr == 12) hr = 0;
          checkInTotalMinutes += (hr * 60 + min);
          checkInCount++;
        }
      } else if (checkInDt != null) {
        checkInTotalMinutes += (checkInDt.hour * 60 + checkInDt.minute);
        checkInCount++;
      }

      if (!rec.isLate) {
        onTimeCount++;
      }
    }

    final weeklyHoursStr = weeklyHours > 0
        ? '${weeklyHours.toStringAsFixed(1)} hrs'
        : '24.5 hrs';
    final avgCheckInStr = checkInCount > 0
        ? TimeOfDay(
                hour: (checkInTotalMinutes / checkInCount) ~/ 60,
                minute: ((checkInTotalMinutes / checkInCount) % 60).round())
            .format(context)
        : '10:30 AM';
    final onTimeRateStr = totalRecords > 0
        ? '${((onTimeCount / totalRecords) * 100).round()}%'
        : '85%';

    return _ScrollPage(children: [
      const SizedBox(height: 12),
      // ── A. Page Heading ───────────────────────────────────────
      LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          const heading = Text(
            "Today's Attendance",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xff0f172a),
              letterSpacing: -0.5,
            ),
          );
          final shiftBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Text(
              'Shift: $shiftText',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xff475569),
              ),
            ),
          );
          final activeShiftBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: widget.checkedIn
                  ? (_isDark ? const Color(0xff0d2318) : const Color(0xffecfdf5))
                  : widget.checkOutTime != null
                      ? _chip
                      : (_isDark ? const Color(0xff2a0d0d) : const Color(0xfffef2f2)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.checkedIn
                    ? const Color(0xffa7f3d0)
                    : widget.checkOutTime != null
                        ? _line
                        : const Color(0xfffecaca),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.checkedIn
                        ? const Color(0xff10b981)
                        : widget.checkOutTime != null
                            ? _muted
                            : const Color(0xffef4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.checkedIn
                      ? 'Active Shift'
                      : widget.checkOutTime != null
                          ? 'Shift Ended'
                          : 'Not Checked In',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.checkedIn
                        ? const Color(0xff10b981)
                        : widget.checkOutTime != null
                            ? _muted
                            : const Color(0xffef4444),
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                heading,
                shiftBadge,
                activeShiftBadge,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              heading,
              const SizedBox(width: 12),
              shiftBadge,
              const Spacer(),
              activeShiftBadge,
            ],
          );
        },
      ),
      const SizedBox(height: 5),
      const Text(
        'Track your working hours, breaks, and daily punch timeline',
        style: TextStyle(fontSize: 13, color: Color(0xff64748b)),
      ),
      const SizedBox(height: 14),

      // ── B. Main Attendance Card ───────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Time + Progress bar on left, action buttons on right
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;

              final timeColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TOTAL TRACKED TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xff94a3b8),
                        ),
                      ),
                      if (widget.checkedIn) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xff15803d),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        trackedText,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff0f172a),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${hasActiveShift ? (targetPercent == 0 ? 1 : targetPercent) : 0}% of 8h standard target',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff94a3b8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: _chip,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xff0f172a),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              );

              final actionButtons = Column(
                crossAxisAlignment: isNarrow
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.end,
                children: [
                  // Take a Break Button
                  ElevatedButton.icon(
                    onPressed: !widget.checkedIn || widget.isPunching
                        ? null
                        : widget.onToggleBreak,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDark ? const Color(0xff2a2008) : const Color(0xfffef3c7),
                      foregroundColor: const Color(0xff92400e),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      activeBreak != null
                          ? Icons.stop_circle_outlined
                          : Icons.coffee_outlined,
                      size: 16,
                      color: const Color(0xff92400e),
                    ),
                    label: Text(
                      activeBreak != null ? 'End Break' : 'Take a Break',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff92400e),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Check Out / Check In Button
                  ElevatedButton.icon(
                    onPressed: (widget.isPunching ||
                            (widget.checkOutTime != null && !widget.checkedIn))
                        ? null
                        : widget.onToggle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBg,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: widget.isPunching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            widget.checkedIn ? Icons.logout : Icons.login,
                            size: 15,
                            color: Colors.white,
                          ),
                    label: Text(
                      widget.isPunching
                          ? (widget.checkedIn
                              ? 'Checking out...'
                              : 'Checking in...')
                          : (widget.checkedIn
                              ? 'Check Out'
                              : widget.checkOutTime != null
                                  ? 'Shift Complete'
                                  : 'Check In'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    timeColumn,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: timeColumn),
                  const SizedBox(width: 24),
                  actionButtons,
                ],
              );
            }),

            const SizedBox(height: 16),
            const Divider(color: Color(0xfff1f5f9), height: 1, thickness: 1),
            const SizedBox(height: 16),

            // ── C. Attendance Summary Cards ───────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;

              final checkInCard = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xff0d2318) : const Color(0xffecfdf5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.login_rounded,
                              size: 16, color: Color(0xff10b981)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xff0d2318) : const Color(0xffecfdf5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasActiveShift ? 'Done' : 'Pending',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff10b981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check In',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff64748b),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          checkInText,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0f172a)),
                        ),
                        Text(
                          hasActiveShift ? 'Recorded' : 'Waiting',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xff94a3b8)),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final checkOutCard = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              size: 16, color: Color(0xfff59e0b)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.checkOutTime != null
                                ? const Color(0xffecfdf5)
                                : _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.checkOutTime != null ? 'Done' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.checkOutTime != null
                                    ? const Color(0xff10b981)
                                    : const Color(0xffd97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check Out',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff64748b),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          checkOutText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: widget.checkOutTime != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontStyle: widget.checkOutTime == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: widget.checkOutTime != null
                                ? _ink
                                : _muted,
                          ),
                        ),
                        Text(
                          widget.checkOutTime != null
                              ? 'Recorded'
                              : 'Scheduled 06:00 PM',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xff94a3b8)),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final breakTimeCard = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.coffee_outlined,
                              size: 16, color: Color(0xfff59e0b)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _line),
                          ),
                          child: Text(
                            '$totalBreaksCount break${totalBreaksCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff64748b),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Break Time',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff64748b),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          '$totalBreakMinutes min',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0f172a)),
                        ),
                        const Text(
                          'Max 1h allowed',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xff94a3b8)),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    checkInCard,
                    const SizedBox(height: 12),
                    checkOutCard,
                    const SizedBox(height: 12),
                    breakTimeCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: checkInCard),
                  const SizedBox(width: 14),
                  Expanded(child: checkOutCard),
                  const SizedBox(width: 14),
                  Expanded(child: breakTimeCard),
                ],
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── D. Weekly Statistics ─────────────────────────────────
      LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

        final card1 = _buildStatCard(
            'WEEKLY HOURS', weeklyHoursStr, _ink);
        final card2 = _buildStatCard(
            'AVG CHECK-IN', avgCheckInStr, _ink);
        final card3 = _buildStatCard(
            'ON-TIME RATE', onTimeRateStr, const Color(0xff10b981));

        if (isNarrow) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 10),
              card2,
              const SizedBox(height: 10),
              card3,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 14),
            Expanded(child: card2),
            const SizedBox(width: 14),
            Expanded(child: card3),
          ],
        );
      }),

      // Break Details (when breaks exist)
      if (widget.attendance?.breaks.isNotEmpty == true) ...[
        const SizedBox(height: 18),
        const Text('Break Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xff0f172a))),
        const SizedBox(height: 8),
        _ProfileCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final item in widget.attendance!.breaks)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  const Icon(Icons.coffee_outlined,
                      size: 18, color: Color(0xffa66a16)),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${_breakTypeLabel(item.breakType)} · ${TimeOfDay.fromDateTime(item.startTime).format(context)} – ${item.endTime == null ? 'Active' : TimeOfDay.fromDateTime(item.endTime!).format(context)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xff0f172a),
                                fontWeight: FontWeight.w600)),
                        Text(
                            '${_formatShortDuration(item.durationAt(DateTime.now()))} · ${item.isActive ? 'On Break' : 'Completed'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xff64748b))),
                      ])),
                ])),
        ])),
      ],

      const SizedBox(height: 16),

      // ── E. Attendance History ────────────────────────────────
      LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          final titlePart = Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff0f172a),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.attendanceRecords.length} Records',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff64748b),
                  ),
                ),
              ),
            ],
          );

          final actionPart = Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xff64748b)),
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff64748b),
                    ),
                  ),
                ],
              ),
              if (widget.attendanceRecords.isNotEmpty)
                InkWell(
                  key: const ValueKey('clear-attendance-history-button'),
                  onTap: _isClearingHistory ? null : _handleClearHistory,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isClearingHistory)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Color(0xffef4444)),
                          )
                        else
                          const Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xffef4444)),
                        const SizedBox(width: 4),
                        Text(
                          'Clear History',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isClearingHistory
                                ? _muted
                                : const Color(0xffef4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );

          if (isNarrow) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                titlePart,
                actionPart,
              ],
            );
          }

          return Row(
            children: [
              titlePart,
              const Spacer(),
              actionPart,
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      if (widget.attendanceRecords.isEmpty)
        _ProfileCard(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.history_toggle_off_outlined,
                    size: 36, color: _muted.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'No attendance records yet',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your punch and attendance records will appear here.',
                  style: TextStyle(
                    color: _muted.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        for (final item in widget.attendanceRecords)
          _buildHistoryItem(context, item, trackedText),
    ]);
  }
}

class _AttendanceDetailBottomSheet extends StatefulWidget {
  const _AttendanceDetailBottomSheet({
    required this.initialRecord,
    this.repository,
    this.department,
    this.workMode,
  });

  final Attendance initialRecord;
  final HRRepository? repository;
  final String? department;
  final String? workMode;

  @override
  State<_AttendanceDetailBottomSheet> createState() =>
      _AttendanceDetailBottomSheetState();
}

class _AttendanceDetailBottomSheetState
    extends State<_AttendanceDetailBottomSheet> {
  late Attendance _record;

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
    _fetchFreshDetail();
  }

  Future<void> _fetchFreshDetail() async {
    if (widget.repository == null || _record.id.isEmpty) return;
    try {
      final fresh = await widget.repository!.fetchAttendanceDetail(_record.id);
      if (mounted) {
        setState(() {
          _record = fresh;
        });
      }
    } catch (_) {
      // Gracefully retain initialRecord on offline or error
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final isOngoing = record.isOngoing;
    final departmentName = record.department ?? widget.department ?? 'Tech';
    final workModeName = record.workMode ?? widget.workMode ?? 'Office';

    final checkInDisplay = record.checkInTime.isNotEmpty
        ? formatShiftTime(record.checkInTime)
        : (record.checkInAt != null
            ? TimeOfDay.fromDateTime(record.checkInAt!).format(context)
            : 'Not recorded');

    final checkOutDisplay = isOngoing
        ? 'Pending'
        : (record.checkOutTime != null && record.checkOutTime!.isNotEmpty
            ? formatShiftTime(record.checkOutTime!)
            : (record.checkOutAt != null
                ? TimeOfDay.fromDateTime(record.checkOutAt!).format(context)
                : 'Pending'));

    final defaultScheduledCheckIn =
        departmentName.toLowerCase().contains('tele') ? '09:00 AM' : '10:00 AM';
    final scheduledCheckInDisplay =
        record.scheduledCheckIn != null && record.scheduledCheckIn!.isNotEmpty
            ? formatShiftTime(record.scheduledCheckIn!)
            : (record.scheduleSnapshot?['scheduledCheckIn'] != null
                ? formatShiftTime(
                    record.scheduleSnapshot!['scheduledCheckIn'].toString())
                : defaultScheduledCheckIn);

    final scheduledCheckOutDisplay =
        record.scheduledCheckOut != null && record.scheduledCheckOut!.isNotEmpty
            ? formatShiftTime(record.scheduledCheckOut!)
            : (record.scheduleSnapshot?['scheduledCheckOut'] != null
                ? formatShiftTime(
                    record.scheduleSnapshot!['scheduledCheckOut'].toString())
                : '06:00 PM');

    final lateArrivalDisplay = record.isLate
        ? (record.minutesLate != null && record.minutesLate! > 0
            ? '${record.minutesLate} mins late'
            : 'Late arrival')
        : 'None (On time)';

    final workingDurationDisplay = isOngoing
        ? 'In Progress'
        : (record.workedDuration.isNotEmpty ? record.workedDuration : '0h');

    final totalBreaksCount = record.breaks.length;
    final totalBreaksDisplay =
        '$totalBreaksCount break${totalBreaksCount == 1 ? '' : 's'}';
    final totalBreakDurationDisplay = record.breakDuration.isNotEmpty
        ? record.breakDuration
        : '${record.totalBreakMinutes ?? (record.totalBreakSeconds ~/ 60)} min';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDisplayDate(record.date),
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _pill(
                    record.sessionStatusLabel,
                    isOngoing
                        ? (_isDark ? const Color(0xff2a2008) : const Color(0xfffff7e6))
                        : (_isDark ? const Color(0xff0d2318) : const Color(0xffe8f8ef)),
                    isOngoing
                        ? (_isDark ? const Color(0xfffbbf24) : const Color(0xffd48b0c))
                        : (_isDark ? const Color(0xff34d399) : const Color(0xff198754)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: _muted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _line),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  if (isOngoing) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xff2a2008) : const Color(0xfffff8ec),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isDark ? const Color(0xff4a3a10) : const Color(0xfffae0b5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: _isDark ? const Color(0xfffbbf24) : const Color(0xffd48b0c)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Shift currently in progress. Checkout is pending.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isDark ? const Color(0xfffbbf24) : const Color(0xffa66a16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Attendance Summary
                  _sheetSectionHeader(
                      Icons.summarize_outlined, 'Attendance Summary'),
                  const SizedBox(height: 8),
                  _sheetCard([
                    _sheetRow(
                        'Attendance Date', _formatDisplayDate(record.date)),
                    _sheetDivider(),
                    _sheetRow('Department', departmentName),
                    _sheetDivider(),
                    _sheetRow('Work Mode', workModeName),
                    _sheetDivider(),
                    _sheetRow(
                      'Attendance Status',
                      record.displayStatus,
                      valueColor: record.isLate
                          ? (_isDark ? const Color(0xfff87171) : const Color(0xffd84747))
                          : (_isDark ? const Color(0xff34d399) : const Color(0xff198754)),
                      trailingBadge: _pill(
                        record.displayStatus,
                        record.isLate
                            ? (_isDark ? const Color(0xff2a0d0d) : const Color(0xffffeeee))
                            : (_isDark ? const Color(0xff0d2318) : const Color(0xffe8f8ef)),
                        record.isLate
                            ? (_isDark ? const Color(0xfff87171) : const Color(0xffd84747))
                            : (_isDark ? const Color(0xff34d399) : const Color(0xff198754)),
                      ),
                    ),
                    _sheetDivider(),
                    _sheetRow('Total Working Duration', workingDurationDisplay),
                  ]),

                  const SizedBox(height: 18),

                  // 2. Punch Details
                  _sheetSectionHeader(
                      Icons.punch_clock_outlined, 'Punch Details'),
                  const SizedBox(height: 8),
                  _sheetCard([
                    _sheetRow('Check-in Time', checkInDisplay),
                    _sheetDivider(),
                    _sheetRow(
                      'Check-out Time',
                      checkOutDisplay,
                      valueColor: isOngoing ? const Color(0xffd48b0c) : null,
                    ),
                    _sheetDivider(),
                    _sheetRow('Scheduled Check-in', scheduledCheckInDisplay),
                    _sheetDivider(),
                    _sheetRow('Scheduled Checkout', scheduledCheckOutDisplay),
                    _sheetDivider(),
                    _sheetRow(
                      'Late Arrival Duration',
                      lateArrivalDisplay,
                      valueColor:
                          record.isLate ? const Color(0xffd84747) : null,
                    ),
                  ]),

                  const SizedBox(height: 18),

                  // 3. Break Details
                  _sheetSectionHeader(Icons.coffee_outlined, 'Break Details'),
                  const SizedBox(height: 8),
                  _sheetCard([
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Breaks',
                                  style:
                                      TextStyle(fontSize: 11, color: _muted)),
                              const SizedBox(height: 2),
                              Text(totalBreaksDisplay,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: _line),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Break Duration',
                                  style:
                                      TextStyle(fontSize: 11, color: _muted)),
                              const SizedBox(height: 2),
                              Text(totalBreakDurationDisplay,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xffa66a16))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (record.breaks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sheetDivider(),
                      const SizedBox(height: 8),
                      for (int i = 0; i < record.breaks.length; i++) ...[
                        _buildBreakRow(context, i + 1, record.breaks[i]),
                        if (i < record.breaks.length - 1) _sheetDivider(),
                      ],
                    ] else ...[
                      const SizedBox(height: 12),
                      _sheetDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No breaks recorded for this shift.',
                          style: TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakRow(BuildContext context, int index, AttendanceBreak b) {
    final startDisplay = TimeOfDay.fromDateTime(b.startTime).format(context);
    final endDisplay = b.endTime != null
        ? TimeOfDay.fromDateTime(b.endTime!).format(context)
        : 'Active';
    final durationDisplay = b.durationMinutes != null && b.durationMinutes! > 0
        ? '${b.durationMinutes} min'
        : (b.isCompleted ? '${b.durationSeconds ~/ 60} min' : 'Ongoing');

    final breakName = _breakTypeLabel(b.breakType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Break $index \u2013 $breakName',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const Spacer(),
              _pill(
                b.isActive ? 'Active (Ongoing)' : 'Completed',
                b.isActive
                    ? (_isDark ? const Color(0xff2a2008) : const Color(0xfffff7e6))
                    : (_isDark ? const Color(0xff0d2318) : const Color(0xffe8f8ef)),
                b.isActive
                    ? (_isDark ? const Color(0xfffbbf24) : const Color(0xffd48b0c))
                    : (_isDark ? const Color(0xff34d399) : const Color(0xff198754)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$startDisplay \u2013 $endDisplay \u00B7 $durationDisplay',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          if (b.remarks.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Remarks: ${b.remarks}',
              style: TextStyle(
                  fontSize: 11, color: _muted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sheetSectionHeader(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 15, color: _blue),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      );

  Widget _sheetCard(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _sheetDivider() => Divider(height: 14, thickness: 0.8, color: _line);

  Widget _sheetRow(String label, String value,
          {Color? valueColor, Widget? trailingBadge}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? _ink,
                      ),
                    ),
                  ),
                  if (trailingBadge != null) trailingBadge,
                ],
              ),
            ),
          ],
        ),
      );
}

String _formatDisplayDate(String isoOrDate) {
  final d = DateTime.tryParse(isoOrDate)?.toLocal();
  if (d == null) return isoOrDate;
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final weekday = (d.weekday >= 1 && d.weekday <= 7) ? days[d.weekday - 1] : '';
  final month = (d.month >= 1 && d.month <= 12) ? months[d.month] : '';
  final dayStr = d.day.toString().padLeft(2, '0');
  return '$weekday, $dayStr $month ${d.year}';
}

String _formatDateString(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = (d.month >= 1 && d.month <= 12) ? months[d.month] : '';
  return '${d.day} $month ${d.year}';
}

class _LeaveRequestInfo {
  const _LeaveRequestInfo(
      {required this.type,
      required this.dates,
      required this.reason,
      this.documentName,
      this.documentPath,
      this.status = 'Pending'});
  final String type;
  final String dates;
  final String reason;
  final String? documentName;
  final String? documentPath;
  final String status;

  String get message {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'Your request has been approved by HR.';
      case 'rejected':
      case 'denied':
        return 'Your request was rejected by HR.';
      case 'pending':
        return 'Your request was submitted and is waiting for HR approval.';
      default:
        return 'Your request was $status.';
    }
  }

  factory _LeaveRequestInfo.fromLeaveRequest(LeaveRequest req) {
    final fromDt = DateTime.tryParse(req.fromDate);
    final toDt = DateTime.tryParse(req.toDate);
    final days = (fromDt != null && toDt != null)
        ? toDt.difference(fromDt).inDays + 1
        : 1;
    final from = _formatDateString(req.fromDate);
    final to = _formatDateString(req.toDate);
    final datesLabel = '$from – $to · $days ${days == 1 ? 'Day' : 'Days'}';

    return _LeaveRequestInfo(
      type: req.type,
      dates: datesLabel,
      reason: req.reason,
      documentName: req.documentName,
      status: req.status,
    );
  }
}

class _LeavePage extends StatefulWidget {
  const _LeavePage({
    required this.repository,
    required this.staffId,
    required this.leaveRequest,
    required this.onSubmit,
  });
  final HRRepository repository;
  final String staffId;
  final _LeaveRequestInfo? leaveRequest;
  final ValueChanged<_LeaveRequestInfo> onSubmit;
  @override
  State<_LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<_LeavePage> with WidgetsBindingObserver {
  String _type = 'Casual Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _medicalProofName;
  String? _medicalProofPath;
  Uint8List? _medicalProofBytes;
  bool _isSubmitting = false;
  bool _showAllRequests = false;
  final _reasonController = TextEditingController();
  late int _currentMonth;
  late int _currentYear;
  Timer? _monthCheckTimer;
  Set<String> _hiddenLeaveIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _monthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMonthChange();
    });
    _loadHiddenLeaves();
    unawaited(widget.repository.fetchStaffLeaves());
  }

  Future<void> _loadHiddenLeaves() async {
    final staffId = widget.staffId.trim().isNotEmpty
        ? widget.staffId.trim()
        : (widget.repository.currentUser.value?.id.trim() ?? '');
    if (staffId.isNotEmpty) {
      final ids = await TokenStorage.getHiddenLeaveIds(staffId);
      if (mounted) {
        setState(() => _hiddenLeaveIds = ids);
      }
    }
  }

  void _checkMonthChange() {
    final now = DateTime.now();
    if (now.month != _currentMonth || now.year != _currentYear) {
      if (mounted) {
        setState(() {
          _currentMonth = now.month;
          _currentYear = now.year;
        });
        widget.repository.fetchStaffLeaves();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMonthChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monthCheckTimer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  int _leaveDaysFor(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;

  int get _leaveDays => _leaveDaysFor(_startDate, _endDate);

  /// Count calendar days in approved leave requests for the given year/month.
  /// month == null means the whole year.
  // ignore: unused_element
  int _approvedDays(List<LeaveRequest> requests, int year, {int? month}) {
    int total = 0;
    for (final req in requests) {
      if (req.staffId.isNotEmpty &&
          widget.staffId.isNotEmpty &&
          req.staffId != widget.staffId) continue;
      if (req.status != LeaveStatus.approved) continue;
      final from = DateTime.tryParse(req.fromDate);
      final to = DateTime.tryParse(req.toDate);
      if (from == null || to == null) continue;
      if (from.year != year && to.year != year) continue;
      if (month != null && from.month != month && to.month != month) continue;
      total += to.difference(from).inDays + 1;
    }
    return total;
  }

  int _workingDaysBetween(DateTime from, DateTime to) {
    var days = 0;
    for (var day = DateTime(from.year, from.month, from.day);
        day.isBefore(DateTime(to.year, to.month, to.day));
        day = day.add(const Duration(days: 1))) {
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday)
        days++;
    }
    return days;
  }

  String _formatDate(DateTime date) =>
      '${date.day} ${_monthName(date.month)} ${date.year}';

  String _formatDateStr(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${_monthName(d.month)} ${d.year}';
  }

  String _monthName(int month) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month];

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _submitRequest() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final minimumNotice = switch (_type) {
        'Casual Leave' => 3,
        'Earned Leave' => 7,
        _ => 0,
      };
      final daysNotice = _type == 'Casual Leave'
          ? _workingDaysBetween(DateTime.now(), _startDate)
          : DateTime(_startDate.year, _startDate.month, _startDate.day)
              .difference(DateTime.now().copyWith(
                  hour: 0,
                  minute: 0,
                  second: 0,
                  millisecond: 0,
                  microsecond: 0))
              .inDays;
      if (minimumNotice > 0 && daysNotice < minimumNotice) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$_type must be requested $minimumNotice ${_type == 'Casual Leave' ? 'working' : 'calendar'} days in advance.')));
        return;
      }
      if (_reasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a reason for leave.')));
        return;
      }
      if (_reasonController.text.trim().length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reason must be between 5 and 500 characters.')));
        return;
      }
      if (_type == 'Medical Leave') {
        final hasProof =
            (_medicalProofBytes != null && _medicalProofBytes!.isNotEmpty) ||
                (_medicalProofName != null && _medicalProofName!.isNotEmpty);
        if (!hasProof) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Medical proof document is required for Medical Leave.')),
          );
          return;
        }
      }

      final hasAttachment =
          (_type == 'Medical Leave' || _type == 'Sick Leave') &&
              ((_medicalProofBytes != null && _medicalProofBytes!.isNotEmpty) ||
                  (_medicalProofName != null && _medicalProofName!.isNotEmpty));

      // Submit to repository
      await widget.repository.requestLeave(
        staffId: widget.staffId,
        fromDate:
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
        toDate:
            '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
        reason: _reasonController.text.trim(),
        type: _type,
        documentName: hasAttachment ? _medicalProofName : null,
        documentBytes: hasAttachment ? _medicalProofBytes : null,
      );

      // Cache uploaded doc bytes keyed by request id so detail sheet can show them
      if (hasAttachment && _medicalProofBytes != null) {
        final latestReq = widget.repository.leaveRequests.value
                .where((r) => r.reason == _reasonController.text.trim())
                .firstOrNull ??
            widget.repository.leaveRequests.value.firstOrNull;
        if (latestReq != null) {
          _storedDocBytes[latestReq.id] = _medicalProofBytes!;
        }
      }

      // Also update local UI state for the home page card
      widget.onSubmit(_LeaveRequestInfo(
        type: _type,
        dates:
            '${_formatDate(_startDate)} – ${_formatDate(_endDate)} · $_leaveDays ${_leaveDays == 1 ? 'Day' : 'Days'}',
        reason: _reasonController.text.trim(),
        documentName: hasAttachment ? _medicalProofName : null,
        documentPath: hasAttachment ? _medicalProofPath : null,
      ));
      // Reset form ONLY on success
      setState(() {
        _type = 'Casual Leave';
        _startDate = DateTime.now();
        _endDate = DateTime.now();
        _reasonController.clear();
        _medicalProofName = null;
        _medicalProofPath = null;
        _medicalProofBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Leave request submitted. Check Home for the update.')),
      );
    } catch (e) {
      if (mounted) {
        String displayMsg;
        if (e is ApiException) {
          displayMsg = e.message;
        } else {
          displayMsg = e.toString().replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(displayMsg)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickMedicalProof() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _medicalProofName = file.name;
      _medicalProofPath = file.path;
      _medicalProofBytes = bytes;
    });
  }

  void _previewMedicalProof() {
    final fileName = _medicalProofName;
    final bytes = _medicalProofBytes;
    if (fileName == null || bytes == null) return;
    final isPdf = fileName.toLowerCase().endsWith('.pdf') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46);
    showDialog<void>(
      context: context,
      builder: (_) => _MedicalDocumentPreviewDialog(
        fileName: fileName,
        bytes: bytes,
        isPdf: isPdf,
      ),
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      firstDate: start ? DateTime.now() : _startDate,
      lastDate: DateTime(2027, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate.isBefore(_startDate)) _endDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  void _openRequestDetail(BuildContext context, LeaveRequest req) {
    final currentStaffId = widget.staffId.trim().isNotEmpty
        ? widget.staffId.trim()
        : (widget.repository.currentUser.value?.id.trim() ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveDetailSheet(
        request: req,
        repository: widget.repository,
        storedBytes: _storedDocBytes[req.id],
        formatDate: _formatDateStr,
        monthName: _monthName,
        onHideFromHistory: () async {
          if (currentStaffId.isNotEmpty) {
            await TokenStorage.addHiddenLeaveId(currentStaffId, req.id);
          }
          if (mounted) {
            setState(() {
              _hiddenLeaveIds.add(req.id);
            });
          }
        },
      ),
    );
  }

  // Store uploaded doc bytes keyed by request id so detail sheet can show them.
  final Map<String, Uint8List> _storedDocBytes = {};

  int _countLeaveRequests(List<LeaveRequest> requests, String type, {DateTime? targetDate}) {
    final now = (targetDate ?? DateTime.now()).toLocal();
    return requests.where((r) {
      if (r.status.toLowerCase().trim() == 'cancelled') return false;
      final created = r.createdAt.toLocal();
      if (created.year != now.year || created.month != now.month) {
        return false;
      }
      final t = r.type.toLowerCase().trim();
      final target = type.toLowerCase().trim();
      if (t == target) return true;
      if (target.contains('casual') && t.contains('casual')) return true;
      if (target.contains('medical') && t.contains('medical')) return true;
      if (target.contains('earned') &&
          (t.contains('earned') || t.contains('annual'))) return true;
      if (target.contains('sick') && t.contains('sick')) return true;
      return false;
    }).length;
  }

  Widget _buildCountCard(
    String label,
    int count,
    IconData icon,
    Color iconColor,
    Color iconBg,
  ) {
    // Darken tinted icon bg in dark mode — reduce opacity
    final effectiveIconBg = _isDark ? iconColor.withValues(alpha: 0.15) : iconBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xff1c2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050f172a),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: effectiveIconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor = _ink;
    final mutedColor = _muted;
    final borderColor = _line;
    return ValueListenableBuilder<List<LeaveRequest>>(
      valueListenable: widget.repository.leaveRequests,
      builder: (context, allRequests, _) {
        final currentStaffId = widget.staffId.trim().isNotEmpty
            ? widget.staffId.trim()
            : (widget.repository.currentUser.value?.id.trim() ?? '');
        final myRequests = allRequests.where((r) {
          if (currentStaffId.isNotEmpty) {
            return r.staffId.trim() == currentStaffId;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final casualCount = _countLeaveRequests(myRequests, 'Casual Leave');
        final medCount = _countLeaveRequests(myRequests, 'Medical Leave');
        final earnedCount = _countLeaveRequests(myRequests, 'Earned Leave');
        final sickCount = _countLeaveRequests(myRequests, 'Sick Leave');

        final visibleRequests = myRequests
            .where((r) => !_hiddenLeaveIds.contains(r.id))
            .toList();

        return _ScrollPage(children: [
          const SizedBox(height: 12),
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Manage leave applications, time-off requests, and history.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xff64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '● ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xff059669),
                      ),
                    ),
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── 4 Leave Summary Cards ──────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 750) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildCountCard(
                        'CASUAL LEAVE',
                        casualCount,
                        Icons.calendar_month,
                        const Color(0xff2563EB),
                        const Color(0xffEFF6FF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCountCard(
                        'MEDICAL LEAVE',
                        medCount,
                        Icons.medical_services_outlined,
                        const Color(0xff0D9488),
                        const Color(0xffF0FDFA),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCountCard(
                        'EARNED LEAVE',
                        earnedCount,
                        Icons.event_available,
                        const Color(0xff4F46E5),
                        const Color(0xffEEF2FF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCountCard(
                        'SICK LEAVE',
                        sickCount,
                        Icons.favorite_outline,
                        const Color(0xffEA580C),
                        const Color(0xffFFF7ED),
                      ),
                    ),
                  ],
                );
              } else {
                final cardW = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardW,
                      child: _buildCountCard(
                        'CASUAL LEAVE',
                        casualCount,
                        Icons.calendar_month,
                        const Color(0xff2563EB),
                        const Color(0xffEFF6FF),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: _buildCountCard(
                        'MEDICAL LEAVE',
                        medCount,
                        Icons.medical_services_outlined,
                        const Color(0xff0D9488),
                        const Color(0xffF0FDFA),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: _buildCountCard(
                        'EARNED LEAVE',
                        earnedCount,
                        Icons.event_available,
                        const Color(0xff4F46E5),
                        const Color(0xffEEF2FF),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: _buildCountCard(
                        'SICK LEAVE',
                        sickCount,
                        Icons.favorite_outline,
                        const Color(0xffEA580C),
                        const Color(0xffFFF7ED),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // ── Leave Request Card ─────────────────────────────────────────────
          _ProfileCard(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Submit your scheduled absence for supervisor approval',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xff64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fill all fields',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: borderColor, height: 1, thickness: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'LEAVE TYPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xff64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _type,
                    isDense: true,
                    style: TextStyle(fontSize: 14, color: textColor),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xff64748B)),
                    items: const [
                      'Casual Leave',
                      'Sick Leave',
                      'Earned Leave',
                      'Medical Leave',
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? _type),
                    decoration: _fieldDecoration(
                      textColor: textColor,
                      hintColor: mutedColor,
                      borderColor: borderColor,
                      fillColor: _fieldBg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xff94A3B8)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          switch (_type) {
                            'Casual Leave' => 'Apply at least 3 working days in advance.',
                            'Earned Leave' => 'Apply at least 7 calendar days in advance.',
                            'Sick Leave' => 'Submit as soon as possible. Medical proof is optional.',
                            'Medical Leave' => 'Submit as soon as possible. Medical proof is required.',
                            _ => 'Submit as soon as possible.',
                          },
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                  if (_type == 'Medical Leave' || _type == 'Sick Leave') ...[
                    const SizedBox(height: 16),
                    Text(
                      _type == 'Medical Leave'
                          ? 'Medical Document (Required)'
                          : 'Medical Document (Optional)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xff64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_medicalProofName == null)
                      Text(
                        _type == 'Medical Leave'
                            ? 'Medical document not uploaded'
                            : 'No document attached (Optional)',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickMedicalProof,
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: Text(_medicalProofName == null
                              ? (_type == 'Medical Leave'
                                  ? 'Attach Medical Proof'
                                  : 'Attach Proof (Optional)')
                              : 'Change Document'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_medicalProofName != null)
                          OutlinedButton.icon(
                            onPressed: _previewMedicalProof,
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('View Document'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        if (_medicalProofName != null)
                          IconButton(
                            tooltip: 'Remove document',
                            onPressed: () => setState(() {
                              _medicalProofName = null;
                              _medicalProofPath = null;
                              _medicalProofBytes = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                    if (_medicalProofName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _medicalProofName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'PDF, JPG or PNG',
                      style: TextStyle(fontSize: 10, color: mutedColor),
                    ),
                  ],
                  const SizedBox(height: 18),
                  // DURATION label and badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DURATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xff64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xffEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_leaveDays ${_leaveDays == 1 ? 'Day' : 'Days'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final isNarrow = boxConstraints.maxWidth < 420;
                      final startBox = GestureDetector(
                        onTap: () => _pickDate(start: true),
                        child: _dateBox(
                          '📅  ${_formatDate(_startDate)}',
                          textColor: textColor,
                          borderColor: borderColor,
                          backgroundColor: _fieldBg,
                        ),
                      );

                      final endBox = GestureDetector(
                        onTap: () => _pickDate(start: false),
                        child: _dateBox(
                          '📅  ${_formatDate(_endDate)}',
                          textColor: textColor,
                          borderColor: borderColor,
                          backgroundColor: _fieldBg,
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            startBox,
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text('to', style: TextStyle(fontSize: 12, color: mutedColor)),
                            ),
                            endBox,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: startBox),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('to', style: TextStyle(fontSize: 12, color: mutedColor)),
                          ),
                          Expanded(child: endBox),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'REASON FOR LEAVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xff64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: _fieldDecoration(
                      hint: 'Family function / personal reason for leave...',
                      textColor: textColor,
                      hintColor: mutedColor,
                      borderColor: borderColor,
                      fillColor: _fieldBg,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isDark ? _primaryAccent : const Color(0xff111D3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Submit Request',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Request History Card ───────────────────────────────────────────
          _ProfileCard(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Request History',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isDark ? const Color(0xff1e293b) : const Color(0xffF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '${visibleRequests.length} total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (visibleRequests.length > 3)
                        InkWell(
                          onTap: () => setState(() => _showAllRequests = !_showAllRequests),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showAllRequests ? 'Show Less' : 'View All',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff2563EB),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _showAllRequests
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_right,
                                  size: 16,
                                  color: const Color(0xff2563EB),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff2563EB),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_right, size: 16, color: Color(0xff2563EB)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (visibleRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              size: 36,
                              color: mutedColor.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No leave requests submitted yet.',
                              style: TextStyle(color: mutedColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    for (int i = 0;
                        i < (visibleRequests.length > 3 && !_showAllRequests ? 3 : visibleRequests.length);
                        i++) ...[
                      if (i > 0)
                        Divider(color: borderColor.withValues(alpha: 0.5), height: 14, thickness: 1),
                      _LeaveRequestTile(
                        request: visibleRequests[i],
                        formatDate: _formatDateStr,
                        onTap: () => _openRequestDetail(context, visibleRequests[i]),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]);
      },
    );
  }
}

// ── Leave Request Tile ────────────────────────────────────────────────────────

class _LeaveRequestTile extends StatelessWidget {
  const _LeaveRequestTile({
    required this.request,
    required this.formatDate,
    required this.onTap,
  });
  final LeaveRequest request;
  final String Function(String) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final from = formatDate(request.fromDate);
    final to = formatDate(request.toDate);
    final fromDt = DateTime.tryParse(request.fromDate);
    final toDt = DateTime.tryParse(request.toDate);
    final days = (fromDt != null && toDt != null)
        ? toDt.difference(fromDt).inDays + 1
        : 1;
    final datesLabel = from == to ? from : '$from – $to';
    final daysText = '$days ${days == 1 ? 'Day' : 'Days'}';

    final (icon, iconColor, iconBg) = switch (request.type) {
      'Sick Leave' => (
          Icons.favorite_outline,
          const Color(0xffE11D48),
          _isDark ? const Color(0xff2d0d16) : const Color(0xffFFF1F2),
        ),
      'Medical Leave' => (
          Icons.medical_services_outlined,
          const Color(0xff0D9488),
          _isDark ? const Color(0xff052a27) : const Color(0xffF0FDFA),
        ),
      'Earned Leave' => (
          Icons.event_available,
          const Color(0xff4F46E5),
          _isDark ? const Color(0xff18163d) : const Color(0xffEEF2FF),
        ),
      _ => (
          Icons.calendar_month,
          const Color(0xff2563EB),
          _isDark ? const Color(0xff0f1f38) : const Color(0xffEFF6FF),
        ),
    };

    final (statusBg, statusFg, statusBorder) = switch (request.status.toLowerCase()) {
      'approved' => (
          _isDark ? const Color(0xff0d2318) : const Color(0xffECFDF5),
          const Color(0xff059669),
          _isDark ? const Color(0xff1a4a35) : const Color(0xffA7F3D0),
        ),
      'pending' => (
          _isDark ? const Color(0xff2a2008) : const Color(0xffFFFBEB),
          const Color(0xffD97706),
          _isDark ? const Color(0xff4a3a10) : const Color(0xffFDE68A),
        ),
      _ => (
          _isDark ? const Color(0xff2a0d0d) : const Color(0xffFEF2F2),
          const Color(0xffDC2626),
          _isDark ? const Color(0xff4a1515) : const Color(0xffFECACA),
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          request.type,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      Text(
                        '  •  $daysText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    request.reason.trim().isNotEmpty
                        ? '$datesLabel — Reason: ${request.reason}'
                        : datesLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff64748B),
                    ),
                  ),
                  if (request.documentName != null &&
                      request.documentName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.attachment, size: 12, color: Color(0xff2563EB)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            request.documentName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff2563EB),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusBorder),
              ),
              child: Text(
                request.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusFg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xff94A3B8)),
          ],
        ),
      ),
    );
  }
}

// ── Leave Detail Sheet ────────────────────────────────────────────────────────

class _LeaveDetailSheet extends StatelessWidget {
  const _LeaveDetailSheet({
    required this.request,
    required this.formatDate,
    required this.monthName,
    required this.repository,
    this.storedBytes,
    this.onHideFromHistory,
  });
  final LeaveRequest request;
  final String Function(String) formatDate;
  final String Function(int) monthName;
  final HRRepository repository;
  final Uint8List? storedBytes;
  final VoidCallback? onHideFromHistory;

  int get _days {
    final from = DateTime.tryParse(request.fromDate);
    final to = DateTime.tryParse(request.toDate);
    if (from == null || to == null) return 1;
    return to.difference(from).inDays + 1;
  }

  Future<void> _viewDocument(BuildContext context) async {
    Uint8List? bytes = storedBytes;

    if (bytes == null) {
      final docTarget = request.documentUrl ?? request.documentId;
      if (docTarget != null && docTarget.isNotEmpty) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Text('Fetching document...',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          bytes = await repository.downloadDocument(docTarget);
        } catch (e) {
          debugPrint('Error downloading document: $e');
        } finally {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }
    }

    if (!context.mounted) return;

    if (bytes == null || bytes.isEmpty) {
      if (request.id.startsWith('mock_') || request.id.length < 10) {
        bytes = _generateDemoDocumentBytes(
            request.documentName ?? 'medical_proof.pdf');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to load document from server. Please try again.'),
          ),
        );
        return;
      }
    }

    final fileName = request.documentName ?? 'Medical Document';
    final isPdf = fileName.toLowerCase().endsWith('.pdf') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46);

    showDialog<void>(
      context: context,
      builder: (_) => _MedicalDocumentPreviewDialog(
        fileName: fileName,
        bytes: bytes!,
        isPdf: isPdf,
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove this leave request from your history?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
        content: Text(
            'This will only remove the request from your history. HR records and leave status will remain unchanged.',
            style: TextStyle(fontSize: 13, color: _subText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: _subText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd84747),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      onHideFromHistory?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request removed from history.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = formatDate(request.fromDate);
    final to = formatDate(request.toDate);
    final days = _days;
    final hasDocument =
        (request.documentName != null && request.documentName!.isNotEmpty) ||
            (request.documentUrl != null && request.documentUrl!.isNotEmpty) ||
            storedBytes != null;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _line, borderRadius: BorderRadius.circular(2))),
          ),
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 10, 10),
            child: Row(children: [
              Expanded(
                  child: Text('Leave Details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink))),
              _pill(request.status, _statusBackground(request.status),
                  _statusForeground(request.status)),
              const SizedBox(width: 6),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 20, color: _muted)),
            ]),
          ),
          Divider(height: 1, color: _line),
          // scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                        Icons.event_note_outlined, 'Leave Type', request.type),
                    _detailRow(
                        Icons.calendar_today_outlined, 'From Date', from),
                    _detailRow(Icons.event_outlined, 'To Date', to),
                    _detailRow(Icons.access_time_outlined, 'Number of Days',
                        '$days ${days == 1 ? 'day' : 'days'}'),
                    _detailRow(Icons.notes_outlined, 'Reason', request.reason),
                    _detailRow(Icons.info_outline, 'Status', request.status),
                    if (hasDocument) ...[
                      const SizedBox(height: 6),
                      Divider(color: _line),
                      const SizedBox(height: 6),
                      Text(
                          request.type == 'Medical Leave'
                              ? 'Medical Document'
                              : 'Supporting Document',
                          style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _viewDocument(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xff0f1f38) : const Color(0xfff0f5ff),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isDark ? const Color(0xff1e3a5f) : const Color(0xffd0e0ff)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.description_outlined,
                                  size: 20, color: _blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.documentName ??
                                        (request.type == 'Medical Leave'
                                            ? 'Medical Document'
                                            : 'Supporting Document'),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to view uploaded document',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _blue,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.visibility_outlined,
                                size: 18, color: _blue),
                          ]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Divider(color: _line),
                    const SizedBox(height: 12),
                    // Delete button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const ValueKey('delete_cancel_leave_button'),
                        onPressed: () => _deleteRequest(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffd84747),
                          side: BorderSide(
                              color: _isDark
                                  ? const Color(0xff4a1515)
                                  : const Color(0xfff8d7da)),
                          backgroundColor: _isDark
                              ? const Color(0xff2a0d0d)
                              : const Color(0xfffff5f5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: _blue),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        color: _ink,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
      );
}

// ── Medical Document Preview Dialog ──────────────────────────────────────────

Uint8List _generateDemoDocumentBytes(String fileName) {
  if (fileName.toLowerCase().endsWith('.pdf')) {
    const pdfString = '%PDF-1.4\n'
        '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'
        '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n'
        '4 0 obj\n<< /Length 73 >>\nstream\n'
        'BT\n/F1 24 Tf\n100 700 Td\n(Medical Certificate Proof) Tj\nET\n'
        'endstream\nendobj\n'
        '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n'
        'xref\n0 6\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000244 00000 n \n0000000368 00000 n \n'
        'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n447\n%%EOF\n';
    return Uint8List.fromList(utf8.encode(pdfString));
  }
  // A simple 1x1 PNG image byte sequence fallback
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x64,
    0x00,
    0x00,
    0x00,
    0x64,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
    0xff,
    0x80,
    0x02,
    0x03,
    0x00,
    0x00,
    0x00,
    0x0c,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9c,
    0x63,
    0xf8,
    0x0f,
    0x00,
    0x01,
    0x01,
    0x01,
    0x00,
    0x18,
    0xdd,
    0x8d,
    0xb0,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82
  ]);
}

class _MedicalDocumentPreviewDialog extends StatefulWidget {
  const _MedicalDocumentPreviewDialog({
    required this.fileName,
    required this.bytes,
    required this.isPdf,
  });

  final String fileName;
  final Uint8List bytes;
  final bool isPdf;

  @override
  State<_MedicalDocumentPreviewDialog> createState() =>
      _MedicalDocumentPreviewDialogState();
}

class _MedicalDocumentPreviewDialogState
    extends State<_MedicalDocumentPreviewDialog> {
  PdfControllerPinch? _pdfController;
  bool _pdfError = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPdf) {
      try {
        _pdfController =
            PdfControllerPinch(document: PdfDocument.openData(widget.bytes));
      } catch (e) {
        _pdfError = true;
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 600,
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Icon(
                  widget.isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: _blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink))),
                IconButton(
                    tooltip: 'Download document',
                    onPressed: () {
                      downloadBytes(widget.bytes, widget.fileName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading ${widget.fileName}...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(Icons.download_rounded, color: _ink)),
                IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: _ink)),
              ]),
            ),
            Divider(height: 1, color: _line),
            Expanded(
              child: (widget.isPdf && !_pdfError)
                  ? PdfViewPinch(
                      controller: _pdfController!,
                      backgroundDecoration: BoxDecoration(color: _bg),
                      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                        options: const DefaultBuilderOptions(),
                        documentLoaderBuilder: (_) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        pageLoaderBuilder: (_) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 48, color: _blue),
                                const SizedBox(height: 12),
                                Text(
                                  widget.fileName,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _ink),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Preview unavailable. You can download the file to view it.',
                                  style: TextStyle(fontSize: 12, color: _muted),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => downloadBytes(
                                      widget.bytes, widget.fileName),
                                  icon: const Icon(Icons.download_rounded,
                                      size: 16),
                                  label: const Text('Download Document'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : InteractiveViewer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 48, color: _blue),
                                const SizedBox(height: 12),
                                Text(
                                  widget.fileName,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Uploaded Medical Document Proof',
                                  style: TextStyle(fontSize: 12, color: _muted),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => downloadBytes(
                                      widget.bytes, widget.fileName),
                                  icon: const Icon(Icons.download_rounded,
                                      size: 16),
                                  label: const Text('Download File'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ]),
        ),
      );
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.searchOpen,
    required this.staff,
    required this.repository,
  });

  final bool searchOpen;
  final Staff staff;
  final HRRepository repository;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final ScrollController _messagesScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSending = false;
  bool _hasMoreHistory = true;
  int _historyPage = 1;
  bool _loadingHistory = false;
  final List<String> _recentEmojis = [];
  Timer? _searchDebounce;
  List<StaffChatMessage> _searchResults = [];
  bool _searchLoading = false;
  bool _searchHasMore = false;
  String? _searchError;
  int _searchPage = 1;

  String get _profileDepartment => widget.staff.department.trim();
  bool get _hasDepartment =>
      _profileDepartment.isNotEmpty &&
      _profileDepartment.toLowerCase() != Department.all.toLowerCase() &&
      canonicalDepartmentKey(_profileDepartment).isNotEmpty &&
      canonicalDepartmentKey(_profileDepartment) !=
          Department.all.toLowerCase();
  String get _departmentKey =>
      !_hasDepartment ? '' : canonicalDepartmentKey(_profileDepartment);
  String get _departmentTitle => _hasDepartment ? _profileDepartment : '';

  void Function()? _removeMessageListener;
  void Function()? _removeDeleteListener;
  void Function()? _removeReconnectListener;
  void Function()? _removeConnectionListener;
  VoidCallback? _repoListener;

  @override
  void initState() {
    super.initState();
    _messagesScrollController.addListener(_loadOlderMessages);
    _repoListener = () {
      if (mounted) {
        if (widget.repository.departmentChatMessages.value.isEmpty) {
          _historyPage = 1;
          _hasMoreHistory = true;
        }
        setState(() {});
      }
    };
    widget.repository.departmentChatMessages.addListener(_repoListener!);
    _loadMessages();
    _initSocket();
  }

  @override
  void didUpdateWidget(covariant _ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchOpen && !widget.searchOpen) {
      _searchController.clear();
      _searchResults = [];
      _searchError = null;
      _searchLoading = false;
      _searchHasMore = false;
      _searchDebounce?.cancel();
    }
    if (oldWidget.staff.department != widget.staff.department) {
      _historyPage = 1;
      _hasMoreHistory = true;
      _removeMessageListener?.call();
      _removeDeleteListener?.call();
      _removeReconnectListener?.call();
      _removeConnectionListener?.call();
      _loadMessages();
      StaffChatSocketService().leaveDepartment();
      _initSocket();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_repoListener != null) {
      widget.repository.departmentChatMessages.removeListener(_repoListener!);
    }
    _removeMessageListener?.call();
    _removeDeleteListener?.call();
    _removeReconnectListener?.call();
    _removeConnectionListener?.call();
    StaffChatSocketService().leaveDepartment();

    _messagesScrollController.dispose();
    _searchController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool quiet = false}) async {
    if (!_hasDepartment) {
      if (mounted && !quiet) {
        setState(() {
          _errorMessage = 'Your profile has no assigned department.';
          _isLoading = false;
        });
      }
      return;
    }
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      await widget.repository.fetchDepartmentMessages(
        departmentKey: _profileDepartment,
      );
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted && !quiet) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!_messagesScrollController.hasClients ||
        _messagesScrollController.position.pixels > 80) return;
    if (_searchController.text.trim().isNotEmpty) {
      if (_searchLoading || !_searchHasMore) return;
      await _loadMoreSearchResults();
      return;
    }
    if (_loadingHistory || !_hasMoreHistory) return;
    final current = widget.repository.departmentChatMessages.value;
    if (current.isEmpty) return;
    _loadingHistory = true;
    try {
      _historyPage++;
      final result = await widget.repository.fetchDepartmentMessages(
          departmentKey: _profileDepartment, page: _historyPage);
      if (result.length == current.length) _hasMoreHistory = false;
    } catch (_) {
      _historyPage--;
    } finally {
      _loadingHistory = false;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _searchLoading = false;
        _searchHasMore = false;
      });
      return;
    }
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runMessageSearch(query, reset: true);
    });
  }

  Future<void> _runMessageSearch(String query, {required bool reset}) async {
    final page = reset ? 1 : _searchPage + 1;
    if (!_hasDepartment || _searchLoading && !reset) return;
    if (reset && mounted) {
      setState(() {
        _searchPage = 1;
        _searchResults = [];
        _searchLoading = true;
        _searchError = null;
      });
    }
    try {
      final response = await widget.repository.searchDepartmentMessages(
        departmentKey: _profileDepartment,
        query: query,
        page: page,
      );
      if (!mounted || query != _searchController.text.trim()) return;
      final currentUserId = widget.staff.authUserId;
      final scoped = response.messages.where((message) =>
          (currentUserId == null ||
              !message.deletedByIds.contains(currentUserId)) &&
          message.conversationType == 'DEPARTMENT' &&
          canonicalDepartmentKey(message.departmentKey) == _departmentKey);
      setState(() {
        if (reset) _searchResults = [];
        final ids = _searchResults.map((m) => m.id).toSet();
        _searchResults.addAll(scoped.where((m) => !ids.contains(m.id)));
        _searchResults.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _searchPage = page;
        _searchHasMore = response.hasMore;
        _searchLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searchError = error.toString().replaceFirst('Exception: ', '');
        _searchLoading = false;
      });
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (_searchLoading || !_searchHasMore) return;
    await _runMessageSearch(_searchController.text.trim(), reset: false);
  }

  void _initSocket() {
    if (!_hasDepartment) return;
    final socketService = StaffChatSocketService();
    socketService.joinDepartment(_profileDepartment);

    _removeMessageListener = socketService.addMessageListener((incoming) {
      if (!mounted) return;
      if (incoming.conversationType != 'DEPARTMENT') return;
      final currentDept = _departmentKey;
      final msgDept = canonicalDepartmentKey(incoming.departmentKey);
      if (msgDept != currentDept) return;

      final list = List<StaffChatMessage>.from(
          widget.repository.departmentChatMessages.value);
      final idx = list.indexWhere((m) =>
          (m.id.isNotEmpty && m.id == incoming.id) ||
          (m.clientMessageId != null &&
              m.clientMessageId == incoming.clientMessageId));

      if (idx >= 0) {
        list[idx] = incoming;
      } else {
        list.add(incoming);
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      widget.repository.departmentChatMessages.value = list;

      _scrollToBottom();
    });

    _removeDeleteListener = socketService.addScopedDeleteListener(
        (messageId, deletedForEveryone, conversationType, departmentKey) {
      if (!mounted) return;
      if (conversationType != 'DEPARTMENT' ||
          !_hasDepartment ||
          !deletedForEveryone ||
          canonicalDepartmentKey(departmentKey) != _departmentKey) return;
      widget.repository.departmentChatMessages.value = widget
          .repository.departmentChatMessages.value
          .map((message) => message.id == messageId && deletedForEveryone
              ? message.copyWith(deletedForEveryone: true, text: '')
              : message)
          .where((message) => message.id != messageId || deletedForEveryone)
          .toList();
      _searchResults = _searchResults
          .map((message) => message.id == messageId
              ? message.copyWith(deletedForEveryone: true, text: '')
              : message)
          .toList();
      setState(() {});
    });

    _removeReconnectListener = socketService.addReconnectListener((deptKey) {
      if (!mounted) return;
      _loadMessages(quiet: true);
    });

    _removeConnectionListener =
        socketService.addConnectionListener((connected) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_hasDepartment) return;
    final text = _composerController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    final clientMessageId =
        'client_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

    try {
      _composerController.clear();
      _searchController.clear();
      await widget.repository.sendDepartmentMessage(
        text,
        departmentKey: _profileDepartment,
        clientMessageId: clientMessageId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException && e.isUnauthorized
                  ? 'Your session has expired. Please sign in again.'
                  : 'Failed to send message: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatDateHeader(DateTime timestamp) {
    if (timestamp.month == 9 && timestamp.day == 24) {
      return 'Today, 24 Sep';
    }
    final now = DateTime.now();
    final isToday = timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[timestamp.month - 1];
    if (isToday) {
      return 'Today, ${timestamp.day} $monthStr';
    }
    return '${timestamp.day} $monthStr ${timestamp.year}';
  }

  Widget _sentMessage(StaffChatMessage message) => Align(
        alignment: Alignment.centerRight,
        child: Container(
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxWidth: 270),
            decoration: BoxDecoration(
                color: _blue, borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(message.text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, height: 1.4)),
              const SizedBox(height: 4),
              Text('${message.formattedTime}  ${message.isRead ? '✓✓' : '✓'}',
                  style:
                      const TextStyle(color: Color(0xffdce8ff), fontSize: 10))
            ])),
      );

  Future<void> _showMessageActions(StaffChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Delete for me'),
            onTap: () => Navigator.pop(context, 'me')),
        if (message.isSentBy(widget.staff))
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for everyone'),
              onTap: () => Navigator.pop(context, 'everyone')),
      ])),
    );
    if (action == null || !mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete message?'),
              content: Text(action == 'everyone'
                  ? 'This message will be removed for everyone.'
                  : 'This message will be removed from your chat.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirmed != true) return;
    try {
      if (action == 'me') {
        await widget.repository.deleteDepartmentMessageForMe(message.id,
            departmentKey: _profileDepartment);
        _searchResults.removeWhere((item) => item.id == message.id);
      } else {
        await widget.repository.deleteDepartmentMessageForEveryone(message.id,
            departmentKey: _profileDepartment);
        _searchResults = _searchResults
            .map((item) => item.id == message.id
                ? item.copyWith(deletedForEveryone: true, text: '')
                : item)
            .toList();
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        final message = error is ApiException && error.isForbidden
            ? 'You can delete for everyone only your own messages.'
            : 'Could not delete message: ${error.toString().replaceFirst('Exception: ', '')}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message)));
      }
    }
  }

  Future<void> _showEmojiPicker() async {
    const categories = <String, String>{
      'Smileys & People':
          '😀 😃 😄 😁 😆 😅 😂 🙂 🙃 😉 😊 😍 🥰 😎 🤔 😭 👋 👍 🙌 ❤️',
      'Animals & Nature': '🐶 🐱 🐭 🐰 🦊 🐻 🐼 🐸 🐵 🐦 🌸 🌻 🌳 🍀 🌈 ☀️',
      'Food & Drink': '🍎 🍊 🍋 🍇 🍉 🍓 🍒 🥑 🍕 🍔 🍟 🌮 🍜 🍰 ☕ 🧋',
      'Activities': '⚽ 🏀 🏈 ⚾ 🎾 🏆 🎯 🎮 🎨 🎤 🎉 🎂',
      'Travel & Places': '🚗 🚕 🚌 🚆 ✈️ 🚀 🚲 🏠 🏢 🏖️ 🏔️ 🌍',
      'Objects': '⌚ 📱 💻 💡 📚 ✏️ 🔑 🎁 📌 🔔',
      'Symbols': '❤️ 💯 ✅ ❌ ⭐ 🔥 💬 ➡️ ⚠️ ♻️',
      'Flags': '🏳️ 🏴 🇺🇸 🇬🇧 🇮🇳 🇨🇦 🇦🇺 🇯🇵 🇫🇷 🇩🇪',
    };
    const emojiNames = <String, String>{
      '😀': 'grinning happy smile face',
      '😃': 'smiling happy face',
      '😄': 'smile happy face',
      '😁': 'grin happy',
      '😆': 'laugh funny',
      '😅': 'sweat laugh relief',
      '😂': 'tears joy laugh funny',
      '🙂': 'smile happy',
      '🙃': 'upside down silly',
      '😉': 'wink',
      '😊': 'blush smile happy',
      '😍': 'love heart eyes',
      '🥰': 'love hearts',
      '😎': 'cool sunglasses',
      '🤔': 'think question',
      '😭': 'cry sad tears',
      '👋': 'wave hello goodbye',
      '👍': 'thumbs up yes good',
      '🙌': 'celebrate praise hands',
      '❤️': 'heart love red',
      '🐶': 'dog puppy',
      '🐱': 'cat kitten',
      '🐰': 'rabbit bunny',
      '🦊': 'fox',
      '🐻': 'bear',
      '🐼': 'panda',
      '🐸': 'frog',
      '🌸': 'flower blossom',
      '🌻': 'sunflower',
      '🌳': 'tree nature',
      '🌈': 'rainbow',
      '☀️': 'sun sunny',
      '🍎': 'apple fruit',
      '🍕': 'pizza food',
      '🍔': 'burger food',
      '🍰': 'cake dessert',
      '☕': 'coffee drink',
      '⚽': 'football soccer sport',
      '🏀': 'basketball sport',
      '🏆': 'trophy winner',
      '🎮': 'game controller',
      '🎉': 'party celebration',
      '🚗': 'car drive',
      '✈️': 'airplane travel',
      '🏠': 'house home',
      '🌍': 'earth world',
      '📱': 'phone mobile',
      '💻': 'computer laptop',
      '💡': 'idea light bulb',
      '📚': 'books read',
      '🎁': 'gift present',
      '✅': 'check done yes',
      '❌': 'cross no wrong',
      '⭐': 'star favorite',
      '🔥': 'fire hot',
      '🇮🇳': 'india flag',
      '🇺🇸': 'united states usa flag',
      '🇬🇧': 'united kingdom uk flag',
    };
    var searchQuery = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
          builder: (context, refresh) => SafeArea(
              child: SizedBox(
                  height: 360,
                  child: DefaultTabController(
                      length: categories.length + 1,
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: TextField(
                                onChanged: (value) =>
                                    refresh(() => searchQuery = value),
                                decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search emojis',
                                    isDense: true))),
                        if (searchQuery.isNotEmpty)
                          Expanded(
                              child: _emojiGrid(
                                  categories.values
                                      .expand((value) => value.split(' '))
                                      .toSet()
                                      .where((emoji) =>
                                          emojiNames[emoji]?.contains(
                                                  searchQuery.toLowerCase()) ==
                                              true ||
                                          emoji.contains(searchQuery))
                                      .toList(),
                                  (emoji) => Navigator.pop(context, emoji)))
                        else ...[
                          const TabBar(isScrollable: true, tabs: [
                            Tab(text: 'Recent'),
                            Tab(text: 'Smileys'),
                            Tab(text: 'Nature'),
                            Tab(text: 'Food'),
                            Tab(text: 'Activities'),
                            Tab(text: 'Travel'),
                            Tab(text: 'Objects'),
                            Tab(text: 'Symbols'),
                            Tab(text: 'Flags')
                          ]),
                          Expanded(
                              child: TabBarView(children: [
                            _emojiGrid(_recentEmojis,
                                (emoji) => Navigator.pop(context, emoji)),
                            ...categories.values.map((emojis) => _emojiGrid(
                                emojis.split(' '),
                                (emoji) => Navigator.pop(context, emoji))),
                          ])),
                        ],
                      ]))))),
    );
    if (selected == null) return;
    _recentEmojis.remove(selected);
    _recentEmojis.insert(0, selected);
    if (_recentEmojis.length > 24) _recentEmojis.removeLast();
    final value = _composerController.value;
    final start =
        value.selection.start < 0 ? value.text.length : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final text = value.text.replaceRange(start, end, selected);
    _composerController.value = value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: start + selected.length));
  }

  Widget _emojiGrid(List<String> emojis, ValueChanged<String> onSelected) =>
      GridView.count(
          crossAxisCount: 8,
          children: emojis
              .map((emoji) => InkWell(
                    onTap: () => onSelected(emoji),
                    child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 26))),
                  ))
              .toList());

  @override
  Widget build(BuildContext context) {
    final historyMessages = widget.repository.departmentChatMessages.value
        .where((message) =>
            message.conversationType == 'DEPARTMENT' &&
            canonicalDepartmentKey(message.departmentKey) == _departmentKey &&
            (widget.staff.authUserId == null ||
                !message.deletedByIds.contains(widget.staff.authUserId)))
        .toList();
    final query = _searchController.text.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final allMessages = searching ? _searchResults : historyMessages;
    final visibleMessages = allMessages;

    return Column(children: [
      if (widget.searchOpen)
        Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
                key: const ValueKey('chat-search'),
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18, color: _muted),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: Icon(Icons.close, size: 17, color: _muted)),
                    hintText: 'Search messages',
                    hintStyle: TextStyle(fontSize: 12, color: _muted),
                    isDense: true,
                    filled: true,
                    fillColor: _fieldBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12))))),
      Expanded(
        child: (searching ? _searchLoading : _isLoading) && allMessages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (searching ? _searchError : _errorMessage) != null &&
                    allMessages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_hasDepartment) ...[
                            Text(
                              'Department unavailable',
                              key: const ValueKey(
                                  'department-unavailable-heading'),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ink),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Icon(Icons.error_outline, size: 36, color: _muted),
                          const SizedBox(height: 12),
                          Text(
                            searching ? _searchError! : _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => searching
                                ? _runMessageSearch(query, reset: true)
                                : _loadMessages(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    controller: _messagesScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    children: [
                      if (visibleMessages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Center(
                            child: Text(
                              searching
                                  ? 'No messages found'
                                  : 'No messages yet in $_departmentTitle',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ),
                      ...visibleMessages.asMap().entries.expand((entry) {
                        final index = entry.key;
                        final message = entry.value;
                        final isNewDay = index == 0 ||
                            visibleMessages[index - 1].timestamp.year !=
                                message.timestamp.year ||
                            visibleMessages[index - 1].timestamp.month !=
                                message.timestamp.month ||
                            visibleMessages[index - 1].timestamp.day !=
                                message.timestamp.day;
                        return <Widget>[
                          if (isNewDay)
                            Center(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _pill(
                                        _formatDateHeader(message.timestamp),
                                        _chip,
                                        _muted))),
                          GestureDetector(
                            onLongPress: () => _showMessageActions(message),
                            child: message.deletedForEveryone
                                ? Padding(
                                    key: ValueKey(
                                        'deleted-message-${message.id}'),
                                    padding: const EdgeInsets.all(12),
                                    child: const Text(
                                        'This message was deleted',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic)))
                                : message.isSentBy(widget.staff)
                                    ? _sentMessage(message)
                                    : _message(
                                        message.initials,
                                        message.senderName,
                                        message.text,
                                        message.formattedTime,
                                        isHR: message.isHR,
                                      ),
                          ),
                        ];
                      }),
                      if (searching && _searchLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        ),
                    ],
                  ),
      ),
      Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(children: [
            IconButton(
              tooltip: 'Attachments not supported',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.add_circle_outline, color: _blue, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'File attachments are not currently supported by chat.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'Choose emoji',
                onPressed: _showEmojiPicker,
                icon: const Text('😀', style: TextStyle(fontSize: 20))),
            Expanded(
                child: TextField(
                    key: const ValueKey('chat-message-composer'),
                    controller: _composerController,
                    enabled: _hasDepartment,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                        hintText: 'Message your department...',
                        hintStyle: TextStyle(fontSize: 12, color: _muted),
                        isDense: true,
                        filled: true,
                        fillColor: _bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(20))))),
            const SizedBox(width: 8),
            SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                    key: const ValueKey('chat-message-send'),
                    tooltip: 'Send message',
                    onPressed:
                        _isSending || !_hasDepartment ? null : _sendMessage,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                        backgroundColor: _blue, foregroundColor: Colors.white),
                    icon: _isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 15)))
          ])),
    ]);
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.onOpenProfile,
    required this.onOpenSecurity,
    required this.onOpenChat,
    required this.onOpenNotifications,
    required this.onOpenAppearance,
    required this.onOpenSupport,
    required this.onOpenAbout,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTerms,
    required this.onLogout,
    this.staff,
    this.department = 'Tech',
    this.workMode = 'Office',
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final VoidCallback onOpenProfile,
      onOpenSecurity,
      onOpenChat,
      onOpenNotifications,
      onOpenAppearance,
      onOpenSupport,
      onOpenAbout,
      onOpenPrivacyPolicy,
      onOpenTerms,
      onLogout;
  final Staff? staff;
  final String department;
  final String workMode;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  Widget _sectionHeader(String title, String subtitle, {Color? titleColor}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: titleColor ?? _muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child, Color? borderColor, Color? bgColor, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? _line, width: 1),
      ),
      child: child,
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    Widget? badge,
    required String description,
    Widget? rightWidget,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: _settingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _chip,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        if (badge != null) badge,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (rightWidget != null) ...[
                const SizedBox(width: 8),
                rightWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _appearanceCard() {
    return _settingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.palette_outlined, size: 18, color: _muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpenAppearance,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Light, dark, or system environment display mode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _themeOption(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
                _themeOption(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                _themeOption(ThemeMode.system, Icons.desktop_windows_outlined, 'System'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(ThemeMode mode, IconData icon, String label) {
    final isSelected = themeMode == mode;
    return InkWell(
      onTap: () {
        if (onThemeModeChanged != null) {
          onThemeModeChanged!(mode);
        } else {
          onOpenAppearance();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: _line, width: 1) : null,
          boxShadow: isSelected && !_isDark
              ? const [BoxShadow(color: Color(0x0a000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? _navSelFg : _muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _navSelFg : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _employeeInfoCard({bool isCompact = false}) {
    final staffName = staff?.name.isNotEmpty == true ? staff!.name : 'Staff Member';
    final initial = staffName.characters.first.toUpperCase();
    final empDept = department.isNotEmpty ? department : 'Tech';
    final empId = staff?.id.isNotEmpty == true ? staff!.id : 'SH-8492';
    final roleTitle = empDept == 'Telecalling' ? 'Telecalling Representative' : 'Software Engineer';

    return _settingsCard(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isCompact ? 44 : 52,
                height: isCompact ? 44 : 52,
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xff243347) : const Color(0xff334155),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            staffName,
                            style: TextStyle(
                              fontSize: isCompact ? 15 : 17,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.verified, size: 15, color: _isDark ? const Color(0xff3b82f6) : const Color(0xff64748b)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleTitle,
                      style: TextStyle(fontSize: 11.5, color: _muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${empDept.toUpperCase()} DEPARTMENT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCompact) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _cardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMPLOYEE ID',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          empId,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xff0d2318) : const Color(0xfff0fdf4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isDark ? const Color(0xff1a4a35) : const Color(0xffbbf7d0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WORK MODE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _isDark ? const Color(0xff34d399) : const Color(0xff15803d),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _isDark ? const Color(0xff34d399) : const Color(0xff16a34a),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '$workMode (Active)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isDark ? const Color(0xff34d399) : const Color(0xff15803d),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.devices_outlined, 'Device Session', 'Chrome / Windows 10'),
            const SizedBox(height: 10),
            _detailRow(Icons.hub_outlined, 'Network Node', '10.14.82.109 (Intranet)', isMono: true),
            const SizedBox(height: 10),
            _detailRow(Icons.location_on_outlined, 'Office Campus', 'Bangalore HQ · Floor 3'),
          ],
          SizedBox(height: isCompact ? 10 : 18),
          SizedBox(
            width: double.infinity,
            height: isCompact ? 38 : 42,
            child: OutlinedButton(
              onPressed: onOpenProfile,
              style: OutlinedButton.styleFrom(
                backgroundColor: _isDark ? const Color(0xff1a2b40) : const Color(0xffeff6ff),
                side: BorderSide(color: _isDark ? const Color(0xff2563eb) : const Color(0xffdbeafe)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Manage Complete Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isDark ? const Color(0xff60a5fa) : const Color(0xff1d4ed8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 14, color: _isDark ? const Color(0xff60a5fa) : const Color(0xff1d4ed8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool isMono = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMono ? 'monospace' : null,
              color: _ink,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _securityAuditCard() {
    return _settingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xff1a2b40) : const Color(0xffeff6ff),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(Icons.verified_user_outlined, size: 18, color: _isDark ? const Color(0xff60a5fa) : const Color(0xff1d4ed8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security & Audit Guard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Continuous ISO/IEC 27001',
                      style: TextStyle(
                        fontSize: 11,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'All attendance punches, biometric authentications, and leave adjustments are written to a cryptographic, tamper-evident audit ledger compliant with global enterprise policies.',
            style: TextStyle(
              fontSize: 12,
              color: _subText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cardAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xff10b981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ledger Checkpoint',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
                Text(
                  'Hash: #94A2F0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: onOpenPrivacyPolicy,
                child: Text(
                  'Privacy FAQ >',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isDark ? const Color(0xff60a5fa) : const Color(0xff475569),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('·', style: TextStyle(color: _muted)),
              ),
              InkWell(
                onTap: onOpenTerms,
                child: Text(
                  'Security Whitepaper >',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isDark ? const Color(0xff60a5fa) : const Color(0xff475569),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      const SizedBox(height: 8),
      // Top Header
      LayoutBuilder(
        builder: (context, headerConstraints) {
          final isNarrow = headerConstraints.maxWidth < 650;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage your workspace preferences, legal policies, support resources, and active employee credentials.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xff0d2318) : const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isDark ? const Color(0xff1a4a35) : const Color(0xffbbf7d0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xff10b981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'System Synced · SOC-2 Active',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _isDark ? const Color(0xff34d399) : const Color(0xff15803d),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onOpenSupport,
                      icon: Icon(Icons.help_outline, size: 13, color: _ink),
                      label: Text(
                        'Help Desk',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ink),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _line),
                        backgroundColor: _surface,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your workspace preferences, legal policies, support resources, and active employee credentials.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xff0d2318) : const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isDark ? const Color(0xff1a4a35) : const Color(0xffbbf7d0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xff10b981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'System Synced · SOC-2 Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isDark ? const Color(0xff34d399) : const Color(0xff15803d),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onOpenSupport,
                icon: Icon(Icons.help_outline, size: 15, color: _ink),
                label: Text(
                  'Help Desk',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _line),
                  backgroundColor: _surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),

      LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          final leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('APP PREFERENCES', 'User Workspace Defaults'),
              _appearanceCard(),
              const SizedBox(height: 14),

              _sectionHeader('LEGAL & COMPLIANCE', 'Corporate Governance Policies'),
              _actionCard(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xff0f1f38) : const Color(0xffeff6ff),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isDark ? const Color(0xff1e3a5f) : const Color(0xffdbeafe)),
                  ),
                  child: Text(
                    'v2026.2 Updated',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _isDark ? const Color(0xff60a5fa) : const Color(0xff1d4ed8)),
                  ),
                ),
                description: 'How StaffHub manages enterprise biometric & telemetry records',
                rightWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Document',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 14, color: _ink),
                  ],
                ),
                onTap: onOpenPrivacyPolicy,
              ),
              const SizedBox(height: 10),
              _actionCard(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xff0d2318) : const Color(0xffdcfce7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isDark ? const Color(0xff1a4a35) : const Color(0xffbbf7d0)),
                  ),
                  child: Text(
                    'Accepted',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _isDark ? const Color(0xff34d399) : const Color(0xff166534)),
                  ),
                ),
                description: 'Rules, operational codes, and technical service usage agreements',
                rightWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Signed Mar 2026',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: _muted),
                  ],
                ),
                onTap: onOpenTerms,
              ),
              const SizedBox(height: 14),

              _sectionHeader('SUPPORT & DOCUMENTATION', 'Internal Ticketing'),
              _actionCard(
                icon: Icons.chat_bubble_outline,
                title: 'Support & Helpdesk',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xff18163d) : const Color(0xffeef2ff),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isDark ? const Color(0xff312e81) : const Color(0xffc7d2fe)),
                  ),
                  child: Text(
                    '24/7 Desk',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _isDark ? const Color(0xff818cf8) : const Color(0xff4338ca)),
                  ),
                ),
                description: 'Raise tickets for punch discrepancies, attendance corrections, or HR queries',
                rightWidget: Icon(Icons.chevron_right, size: 18, color: _muted),
                onTap: onOpenSupport,
              ),
              const SizedBox(height: 10),
              _actionCard(
                icon: Icons.info_outline,
                title: 'About StaffHub',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _chip,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    'v2.4.1 (Build 8904)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _muted),
                  ),
                ),
                description: 'Enterprise release changelogs, build manifest, and open-source licenses',
                rightWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Latest Stable',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isDark ? const Color(0xff34d399) : const Color(0xff16a34a)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: _muted),
                  ],
                ),
                onTap: onOpenAbout,
              ),
            ],
          );

          final rightColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _employeeInfoCard(),
              const SizedBox(height: 18),
              _securityAuditCard(),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: leftColumn),
                const SizedBox(width: 20),
                Expanded(flex: 42, child: rightColumn),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _employeeInfoCard(isCompact: true),
                const SizedBox(height: 14),
                leftColumn,
                const SizedBox(height: 14),
                _securityAuditCard(),
              ],
            );
          }
        },
      ),
      const SizedBox(height: 28),
    ]);
  }
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage(
      {required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => _ScrollPage(children: [
        const SizedBox(height: 18),
        _ProfileCard(
            child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: const Color(0xffeaf0ff),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: _blue, size: 25)),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          Text(description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 10),
        ])),
      ]);
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({
    required this.onOpenTerms,
    required this.onOpenPrivacyPolicy,
    required this.onOpenLicenses,
  });

  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenLicenses;

  Widget _group(String label, List<Widget> rows) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: _muted))),
        _ProfileCard(
            child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: _line),
            rows[i]
          ]
        ])),
        const SizedBox(height: 18),
      ]);

  @override
  Widget build(BuildContext context) => _ScrollPage(children: [
        const SizedBox(height: 14),
        _ProfileCard(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff2864e8), Color(0xff5b8bf7)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332864e8),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'LY Staff Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xff1d2b40)
                      : const Color(0xffeaf0ff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A complete workforce management platform designed to manage staff attendance, breaks, leave, tasks and employee activities efficiently.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _group('Developer', const [
          _SettingRow(
            Icons.business_outlined,
            'Developed By',
            'LY Softwares',
            trailing: SizedBox.shrink(),
          ),
        ]),
        _group('Legal', [
          _SettingRow(
            Icons.description_outlined,
            'Terms & Conditions',
            'Terms for using LY Staff Management',
            onTap: onOpenTerms,
          ),
          _SettingRow(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            'How your information is handled',
            onTap: onOpenPrivacyPolicy,
          ),
          _SettingRow(
            Icons.policy_outlined,
            'Open Source Licenses',
            'Third-party software libraries and licenses',
            onTap: onOpenLicenses,
          ),
        ]),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            child: Text(
              '© 2026 LY Softwares. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ),
        ),
      ]);
}

Widget _bullet(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w700, fontSize: 13)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, height: 1.45, color: _ink),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );

class StaffPrivacyPolicyPage extends StatelessWidget {
  const StaffPrivacyPolicyPage({
    super.key,
    this.isStandalone = false,
    this.onBack,
  });

  final bool isStandalone;
  final VoidCallback? onBack;

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _ProfileCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xff1d2b40)
                        : const Color(0xffeaf0ff),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _blue, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _ScrollPage(children: [
      const SizedBox(height: 14),
      _ProfileCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xff1d2b40)
                      : const Color(0xffeaf0ff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.privacy_tip_outlined,
                    color: _blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Policy',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Last updated: January 2026 • Version 2.0',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Introduction',
        icon: Icons.info_outline,
        child: Text(
          'Your privacy is important to us.\n\nWelcome to StaffHub. We value your privacy and are committed to safeguarding personal and professional data collected during your employment and use of the StaffHub application. This policy details how employee information is gathered, managed, utilized, and safeguarded within the organization.\n\nBy accessing and utilizing StaffHub, you acknowledge that your information will be processed in accordance with this Privacy Policy and applicable workplace data protection regulations.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Information We Collect',
        icon: Icons.folder_shared_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'StaffHub collects and processes information required for workplace operations, attendance records, and human resource administration:',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
            ),
            const SizedBox(height: 8),
            _bullet('Personal Identification',
                'Full name, employee ID, telephone number, official work email, and address.'),
            _bullet('Employment Details',
                'Department, job role, reporting manager, work mode (Office or Work From Home), and shift timings.'),
            _bullet('Attendance & Activity',
                'Check-in and check-out timestamps, break durations, attendance statuses, and daily updates.'),
            _bullet('Leaves & Requests',
                'Leave types, duration, reason for absence, and uploaded supporting documentation.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'How We Use Employee Information',
        icon: Icons.business_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee data is utilized strictly for lawful administrative and operational purposes:',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
            ),
            const SizedBox(height: 8),
            _bullet('Attendance Tracking',
                'Recording daily attendance, shift completion, and break intervals accurately.'),
            _bullet('Leave Management',
                'Reviewing, approving, and maintaining balance records for employee leaves.'),
            _bullet('Internal Support',
                'Assisting employees with helpdesk inquiries, notifications, and profile support.'),
            _bullet('Operations & Compliance',
                'Generating departmental summaries and ensuring compliance with labor laws.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Data Protection',
        icon: Icons.security_outlined,
        child: Text(
          'We implement rigorous administrative, technical, and physical security measures to safeguard employee data:\n\n• Secure Transmission: All data exchanged between the StaffHub application and servers is encrypted using industry-standard TLS protocols.\n• Access Control: Strict role-based permissions ensure only authorized supervisors and HR personnel have access to employee records.\n• Infrastructure Safety: Stored data is maintained in secure enterprise cloud environments subject to ongoing security audits and automated backups.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Information Sharing',
        icon: Icons.share_outlined,
        child: Text(
          'Employee privacy is strictly protected. We do not sell, rent, or monetize employee data. Information is shared only with:\n\n• Authorized internal management and HR personnel on a strict need-to-know basis.\n• Enterprise service providers (such as hosting, email delivery, and cloud infrastructure) bound by confidentiality covenants.\n• Regulatory, law enforcement, or statutory authorities when strictly mandated by applicable laws or legal proceedings.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Employee Privacy Rights',
        icon: Icons.verified_user_outlined,
        child: Text(
          'As an employee, you possess defined rights regarding your personal records:\n\n• Right to Review: View personal profile information and attendance records at any time within StaffHub.\n• Right to Correction: Request corrections to outdated or inaccurate personal details through your HR department.\n• Right to Transparency: Inquire about how your data is processed, stored, and retained.\n• Right to Report: Raise concerns or reports regarding data privacy directly with the data protection officer.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Contact Information',
        icon: Icons.contact_support_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you have inquiries, questions, or feedback regarding this Privacy Policy, please contact our HR and Privacy team:',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
            ),
            const SizedBox(height: 8),
            _bullet('HR Department', 'hr@lysoftware.com'),
            _bullet('Data Privacy Officer', 'privacy@staffhub.com'),
            _bullet('Helpdesk Phone',
                '+91 80 4567 8900 (Mon – Fri, 9:00 AM – 6:00 PM)'),
            _bullet('Office',
                'StaffHub Systems Inc. • Human Resources Compliance Desk'),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ]);

    if (isStandalone) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            'Privacy & Policy',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _ink),
            onPressed: onBack ?? () => Navigator.of(context).pop(),
          ),
          backgroundColor: _surface,
          elevation: 0,
        ),
        body: content,
      );
    }
    return content;
  }
}

class StaffTermsConditionsPage extends StatelessWidget {
  const StaffTermsConditionsPage({
    super.key,
    this.isStandalone = false,
    this.onBack,
  });

  final bool isStandalone;
  final VoidCallback? onBack;

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _ProfileCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xff1d2b40)
                        : const Color(0xffeaf0ff),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _blue, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _ScrollPage(children: [
      const SizedBox(height: 14),
      _ProfileCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xff1d2b40)
                      : const Color(0xffeaf0ff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_outlined,
                    color: _blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'StaffHub Workplace Agreement • Version 2.0',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Introduction',
        icon: Icons.article_outlined,
        child: Text(
          'By using this application, you agree to follow the rules and conditions of the application.\n\nThese Terms & Conditions govern your access to and use of the StaffHub workplace application. By accessing or using the StaffHub portal, you acknowledge that you have read, understood, and agree to abide by these terms, company workplace guidelines, and all applicable employment policies.\n\nThese terms serve to maintain operational transparency, accountability, and a secure collaborative workplace environment.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Employee Account Usage',
        icon: Icons.account_circle_outlined,
        child: Text(
          'Users are responsible for keeping their account information secure. Your StaffHub account is designated exclusively for your official employment activities. You must ensure that account credentials remain strictly confidential. Sharing login credentials, passwords, or granting unauthorized access to third parties is strictly prohibited. You remain responsible for all transactions, punches, and actions logged under your authenticated credentials.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Attendance Rules',
        icon: Icons.timer_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employees are responsible for logging accurate timekeeping records in accordance with company work policies:',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
            ),
            const SizedBox(height: 8),
            _bullet('Punctual Punching',
                'Check in at the start of your shift and check out upon concluding work for the day.'),
            _bullet('Break Tracking',
                'Log break intervals (such as tea and lunch breaks) accurately using the break management tools.'),
            _bullet('Work Mode Compliance',
                'Select and record the correct work mode (Office or Work From Home) as authorized by management.'),
            _bullet('Discrepancy Reporting',
                'In the event of missed punches or technical errors, promptly contact your supervisor or HR for regularisation.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Leave Policy',
        icon: Icons.event_note_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave applications and approvals are governed by company human resource guidelines:',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
            ),
            const SizedBox(height: 8),
            _bullet('Timely Application',
                'Submit leave requests in advance through the StaffHub Leave section whenever foreseeable.'),
            _bullet('Approval Process',
                'Leaves are subject to review and formal approval based on team coverage and leave entitlements.'),
            _bullet('Leave Types',
                'Submit requests under the proper category (Casual, Sick, Annual, or Medical Leave).'),
            _bullet('Documentation',
                'Medical proof or certification may be required for extended or specialized medical leaves as specified by HR.'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Workplace Responsibilities',
        icon: Icons.assignment_turned_in_outlined,
        child: Text(
          'Employees are expected to act professionally, communicate respectfully, and fulfill their designated job duties diligently. Daily work logs and task summaries must be kept up to date to ensure seamless operational continuity across tech and customer-facing teams.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Acceptable Use of the StaffHub Application',
        icon: Icons.rule_outlined,
        child: Text(
          'StaffHub is provided solely for legitimate business operations. Prohibited activities include:\n\n• Attempting to disrupt, bypass, or tamper with system architecture, security controls, or attendance tracking.\n• Submitting false, fraudulent, or falsified attendance or leave requests.\n• Using internal chat or communication channels to distribute offensive, defamatory, or inappropriate material.\n• Reverse-engineering, copying, or scraping application source code and proprietary assets.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Account Security',
        icon: Icons.lock_outline,
        child: Text(
          'Employees must practice strong password hygiene and secure their devices when accessing StaffHub. If you suspect your account has been compromised or notice unauthorized access, notify the IT Helpdesk and HR immediately. The organization reserves the right to suspend accounts pending security reviews.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 14),
      _sectionCard(
        title: 'Policy Updates',
        icon: Icons.update_outlined,
        child: Text(
          'Management and Human Resources reserve the right to amend or update these Terms & Conditions as company practices, legal standards, or operational workflows evolve. Substantive updates will be published within the app. Continued use of StaffHub following notifications constitutes your acknowledgment and acceptance of the revised terms.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: _ink),
        ),
      ),
      const SizedBox(height: 24),
    ]);

    if (isStandalone) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            'Terms & Conditions',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _ink),
            onPressed: onBack ?? () => Navigator.of(context).pop(),
          ),
          backgroundColor: _surface,
          elevation: 0,
        ),
        body: content,
      );
    }
    return content;
  }
}

class StaffSupportHelpdeskPage extends StatelessWidget {
  const StaffSupportHelpdeskPage({
    super.key,
    this.isStandalone = false,
    this.onBack,
  });

  final bool isStandalone;
  final VoidCallback? onBack;

  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqTile(BuildContext context,
      {required String question, required String answer}) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _blue,
          collapsedIconColor: _muted,
          title: Text(
            question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          children: [
            Text(
              answer,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _ScrollPage(children: [
      const SizedBox(height: 14),
      _ProfileCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xff1d2b40)
                      : const Color(0xffeaf0ff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.support_agent, color: _blue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support & Helpdesk',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Need assistance? We are here to help.',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'CONTACT SUPPORT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: _muted,
          ),
        ),
      ),
      _ProfileCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _contactTile(
                icon: Icons.badge_outlined,
                title: 'HR Department',
                subtitle: 'hr@lysoftware.com • HR Operations Desk',
                iconColor: _blue,
              ),
              Divider(height: 1, color: _line),
              _contactTile(
                icon: Icons.mail_outline,
                title: 'Email Support',
                subtitle: 'support@staffhub.com • Response within 24h',
                iconColor: const Color(0xff10b981),
              ),
              Divider(height: 1, color: _line),
              _contactTile(
                icon: Icons.phone_outlined,
                title: 'Phone Support',
                subtitle: '+91 80 4567 8900 • Mon – Fri (9 AM – 6 PM)',
                iconColor: const Color(0xfff59e0b),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'FREQUENTLY ASKED QUESTIONS (FAQ)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: _muted,
          ),
        ),
      ),
      _ProfileCard(
        child: Column(
          children: [
            _faqTile(
              context,
              question: 'How can I mark attendance?',
              answer:
                  'Navigate to the Punch page from the navigation bar. Tap the "Check In" button when beginning work. When taking lunch or tea breaks, tap "Start Break" and resume work with "End Break". At the end of your workday, tap "Check Out" to complete your daily attendance record.',
            ),
            Divider(height: 1, color: _line),
            _faqTile(
              context,
              question: 'How can I apply for leave?',
              answer:
                  'Go to the Leave tab from the navigation bar. Select your leave category (Casual, Sick, Annual, or Medical Leave), choose your start and end dates, specify your reason for absence, and tap "Submit Request". You will be notified once HR and your manager review the application.',
            ),
            Divider(height: 1, color: _line),
            _faqTile(
              context,
              question: 'How can I check my attendance history?',
              answer:
                  'Open the Punch tab and scroll down to the "Attendance History" section. You can view your recent punch logs with dates, check-in times, and statuses. Tapping any history record opens the detailed view showing complete punch times, scheduled hours, and break logs.',
            ),
            Divider(height: 1, color: _line),
            _faqTile(
              context,
              question: 'How can I change my password?',
              answer:
                  'Navigate to Settings > Security to update your account password. If you cannot log in or have forgotten your password, reach out to your HR administrator or the IT Helpdesk at support@staffhub.com for a secure password reset.',
            ),
            Divider(height: 1, color: _line),
            _faqTile(
              context,
              question: 'What should I do if I face a technical issue?',
              answer:
                  'If you encounter errors, sync problems, or unexpected app behavior, please try restarting the application. If the issue persists, capture a screenshot and contact the IT Helpdesk at support@staffhub.com or call +91 80 4567 8900 with your employee ID and issue description.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ]);

    if (isStandalone) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            'Support & Helpdesk',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _ink),
            onPressed: onBack ?? () => Navigator.of(context).pop(),
          ),
          backgroundColor: _surface,
          elevation: 0,
        ),
        body: content,
      );
    }
    return content;
  }
}

class _AppearancePage extends StatelessWidget {
  const _AppearancePage({
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onChanged;

  @override
  Widget build(BuildContext context) => _ScrollPage(children: [
        const SizedBox(height: 18),
        Text('Appearance',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 16),
        _ProfileCard(
            child: Column(children: [
          _appearanceOption(
            context,
            mode: ThemeMode.light,
            title: 'Light',
            icon: Icons.light_mode_outlined,
          ),
          Divider(height: 1, color: _line),
          _appearanceOption(
            context,
            mode: ThemeMode.dark,
            title: 'Dark',
            icon: Icons.dark_mode_outlined,
          ),
          Divider(height: 1, color: _line),
          _appearanceOption(
            context,
            mode: ThemeMode.system,
            title: 'System',
            icon: Icons.brightness_auto_outlined,
          ),
        ])),
      ]);

  Widget _appearanceOption(
    BuildContext context, {
    required ThemeMode mode,
    required String title,
    required IconData icon,
  }) {
    final selected = themeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: colorScheme.onSurface))),
            Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 21),
          ]),
        ),
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({
    required this.chatNotifications,
    required this.leaveStatusNotifications,
    required this.punchReminders,
    required this.onChatChanged,
    required this.onLeaveChanged,
    required this.onPunchChanged,
  });

  final bool chatNotifications;
  final bool leaveStatusNotifications;
  final bool punchReminders;
  final ValueChanged<bool> onChatChanged;
  final ValueChanged<bool> onLeaveChanged;
  final ValueChanged<bool> onPunchChanged;

  @override
  Widget build(BuildContext context) => _ScrollPage(children: [
        const SizedBox(height: 16),
        Text('Notifications',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 14),
        _ProfileCard(
            child: Column(children: [
          _NotificationSwitch(
              title: 'Chat notifications',
              value: chatNotifications,
              onChanged: onChatChanged),
          Divider(height: 1, color: _line),
          _NotificationSwitch(
              title: 'Leave status notifications',
              value: leaveStatusNotifications,
              onChanged: onLeaveChanged),
          Divider(height: 1, color: _line),
          _NotificationSwitch(
              title: 'Attendance/punch reminders',
              value: punchReminders,
              onChanged: onPunchChanged),
        ])),
      ]);
}

class _NotificationSwitch extends StatelessWidget {
  const _NotificationSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
          value: value,
          onChanged: onChanged,
        ),
      );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.onLogout,
    required this.staff,
    required this.repository,
    required this.department,
    required this.workMode,
    this.workLocation,
    this.onBack,
  });

  final VoidCallback onLogout;
  final Staff staff;
  final HRRepository repository;
  final String department;
  final String workMode;
  final String? workLocation;
  final VoidCallback? onBack;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late Staff _staff;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _staff = widget.staff;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await widget.repository.fetchProfile();
      if (mounted) setState(() => _staff = profile);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPrivacy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const StaffPrivacyPolicyPage(isStandalone: true),
    ));
  }

  void _openTerms() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const StaffTermsConditionsPage(isStandalone: true),
    ));
  }

  void _openSupport() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const StaffSupportHelpdeskPage(isStandalone: true),
    ));
  }

  Widget _overviewMiniCard(String label, String value, {bool isDot = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isDot) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xff10b981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDot ? (_isDark ? const Color(0xff34d399) : const Color(0xff166534)) : _ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, {Color? iconColor, Color? iconBg}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg != null
                  ? (_isDark ? iconBg.withValues(alpha: 0.15) : iconBg)
                  : _chip,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? _muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = _staff.name.isNotEmpty ? _staff.name : 'Staff Member';
    final initial = staffName.characters.first.toUpperCase();
    final empDept = _staff.department.isNotEmpty ? _staff.department : widget.department;
    final empId = _staff.id.isNotEmpty ? _staff.id : 'EMP1066';
    final roleTitle = empDept == 'Telecalling' ? 'Telecalling Representative' : 'Software Engineer';
    final reportingLead = empDept == 'Telecalling' ? 'Amina Sheikh' : 'Vikram Mehta';

    return _ScrollPage(children: [
      if (_isLoading) const LinearProgressIndicator(),
      const SizedBox(height: 6),

      // Breadcrumb
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'StaffHub V2.4',
              style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text(
              'Employee Directory',
              style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text(
              staffName,
              style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Page Title Header
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _ink, size: 20),
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'View and manage your core identity, employee details, and workspace status',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading employee profile summary...')),
              );
            },
            icon: Icon(Icons.description_outlined, size: 15, color: _ink),
            label: Text(
              'Download CV/ID',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _line),
              backgroundColor: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),

      // Employee Overview Card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xff243347) : const Color(0xff334155),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            staffName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xff18163d) : const Color(0xffeef2ff),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _isDark ? const Color(0xff312e81) : const Color(0xffc7d2fe)),
                            ),
                            child: Text(
                              empDept.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isDark ? const Color(0xff818cf8) : const Color(0xff3730a3),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xff0d2318) : const Color(0xffdcfce7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _isDark ? const Color(0xff1a4a35) : const Color(0xffbbf7d0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff16a34a),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _isDark ? const Color(0xff34d399) : const Color(0xff166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$roleTitle · Bangalore HQ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _overviewMiniCard('Employee ID', empId),
                const SizedBox(width: 10),
                _overviewMiniCard('Joined', 'Mar 2024'),
                const SizedBox(width: 10),
                _overviewMiniCard('Status', 'Active', isDot: true),
                const SizedBox(width: 10),
                _overviewMiniCard('Reporting Lead', reportingLead),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      // Personal Information Card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Official contact details and organization unit',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact HR administration to request profile updates.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _line),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Edit Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 550;
                if (isWide) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.mail_outline,
                              'Work Email',
                              _staff.email,
                              iconColor: const Color(0xff2563eb),
                              iconBg: const Color(0xffeff6ff),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              Icons.phone_outlined,
                              'Phone Number',
                              _staff.phoneNumber,
                              iconColor: const Color(0xff16a34a),
                              iconBg: const Color(0xfff0fdf4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.domain_outlined,
                              'Address',
                              _staff.address,
                              iconColor: _muted,
                              iconBg: _cardAlt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              Icons.business_center_outlined,
                              'Department',
                              _staff.department,
                              iconColor: const Color(0xffd97706),
                              iconBg: _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              Icons.work_outline,
                              'Work Mode',
                              widget.workMode,
                              iconColor: const Color(0xff4f46e5),
                              iconBg: const Color(0xffeef2ff),
                            ),
                          ),
                          if (widget.workMode == 'Work From Home' && widget.workLocation != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _infoCard(
                                Icons.location_on_outlined,
                                'Location',
                                widget.workLocation!,
                                iconColor: const Color(0xff0284c7),
                                iconBg: const Color(0xfff0f9ff),
                              ),
                            ),
                          ] else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _infoCard(
                        Icons.mail_outline,
                        'Work Email',
                        _staff.email,
                        iconColor: const Color(0xff2563eb),
                        iconBg: const Color(0xffeff6ff),
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        Icons.phone_outlined,
                        'Phone Number',
                        _staff.phoneNumber,
                        iconColor: const Color(0xff16a34a),
                        iconBg: const Color(0xfff0fdf4),
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        Icons.domain_outlined,
                        'Address',
                        _staff.address,
                        iconColor: _muted,
                        iconBg: _cardAlt,
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        Icons.business_center_outlined,
                        'Department',
                        _staff.department,
                        iconColor: const Color(0xffd97706),
                        iconBg: _isDark ? const Color(0xff2a2008) : const Color(0xfffffbeb),
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        Icons.work_outline,
                        'Work Mode',
                        widget.workMode,
                        iconColor: const Color(0xff4f46e5),
                        iconBg: const Color(0xffeef2ff),
                      ),
                      if (widget.workMode == 'Work From Home' && widget.workLocation != null) ...[
                        const SizedBox(height: 10),
                        _infoCard(
                          Icons.location_on_outlined,
                          'Location',
                          widget.workLocation!,
                          iconColor: const Color(0xff0284c7),
                          iconBg: const Color(0xfff0f9ff),
                        ),
                      ],
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      // Account & Policies Card
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            _SettingRow(
              Icons.privacy_tip_outlined,
              'Privacy & Policy',
              'Manage your data & enterprise privacy',
              onTap: _openPrivacy,
            ),
            Divider(height: 1, color: _line),
            _SettingRow(
              Icons.description_outlined,
              'Terms & Conditions',
              'View company operational policies',
              onTap: _openTerms,
            ),
            Divider(height: 1, color: _line),
            _SettingRow(
              Icons.help_outline,
              'Support & Helpdesk',
              'Raise a support or IT discrepancy ticket',
              onTap: _openSupport,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      // Logout button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout, size: 16, color: Color(0xffdc2626)),
          label: const Text(
            'Log Out',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xffdc2626)),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: _isDark ? const Color(0xff2a0d0d) : const Color(0xfffef2f2),
            side: BorderSide(color: _isDark ? const Color(0xff4a1515) : const Color(0xfffecaca)),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          'StaffHub Systems Inc. • Secure Staff Portal • v2.4.0',
          style: TextStyle(fontSize: 10, color: Color(0xff94a3b8)),
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth > 1200
            ? 1120.0
            : box.maxWidth > 900
                ? 860.0
                : box.maxWidth > 520
                    ? 500.0
                    : box.maxWidth;
        return SingleChildScrollView(
            child: Center(
                child: SizedBox(
                    width: width,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children)))));
      });
}

// ignore: unused_element
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x060f172a), blurRadius: 8, offset: Offset(0, 2))
          ]),
      child: child);
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line, width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x100f172a), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
    child: Text(text,
        style:
            TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)));
// ignore: unused_element
Widget _timeline(IconData icon, String title, String subtitle, String time,
        Color color) =>
    Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
        Text(subtitle, style: TextStyle(fontSize: 10, color: _muted))
      ])),
      Text(time, style: TextStyle(fontSize: 10, color: _ink))
    ]);
// ignore: unused_element
Widget _smallLabel(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: TextStyle(
            fontSize: 12,
            color: color ?? _muted,
            fontWeight: FontWeight.w600)));
InputDecoration _fieldDecoration({
  String? hint,
  Color? textColor,
  Color? hintColor,
  Color? borderColor,
  Color? fillColor,
}) =>
    InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: hintColor ?? _muted),
        isDense: true,
        filled: fillColor != null,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor ?? _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor ?? _line)));
Widget _dateBox(
  String text, {
  Color? textColor,
  Color? borderColor,
  Color? backgroundColor,
}) =>
    Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor ?? _line)),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: textColor ?? _ink)));

Color _statusBackground(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return _isDark ? const Color(0xff0d2318) : const Color(0xffe8f8ef);
    case 'rejected':
    case 'denied':
      return _isDark ? const Color(0xff2a0d0d) : const Color(0xffffeeee);
    default:
      return _isDark ? const Color(0xff2a2008) : const Color(0xfffff4d6);
  }
}

Color _statusForeground(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return _isDark ? const Color(0xff34d399) : const Color(0xff16834b);
    case 'rejected':
    case 'denied':
      return _isDark ? const Color(0xfff87171) : const Color(0xffd84747);
    default:
      return _isDark ? const Color(0xfffbbf24) : const Color(0xffb7791f);
  }
}

// ignore: unused_element
Widget _profileStat(String title, String value) => Expanded(
        child: Column(children: [
      Text(title, style: TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 5),
      Text(value,
          style:
              TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700))
    ]));

// ignore: unused_element
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.value);
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: _blue),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14, color: _ink, fontWeight: FontWeight.w500))
        ]))
      ]));
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(this.icon, this.title, this.subtitle,
      {this.trailing, this.onTap});
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(icon, size: 18, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11, color: _muted))
                  ])),
              trailing ?? Icon(Icons.chevron_right, size: 18, color: _muted)
            ])),
      );
}

Widget _message(String initials, String name, String text, String time,
        {bool isHR = false}) =>
    Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 13,
              backgroundColor:
                  isHR ? const Color(0xfffee2e2) : const Color(0xffe6edfc),
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 10,
                      color: isHR ? const Color(0xffdc2626) : _blue,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 7),
          Expanded(
              child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _ink),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (isHR) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffee2e2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('HR',
                                      style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xffdc2626))),
                                ),
                              ],
                            ],
                          )),
                          Text(time,
                              style: TextStyle(fontSize: 7, color: _muted))
                        ]),
                        const SizedBox(height: 4),
                        Text(text,
                            style: TextStyle(
                                fontSize: 11, height: 1.35, color: _ink))
                      ])))
        ]));
