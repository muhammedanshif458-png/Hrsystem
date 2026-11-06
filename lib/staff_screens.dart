import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'models.dart';
import 'hr_repository.dart';
import 'core/api/api_exception.dart';
import 'core/utils/file_download.dart';
import 'services/staff_chat_socket_service.dart';

const _blue = Color(0xff2864e8);
ThemeMode staffHubThemeMode = ThemeMode.light;

bool get _isDark => staffHubThemeMode == ThemeMode.dark;
Color get _ink => _isDark ? const Color(0xffeef2f7) : const Color(0xff1b2638);
Color get _muted => _isDark ? const Color(0xffaeb9c6) : const Color(0xff7b8798);
Color get _line => _isDark ? const Color(0xff354250) : const Color(0xffe8edf4);
Color get _bg => _isDark ? const Color(0xff10151c) : const Color(0xfff5f7fb);
Color get _surface => _isDark ? const Color(0xff151d26) : Colors.white;
Color get _fieldBg => _isDark ? const Color(0xff19232d) : Colors.white;

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
  final isDark = mode == ThemeMode.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor:
        isDark ? const Color(0xff10151c) : const Color(0xfff5f7fb),
    colorScheme: ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xff6f9cff) : _blue,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ),
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

  @override
  void initState() {
    super.initState();
    widget.repository.attendanceList.addListener(_onAttendanceChanged);
    widget.repository.leaveRequests.addListener(_onLeavesChanged);
    _loadAttendance();
    unawaited(widget.repository.fetchStaffLeaves());
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
      _settingsSubPage = 2;
      _chatSearchOpen = false;
    });
    widget.onNavigate(3);
  }

  void _toggleChatSearch() {
    setState(() => _chatSearchOpen = !_chatSearchOpen);
  }

  @override
  Widget build(BuildContext context) {
    final staffTheme = staffHubThemeData(widget.themeMode);
    final colorScheme = staffTheme.colorScheme;
    final settingsPage = switch (_settingsSubPage) {
      0 => _ProfilePage(
          onLogout: widget.onLogout,
          staff: widget.staff,
          repository: widget.repository,
          department: widget.department,
          workMode: widget.workMode,
          workLocation: widget.workLocation),
      1 => const _SettingsDetailPage(
          icon: Icons.lock_outline,
          title: 'Security',
          description: 'Manage password and account security'),
      2 => _ChatPage(
          searchOpen: _chatSearchOpen,
          staff: widget.staff,
          repository: widget.repository,
          department: widget.department,
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
          themeMode: widget.themeMode, onChanged: widget.onThemeModeChanged),
      5 => const _SettingsDetailPage(
          icon: Icons.help_outline,
          title: 'Help & Support',
          description: 'Get help with StaffHub'),
      6 => _AboutPage(
          onOpenTerms: () => setState(() => _settingsSubPage = 8),
          onOpenPrivacyPolicy: () => setState(() => _settingsSubPage = 7),
          onOpenLicenses: () => showLicensePage(
            context: context,
            applicationName: 'LY Staff Management',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 LY Softwares. All rights reserved.',
          ),
        ),
      7 => const _SettingsDocumentPage(
          title: 'Privacy Policy', content: '''Your privacy is important to us.

    This application collects user information such as name, email, phone number and address for account management and application functionality.

    Your information will be handled securely and will not be shared unnecessarily with third parties.

    By using this application, you agree to the collection and use of information as described in this Privacy Policy.'''),
      8 => const _SettingsDocumentPage(
          title: 'Terms & Conditions',
          content:
              '''By using this application, you agree to follow the rules and conditions of the application.

    Users are responsible for keeping their account information secure.

    The application should only be used for its intended purpose.

    We reserve the right to update these terms when necessary.'''),
      _ => _SettingsPage(
          onOpenProfile: () => setState(() => _settingsSubPage = 0),
          onOpenSecurity: () => setState(() => _settingsSubPage = 1),
          onOpenChat: () => setState(() => _settingsSubPage = 2),
          onOpenNotifications: () => setState(() => _settingsSubPage = 3),
          onOpenAppearance: () => setState(() => _settingsSubPage = 4),
          onOpenSupport: () => setState(() => _settingsSubPage = 5),
          onOpenAbout: () => setState(() => _settingsSubPage = 6),
          onOpenPrivacyPolicy: () => setState(() => _settingsSubPage = 7),
          onOpenTerms: () => setState(() => _settingsSubPage = 8),
          onLogout: widget.onLogout),
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
            5 => 'Help & Support',
            6 => 'About',
            7 => 'Privacy Policy',
            8 => 'Terms & Conditions',
            _ => 'Settings',
          }
        : titles[widget.pageIndex];
    final isChatPage = widget.pageIndex == 3 && _settingsSubPage == 2;
    return Theme(
      data: staffTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.15),
        ),
        child: Scaffold(
          backgroundColor: staffTheme.scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: AppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surface,
              elevation: 0,
              titleSpacing: 14,
              leading: widget.pageIndex == 3 && _settingsSubPage != null
                  ? IconButton(
                      icon:
                          Icon(Icons.arrow_back, color: colorScheme.onSurface),
                      onPressed: () => setState(() => _settingsSubPage = null),
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
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(7)),
                          child: Icon(Icons.badge_outlined,
                              size: 15, color: colorScheme.onPrimary)),
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
                      color: const Color(0xffe9f0ff),
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(widget.department.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: _blue,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4)),
                ),
                if (widget.pageIndex == 0)
                  IconButton(
                    tooltip: 'Open chat',
                    onPressed: _openChat,
                    icon: Icon(Icons.chat_bubble_outline,
                        size: 20, color: colorScheme.primary),
                  ),
                if (isChatPage)
                  IconButton(
                    tooltip: _chatSearchOpen
                        ? 'Close search'
                        : 'Search messages or staff',
                    onPressed: _toggleChatSearch,
                    icon: Icon(_chatSearchOpen ? Icons.close : Icons.search,
                        size: 20, color: colorScheme.onSurfaceVariant),
                  ),
                if (widget.pageIndex == 3 && _settingsSubPage == 3)
                  Icon(Icons.notifications_none,
                      size: 19, color: colorScheme.onSurfaceVariant),
                if (widget.pageIndex == 3 && _settingsSubPage == 3)
                  const SizedBox(width: 14),
                // CircleAvatar(radius: 12, backgroundColor: const Color(0xffe2eaf8), child: Text('A', style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w700))),
                // const SizedBox(width: 13),
              ],
            ),
          ),
          body: SafeArea(top: false, child: pages[widget.pageIndex]),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              iconTheme:
                  WidgetStateProperty.resolveWith((states) => IconThemeData(
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
                  setState(() => _settingsSubPage = null);
                }
                if (index == 0 || index == 2) {
                  unawaited(widget.repository.fetchStaffLeaves());
                }
                widget.onNavigate(index);
              },
              backgroundColor: colorScheme.surface,
              indicatorColor: colorScheme.primaryContainer,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    _refreshDailyUpdates();
    unawaited(widget.repository.fetchStaffLeaves());
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
    return _ScrollPage(children: [
      const SizedBox(height: 12),
      Text('Wednesday, 24 Sep', style: TextStyle(fontSize: 14, color: _muted)),
      const SizedBox(height: 5),
      Row(children: [
        Expanded(
            child: Text('Good Morning, ${widget.staffName} 👋',
                style: TextStyle(
                    fontSize: 20, color: _ink, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),
      Text('Department: ${widget.department}  ·  Work Mode: ${widget.workMode}',
          style: TextStyle(fontSize: 12, color: _muted)),
      if (widget.workMode == 'Work From Home' &&
          widget.workLocation != null) ...[
        const SizedBox(height: 4),
        Text('📍 Location: ${widget.workLocation}',
            style: TextStyle(fontSize: 12, color: _muted)),
      ],
      const SizedBox(height: 18),
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
      _ProfileCard(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _pill(
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
                                  : const Color(0xffd84747)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('Shift: $shiftText',
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(fontSize: 11, color: _muted))))
                    ]),
                    const SizedBox(height: 16),
                    Text('ACTIVE TIME',
                        style: TextStyle(
                            fontSize: 12, color: _muted, letterSpacing: .5)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(trackedText,
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                              const SizedBox(width: 5),
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('hrs',
                                      style: TextStyle(
                                          fontSize: 12, color: _muted)))
                            ]),
                        if (widget.isLoadingAttendance)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    Text(
                        widget.checkOutTime != null
                            ? checkOutText
                            : hasActiveShift
                                ? 'Checked in at $checkInText'
                                : 'Please check in to start your shift',
                        style: TextStyle(fontSize: 12, color: _muted)),
                    const SizedBox(height: 6),
                    if (activeBreak != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          activeBreak.remainingTimeText(now),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      const SizedBox(height: 2),
                      Text(
                          '${AttendanceBreakSchedule.nameForType(activeBreak.breakType)} · Started ${TimeOfDay.fromDateTime(activeBreak.startTime).format(context)}',
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text('Upcoming Break',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      Text(
                          'Tea Breaks and Lunch Break · Whenever you need them',
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: !widget.checkedIn ||
                                  widget.isPunching ||
                                  widget.isLoadingAttendance ||
                                  widget.attendanceError != null ||
                                  _breakActionInFlight
                              ? null
                              : activeBreak != null
                                  ? () async {
                                      setState(
                                          () => _breakActionInFlight = true);
                                      try {
                                        await widget.onToggleBreak(null);
                                      } finally {
                                        if (mounted)
                                          setState(() =>
                                              _breakActionInFlight = false);
                                      }
                                    }
                                  : _chooseAndStartBreak,
                          icon: Icon(
                              activeBreak == null
                                  ? Icons.free_breakfast_outlined
                                  : Icons.stop_circle_outlined,
                              size: 15),
                          label: Text(
                              _breakActionInFlight
                                  ? 'Please wait...'
                                  : activeBreak == null
                                      ? 'Start Break'
                                      : 'End Break',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
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
                                  widget.checkedIn ? Icons.logout : Icons.login,
                                  size: 13),
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
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ]))),
      const SizedBox(height: 18),
      _ProfileCard(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Row(children: [
                        Icon(Icons.assignment_outlined, size: 15, color: _blue),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                _latestUpdate?.title.isNotEmpty == true
                                    ? _latestUpdate!.title
                                    : 'Daily Work Update',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: _ink,
                                    fontWeight: FontWeight.w700)))
                      ])),
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
                          onPressed: _isLoadingUpdate ? null : _editWorkUpdate,
                          child: Text(
                              _latestUpdate == null
                                  ? 'Add Update  ›'
                                  : 'Edit Update  ›',
                              style: TextStyle(fontSize: 12, color: _blue)))
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
                                    fontSize: 11, color: Color(0xffd84747))),
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
                    const SizedBox(height: 14),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: _isLoadingUpdate && _latestUpdate == null
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              )
                            : Text(
                                _latestUpdate?.updateText.isNotEmpty == true
                                    ? _latestUpdate!.updateText
                                    : 'No update submitted yet. Tap "Add Update" to submit.',
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: _latestUpdate == null
                                        ? _muted
                                        : _ink))),
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
                                style: TextStyle(fontSize: 10, color: _muted))),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text('✓ Synced',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: _muted)))
                      ]),
                    ],
                  ]))),
      const SizedBox(height: 18),
      _ProfileCard(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.campaign_outlined, 'HR Notice',
                        trailing: 'Today'),
                    const SizedBox(height: 14),
                    Text(
                        'Office will start at 9:30 AM tomorrow for scheduled infrastructure maintenance.',
                        style: TextStyle(
                            fontSize: 13, color: _muted, height: 1.45))
                  ]))),
      if (activeLeave != null) ...[
        const SizedBox(height: 12),
        _ProfileCard(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Row(children: [
                          Icon(Icons.event_note_outlined,
                              size: 13, color: _blue),
                          const SizedBox(width: 5),
                          Text('Leave Request Update',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _ink,
                                  fontWeight: FontWeight.w700))
                        ])),
                        _pill(
                            activeLeave.status,
                            _statusBackground(activeLeave.status),
                            _statusForeground(activeLeave.status)),
                      ]),
                      const SizedBox(height: 10),
                      Text('${activeLeave.type} · ${activeLeave.dates}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      const SizedBox(height: 5),
                      Text('Reason: ${activeLeave.reason}',
                          style: TextStyle(fontSize: 11, color: _ink)),
                      const SizedBox(height: 5),
                      Text(activeLeave.message,
                          style: TextStyle(
                              fontSize: 12, color: _muted, height: 1.4)),
                    ]))),
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
  });
  final String initialTitle;
  final String initialValue;
  final HRRepository repository;

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

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_hasChanges && !_isSaving,
        onPopInvoked: (didPop) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _surface,
            surfaceTintColor: _surface,
            elevation: 0,
            leading: IconButton(
                icon: Icon(Icons.arrow_back, color: _ink),
                onPressed: _isSaving ? null : _handleBack),
            title: Text('Edit Work Update',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
            actions: [
              TextButton(
                  onPressed: _isSaving ? null : _handleBack,
                  child: Text('Cancel', style: TextStyle(color: _blue)))
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      style: TextStyle(fontSize: 16, color: _ink),
                      decoration: _fieldDecoration(hint: 'Enter update title'),
                    ),
                    const SizedBox(height: 18),
                    Text('Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        expands: true,
                        enabled: !_isSaving,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style:
                            TextStyle(fontSize: 14, height: 1.5, color: _ink),
                        decoration: InputDecoration(
                          hintText: 'Enter today\'s work update',
                          filled: true,
                          fillColor: _fieldBg,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _line)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _blue)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Update',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      );
}

Color _workStatusBackground(String status) => switch (status) {
      'Completed' => const Color(0xffe8f8ef),
      'In Progress' => const Color(0xffeaf0ff),
      _ => const Color(0xfffff4d6),
    };

Color _workStatusForeground(String status) => switch (status) {
      'Completed' => const Color(0xff198754),
      'In Progress' => _blue,
      _ => const Color(0xffb7791f),
    };

class _PunchPage extends StatefulWidget {
  const _PunchPage(
      {required this.checkedIn,
      required this.checkInTime,
      required this.checkOutTime,
      required this.onToggle,
      required this.attendance,
      required this.onToggleBreak,
      required this.attendanceRecords,
      this.isPunching = false,
      this.repository,
      this.department,
      this.workMode});
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

  Widget _buildHistoryItem(BuildContext context, Attendance item) {
    final checkInDisplay = item.checkInTime.isNotEmpty
        ? formatShiftTime(item.checkInTime)
        : (item.checkInAt != null
            ? TimeOfDay.fromDateTime(item.checkInAt!).format(context)
            : 'Not recorded');

    final statusText = item.displayStatus;
    final isLateStatus = item.isLate;
    final sessionStatusText = item.sessionStatusLabel;
    final isOngoing = item.isOngoing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line, width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a0f172a),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? const Color(0xfffff7e6)
                        : const Color(0xffe9f0ff),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOngoing
                        ? Icons.timelapse_outlined
                        : Icons.calendar_today_outlined,
                    size: 17,
                    color: isOngoing ? const Color(0xffd48b0c) : _blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDisplayDate(item.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.login, size: 12, color: _muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'In: $checkInDisplay',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pill(
                      statusText,
                      isLateStatus
                          ? const Color(0xffffeeee)
                          : const Color(0xffe8f8ef),
                      isLateStatus
                          ? const Color(0xffd84747)
                          : const Color(0xff198754),
                    ),
                    const SizedBox(height: 3),
                    _pill(
                      sessionStatusText,
                      isOngoing
                          ? const Color(0xfffff7e6)
                          : const Color(0xffe9f0ff),
                      isOngoing ? const Color(0xffd48b0c) : _blue,
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        : 'Not checked in';
    final checkOutText = widget.checkOutTime == null
        ? 'Pending'
        : TimeOfDay.fromDateTime(widget.checkOutTime!).format(context);
    return _ScrollPage(children: [
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: Text("Today's Attendance",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _ink))),
        _pill(
            widget.checkedIn
                ? '● Active Shift'
                : widget.checkOutTime == null
                    ? '○ Not Checked In'
                    : '○ Shift Ended',
            widget.checkedIn
                ? const Color(0xffe8f8ef)
                : const Color(0xffffeeee),
            widget.checkedIn
                ? const Color(0xff198754)
                : const Color(0xffd84747))
      ]),
      const SizedBox(height: 8),
      _ProfileCard(
          child: Column(children: [
        Text('TOTAL TRACKED TODAY',
            style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 4),
        Text(trackedText,
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 16),
        Divider(height: 1, color: _line),
        const SizedBox(height: 14),
        _timeline(
            Icons.login,
            'Check In',
            hasActiveShift ? 'Recorded successfully' : 'Waiting for check in',
            checkInText,
            hasActiveShift ? const Color(0xff258154) : _muted),
        const SizedBox(height: 14),
        _timeline(
            Icons.logout,
            'Check Out',
            widget.checkedIn
                ? 'Waiting for check out'
                : widget.checkOutTime == null
                    ? 'Available after check in'
                    : 'Recorded successfully',
            checkOutText,
            widget.checkedIn
                ? const Color(0xffe6a328)
                : const Color(0xff258154)),
        const SizedBox(height: 14),
        _timeline(
            Icons.coffee_outlined,
            'Break Time',
            '${widget.attendance?.breaks.length ?? 0} break${(widget.attendance?.breaks.length ?? 0) == 1 ? '' : 's'}',
            _formatShortDuration(widget.attendance?.breaks.fold<int>(
                    0, (sum, b) => sum + b.durationAt(DateTime.now())) ??
                0),
            const Color(0xffa66a16)),
      ])),
      if (widget.attendance?.breaks.isNotEmpty == true) ...[
        const SizedBox(height: 14),
        Text('Break Details',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
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
                            style: TextStyle(
                                fontSize: 13,
                                color: _ink,
                                fontWeight: FontWeight.w600)),
                        Text(
                            '${_formatShortDuration(item.durationAt(DateTime.now()))} · ${item.isActive ? 'On Break' : 'Completed'}',
                            style: TextStyle(fontSize: 12, color: _muted)),
                      ])),
                ])),
        ])),
      ],
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          if (widget.attendanceRecords.isNotEmpty)
            TextButton.icon(
              key: const ValueKey('clear-attendance-history-button'),
              onPressed: _isClearingHistory ? null : _handleClearHistory,
              icon: _isClearingHistory
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.delete_sweep_outlined,
                      size: 15, color: Color(0xffd84747)),
              label: Text(
                'Clear History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isClearingHistory
                      ? _muted
                      : const Color(0xffd84747),
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
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
          _buildHistoryItem(context, item),
      const SizedBox(height: 18),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: widget.isPunching
                  ? null
                  : (widget.checkedIn || widget.checkOutTime == null
                      ? widget.onToggle
                      : null),
              icon: widget.isPunching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(widget.checkedIn ? Icons.logout : Icons.login,
                      size: 15),
              label: Text(widget.isPunching
                  ? (widget.checkedIn ? 'Checking out...' : 'Checking in...')
                  : (widget.checkedIn
                      ? 'Check Out'
                      : widget.checkOutTime != null
                          ? 'Shift Complete'
                          : 'Check In')),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      widget.checkedIn ? const Color(0xffd84747) : _blue))),
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
    final scheduledCheckInDisplay = record.scheduledCheckIn != null &&
            record.scheduledCheckIn!.isNotEmpty
        ? formatShiftTime(record.scheduledCheckIn!)
        : (record.scheduleSnapshot?['scheduledCheckIn'] != null
            ? formatShiftTime(
                record.scheduleSnapshot!['scheduledCheckIn'].toString())
            : defaultScheduledCheckIn);

    final scheduledCheckOutDisplay = record.scheduledCheckOut != null &&
            record.scheduledCheckOut!.isNotEmpty
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
                        ? const Color(0xfffff7e6)
                        : const Color(0xffe8f8ef),
                    isOngoing ? const Color(0xffd48b0c) : const Color(0xff198754),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  if (isOngoing) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff8ec),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xfffae0b5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: Color(0xffd48b0c)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Shift currently in progress. Checkout is pending.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xffa66a16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Attendance Summary
                  _sheetSectionHeader(Icons.summarize_outlined, 'Attendance Summary'),
                  const SizedBox(height: 8),
                  _sheetCard([
                    _sheetRow('Attendance Date', _formatDisplayDate(record.date)),
                    _sheetDivider(),
                    _sheetRow('Department', departmentName),
                    _sheetDivider(),
                    _sheetRow('Work Mode', workModeName),
                    _sheetDivider(),
                    _sheetRow(
                      'Attendance Status',
                      record.displayStatus,
                      valueColor: record.isLate
                          ? const Color(0xffd84747)
                          : const Color(0xff198754),
                      trailingBadge: _pill(
                        record.displayStatus,
                        record.isLate
                            ? const Color(0xffffeeee)
                            : const Color(0xffe8f8ef),
                        record.isLate
                            ? const Color(0xffd84747)
                            : const Color(0xff198754),
                      ),
                    ),
                    _sheetDivider(),
                    _sheetRow(
                        'Total Working Duration', workingDurationDisplay),
                  ]),

                  const SizedBox(height: 18),

                  // 2. Punch Details
                  _sheetSectionHeader(Icons.punch_clock_outlined, 'Punch Details'),
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
                                  style: TextStyle(
                                      fontSize: 11, color: _muted)),
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
                                  style: TextStyle(
                                      fontSize: 11, color: _muted)),
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
    final startDisplay =
        TimeOfDay.fromDateTime(b.startTime).format(context);
    final endDisplay = b.endTime != null
        ? TimeOfDay.fromDateTime(b.endTime!).format(context)
        : 'Active';
    final durationDisplay = b.durationMinutes != null && b.durationMinutes! > 0
        ? '${b.durationMinutes} min'
        : (b.isCompleted
            ? '${b.durationSeconds ~/ 60} min'
            : 'Ongoing');

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
                b.isActive ? const Color(0xfffff7e6) : const Color(0xffe8f8ef),
                b.isActive ? const Color(0xffd48b0c) : const Color(0xff198754),
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
                  fontSize: 11,
                  color: _muted,
                  fontStyle: FontStyle.italic),
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

  Widget _sheetDivider() =>
      Divider(height: 14, thickness: 0.8, color: _line);

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
  final weekday =
      (d.weekday >= 1 && d.weekday <= 7) ? days[d.weekday - 1] : '';
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

class _LeavePageState extends State<_LeavePage> {
  String _type = 'Casual Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _medicalProofName;
  String? _medicalProofPath;
  Uint8List? _medicalProofBytes;
  bool _isSubmitting = false;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.repository.fetchStaffLeaves());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  int _leaveDaysFor(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;

  int get _leaveDays => _leaveDaysFor(_startDate, _endDate);

  /// Count calendar days in approved leave requests for the given year/month.
  /// month == null means the whole year.
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
      // Submit to repository
      await widget.repository.requestLeave(
        staffId: widget.staffId,
        fromDate:
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
        toDate:
            '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
        reason: _reasonController.text.trim(),
        type: _type,
        documentName: _type == 'Medical Leave' ? _medicalProofName : null,
        documentBytes: _type == 'Medical Leave' ? _medicalProofBytes : null,
      );

      // Cache uploaded doc bytes keyed by request id so detail sheet can show them
      if (_type == 'Medical Leave' && _medicalProofBytes != null) {
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
        documentName: _type == 'Medical Leave' ? _medicalProofName : null,
        documentPath: _type == 'Medical Leave' ? _medicalProofPath : null,
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
      ),
    );
  }

  // Store uploaded doc bytes keyed by request id so detail sheet can show them.
  final Map<String, Uint8List> _storedDocBytes = {};

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor = _ink;
    final mutedColor = _muted;
    final borderColor = _line;
    return ValueListenableBuilder<List<LeaveRequest>>(
      valueListenable: widget.repository.leaveRequests,
      builder: (context, allRequests, _) {
        final myRequests = allRequests
            .where((r) =>
                r.staffId == widget.staffId ||
                r.staffId.isEmpty ||
                widget.staffId.isEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return _ScrollPage(children: [
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
                child: Text('Leave',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor))),
            _pill('●  Available', const Color(0xffe8f8ef),
                const Color(0xff198754))
          ]),
          const SizedBox(height: 20),
          _ProfileCard(
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                child: Text('Leave Request',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: textColor))),
                            const SizedBox(width: 8),
                            Text('Fill all fields',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor))
                          ],
                        ),
                        const SizedBox(height: 14),
                        _smallLabel('Leave Type', color: mutedColor),
                        DropdownButtonFormField<String>(
                            value: _type,
                            isDense: true,
                            style: TextStyle(fontSize: 13, color: textColor),
                            items: const [
                              'Casual Leave',
                              'Sick Leave',
                              'Earned Leave',
                              'Medical Leave',
                            ]
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _type = v ?? _type),
                            decoration: _fieldDecoration(
                                textColor: textColor,
                                hintColor: mutedColor,
                                borderColor: borderColor,
                                fillColor: _fieldBg)),
                        const SizedBox(height: 6),
                        Text(
                            switch (_type) {
                              'Casual Leave' =>
                                'Apply at least 3 working days in advance.',
                              'Earned Leave' =>
                                'Apply at least 7 calendar days in advance.',
                              'Sick Leave' => 'Submit as soon as possible.',
                              _ =>
                                'Submit as soon as possible. Attach medical proof when available.',
                            },
                            style: TextStyle(fontSize: 11, color: mutedColor)),
                        if (_type == 'Medical Leave') ...[
                          const SizedBox(height: 12),
                          _smallLabel('Medical Document', color: mutedColor),
                          const SizedBox(height: 6),
                          if (_medicalProofName == null)
                            Text('Medical document not uploaded',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor)),
                          Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                    onPressed: _pickMedicalProof,
                                    icon: Icon(Icons.attach_file, size: 17),
                                    label: Text(_medicalProofName == null
                                        ? 'Attach Medical Proof'
                                        : 'Change Document')),
                                if (_medicalProofName != null)
                                  OutlinedButton.icon(
                                      onPressed: _previewMedicalProof,
                                      icon: Icon(Icons.visibility_outlined,
                                          size: 17),
                                      label: Text('View Document')),
                                if (_medicalProofName != null)
                                  IconButton(
                                      tooltip: 'Remove document',
                                      onPressed: () => setState(() {
                                            _medicalProofName = null;
                                            _medicalProofPath = null;
                                            _medicalProofBytes = null;
                                          }),
                                      icon: Icon(Icons.close, size: 18)),
                              ]),
                          if (_medicalProofName != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_medicalProofName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12, color: textColor))),
                          Text('PDF, JPG or PNG',
                              style:
                                  TextStyle(fontSize: 10, color: mutedColor)),
                        ],
                        const SizedBox(height: 12),
                        _smallLabel('Duration', color: mutedColor),
                        Row(children: [
                          Expanded(
                              child: GestureDetector(
                                  onTap: () => _pickDate(start: true),
                                  child: _dateBox(
                                      '📅  ${_formatDate(_startDate)}',
                                      textColor: textColor,
                                      borderColor: borderColor,
                                      backgroundColor: _fieldBg))),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              child: Text('to',
                                  style: TextStyle(
                                      fontSize: 12, color: mutedColor))),
                          Expanded(
                              child: GestureDetector(
                                  onTap: () => _pickDate(start: false),
                                  child: _dateBox(
                                      '📅  ${_formatDate(_endDate)}',
                                      textColor: textColor,
                                      borderColor: borderColor,
                                      backgroundColor: _fieldBg)))
                        ]),
                        const SizedBox(height: 12),
                        _smallLabel('Reason for Leave', color: mutedColor),
                        TextField(
                            controller: _reasonController,
                            maxLines: 3,
                            style: TextStyle(fontSize: 13, color: textColor),
                            decoration: _fieldDecoration(
                                hint:
                                    'Family function / personal reason for leave...',
                                textColor: textColor,
                                hintColor: mutedColor,
                                borderColor: borderColor,
                                fillColor: _fieldBg)),
                        const SizedBox(height: 16),
                        SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submitRequest,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff172d50),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Submit Request',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                            ))
                      ]))),
          const SizedBox(height: 20),
          // ── Request History ────────────────────────────────────────────
          _ProfileCard(
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text('Request History',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textColor))),
                            Text('${myRequests.length} total',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: mutedColor)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (myRequests.isEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                  child: Column(
                                children: [
                                  Icon(Icons.event_note_outlined,
                                      size: 36,
                                      color: mutedColor.withOpacity(0.4)),
                                  const SizedBox(height: 8),
                                  Text('No leave requests submitted yet.',
                                      style: TextStyle(
                                          color: mutedColor, fontSize: 13)),
                                ],
                              )))
                        else
                          ...myRequests.map(
                            (req) => _LeaveRequestTile(
                              request: req,
                              formatDate: _formatDateStr,
                              onTap: () => _openRequestDetail(context, req),
                            ),
                          ),
                      ]))),
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
    final daysText = '$days ${days == 1 ? 'day' : 'days'}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(request.type,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                  ),
                  _pill(
                    request.status,
                    _statusBackground(request.status),
                    _statusForeground(request.status),
                  ),
                ]),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 11, color: _muted),
                    children: [
                      TextSpan(text: '$datesLabel · '),
                      TextSpan(
                        text: daysText,
                        style:
                            TextStyle(fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                if (request.documentName != null &&
                    request.documentName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.attachment, size: 12, color: _blue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.documentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: _blue,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: _muted),
        ]),
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
  });
  final LeaveRequest request;
  final String Function(String) formatDate;
  final String Function(int) monthName;
  final HRRepository repository;
  final Uint8List? storedBytes;

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
        title: const Text('Delete this leave request?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to delete this leave request? This action cannot be undone.',
            style: TextStyle(fontSize: 13, color: Color(0xff556987))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xff556987))),
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
      try {
        await repository.deleteLeaveRequest(request.id);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request deleted successfully.')),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete request: $e')),
          );
        }
      }
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
        color: _bg,
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
                      Text('Medical Document',
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
                            color: const Color(0xfff0f5ff),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffd0e0ff)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _blue.withOpacity(0.1),
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
                                    request.documentName ?? 'Medical Document',
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
                    // Delete Request button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteRequest(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffd84747),
                          side: const BorderSide(color: Color(0xfff8d7da)),
                          backgroundColor: const Color(0xfffff5f5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete Request',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
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
    required this.department,
  });

  final bool searchOpen;
  final Staff staff;
  final HRRepository repository;
  final String department;

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

  void Function()? _removeMessageListener;
  void Function()? _removeDeleteListener;
  void Function()? _removeReconnectListener;
  void Function()? _removeConnectionListener;
  VoidCallback? _repoListener;

  @override
  void initState() {
    super.initState();
    _repoListener = () {
      if (mounted) setState(() {});
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
    }
    if (oldWidget.department != widget.department) {
      _loadMessages();
      StaffChatSocketService().joinDepartment(widget.department);
    }
  }

  @override
  void dispose() {
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
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      await widget.repository.fetchDepartmentMessages(
        departmentKey: widget.department,
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

  void _initSocket() {
    final socketService = StaffChatSocketService();
    socketService.joinDepartment(widget.department);

    _removeMessageListener = socketService.addMessageListener((incoming) {
      if (!mounted) return;
      final currentDept = canonicalDepartmentKey(widget.department);
      final msgDept = canonicalDepartmentKey(incoming.departmentKey);
      if (msgDept.isNotEmpty &&
          currentDept.isNotEmpty &&
          msgDept != currentDept) {
        return;
      }

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

    _removeDeleteListener =
        socketService.addDeleteListener((messageId, deletedForEveryone) {
      if (!mounted) return;
      final list = widget.repository.departmentChatMessages.value
          .where((m) => m.id != messageId)
          .toList();
      widget.repository.departmentChatMessages.value = list;
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
        departmentKey: widget.department,
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

  @override
  Widget build(BuildContext context) {
    final allMessages = widget.repository.departmentChatMessages.value
        .where((m) => !m.isHiddenFor(widget.staff.id))
        .toList();
    final query = _searchController.text.trim().toLowerCase();
    final visibleMessages = query.isEmpty
        ? allMessages
        : allMessages
            .where((message) =>
                message.senderName.toLowerCase().contains(query) ||
                message.text.toLowerCase().contains(query))
            .toList();

    return Column(children: [
      if (widget.searchOpen)
        Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
                key: const ValueKey('chat-search'),
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
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
                    hintText: 'Search staff or messages',
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
        child: _isLoading && allMessages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && allMessages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 36, color: _muted),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _loadMessages(),
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
                      if (visibleMessages.isNotEmpty)
                        Center(
                          child: _pill(
                            _formatDateHeader(visibleMessages.first.timestamp),
                            const Color(0xffeef2f8),
                            _muted,
                          ),
                        ),
                      if (visibleMessages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Center(
                            child: Text(
                              query.isNotEmpty
                                  ? 'No messages found'
                                  : 'No messages yet in this department',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ),
                      ...visibleMessages.map((message) =>
                          message.isSentBy(widget.staff)
                              ? _sentMessage(message)
                              : _message(
                                  message.initials,
                                  message.senderName,
                                  message.text,
                                  message.formattedTime,
                                  isHR: message.isHR,
                                )),
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
            Expanded(
                child: TextField(
                    key: const ValueKey('chat-message-composer'),
                    controller: _composerController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                        hintText: 'Message everyone...',
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
                    onPressed: _isSending ? null : _sendMessage,
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
  const _SettingsPage(
      {required this.onOpenProfile,
      required this.onOpenSecurity,
      required this.onOpenChat,
      required this.onOpenNotifications,
      required this.onOpenAppearance,
      required this.onOpenSupport,
      required this.onOpenAbout,
      required this.onOpenPrivacyPolicy,
      required this.onOpenTerms,
      required this.onLogout});
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

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Log out?'),
              content: Text('You will need to sign in again to use StaffHub.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Log out',
                        style: TextStyle(color: Color(0xffd64545)))),
              ],
            ));
    if (confirmed == true) onLogout();
  }

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
        const SizedBox(height: 18),
        Text('Settings',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 20),
        _group('Account', [
          _SettingRow(Icons.person_outline, 'Profile',
              'View your profile and account settings',
              onTap: onOpenProfile),
          _SettingRow(Icons.lock_outline, 'Security',
              'Manage password and account security',
              onTap: onOpenSecurity),
        ]),
        _group('Communication', [
          _SettingRow(Icons.chat_bubble_outline, 'Chat',
              'Open team conversations and updates',
              onTap: onOpenChat),
          _SettingRow(Icons.notifications_none, 'Notifications',
              'Manage chat, leave, and attendance alerts',
              onTap: onOpenNotifications),
        ]),
        _group('App', [
          _SettingRow(Icons.palette_outlined, 'Appearance', 'Light, dark',
              onTap: onOpenAppearance)
        ]),
        _group('Legal', [
          _SettingRow(Icons.privacy_tip_outlined, 'Privacy Policy',
              'How StaffHub handles your information',
              onTap: onOpenPrivacyPolicy),
          _SettingRow(Icons.description_outlined, 'Terms & Conditions',
              'Terms for using StaffHub',
              onTap: onOpenTerms),
        ]),
        _group('Support', [
          _SettingRow(
              Icons.help_outline, 'Help & Support', 'Get help with StaffHub',
              onTap: onOpenSupport),
          _SettingRow(
              Icons.info_outline, 'About', 'App information and version',
              onTap: onOpenAbout),
        ]),
        Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ACCOUNT ACTIONS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: _muted))),
        Container(
          decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xfff1d9dc))),
          child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _confirmLogout(context),
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    child: Row(children: [
                      Icon(Icons.logout, size: 19, color: Color(0xffd64545)),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text('Logout',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xffc93640)))),
                      Icon(Icons.chevron_right,
                          size: 18, color: Color(0xffd64545)),
                    ])),
              )),
        ),
        const SizedBox(height: 24),
      ]);
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

class _SettingsDocumentPage extends StatelessWidget {
  const _SettingsDocumentPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(children: [
      const SizedBox(height: 18),
      Text(title,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 12),
      _ProfileCard(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(content,
                  style: TextStyle(fontSize: 13, height: 1.6, color: _ink)))),
    ]);
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
  const _ProfilePage(
      {required this.onLogout,
      required this.staff,
      required this.repository,
      required this.department,
      required this.workMode,
      required this.workLocation});
  final VoidCallback onLogout;
  final Staff staff;
  final HRRepository repository;
  final String department;
  final String workMode;
  final String? workLocation;
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late Staff _staff;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _notificationsEnabled = true;

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

  Future<void> _editProfile() async {
    final phoneController = TextEditingController(text: _staff.phoneNumber);
    final addressController = TextEditingController(text: _staff.address);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        await widget.repository.updateProfile(
          phone: phoneController.text,
          address: addressController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          _loadProfile();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ScrollPage(children: [
        if (_isLoading || _isSaving) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Center(
            child: Column(children: [
          Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff243b63), Color(0xff8ea5c8)]),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x24344d78),
                        blurRadius: 14,
                        offset: Offset(0, 6))
                  ]),
              child: Center(
                  child: Text(
                      _staff.name.isEmpty
                          ? 'S'
                          : _staff.name.characters.first.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)))),
          const SizedBox(height: 12),
          Text(_staff.name,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18, color: _ink)),
          const SizedBox(height: 5),
          _pill(_staff.department.toUpperCase(), const Color(0xffeaf0ff), _blue)
        ])),
        const SizedBox(height: 20),
        _Card(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  _profileStat('Employee ID',
                      _staff.id.isNotEmpty ? _staff.id : 'EMP-2024'),
                  _profileStat('Joined', 'Mar 2024'),
                  _profileStat('Status', 'Active')
                ]))),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Information',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: _isSaving ? null : _editProfile,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProfileCard(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(Icons.mail_outline, 'Work Email', _staff.email),
                      _InfoRow(Icons.call_outlined, 'Phone Number',
                          _staff.phoneNumber),
                      _InfoRow(Icons.location_city_outlined, 'Address',
                          _staff.address),
                      _InfoRow(Icons.apartment_outlined, 'Department',
                          _staff.department),
                      _InfoRow(
                          Icons.work_outline, 'Work Mode', widget.workMode),
                      if (widget.workMode == 'Work From Home' &&
                          widget.workLocation != null)
                        _InfoRow(Icons.location_on_outlined, 'Location',
                            widget.workLocation!),
                    ]))),
        const SizedBox(height: 22),
        Text('Account',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
        const SizedBox(height: 10),
        _ProfileCard(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingRow(Icons.notifications_none, 'Notifications',
                          'Push, email, and alerts',
                          trailing: Switch(
                              value: _notificationsEnabled,
                              onChanged: (enabled) => setState(
                                  () => _notificationsEnabled = enabled),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap)),
                      const _SettingRow(Icons.privacy_tip_outlined,
                          'Privacy & Policy', 'Manage your data & privacy'),
                      const _SettingRow(Icons.description_outlined,
                          'Terms & Conditions', 'View company policies'),
                      const _SettingRow(Icons.help_outline,
                          'Support & Helpdesk', 'Raise a support ticket')
                    ]))),
        const SizedBox(height: 22),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Log Out',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffd84747),
                    backgroundColor: const Color(0xffffeeee),
                    minimumSize: const Size(0, 44),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))))),
        Center(
            child: Padding(
                padding: EdgeInsets.all(7),
                child: Text(
                    'StaffHub Systems Inc. • Secure Staff Portal • v2.4.0',
                    style: TextStyle(fontSize: 10, color: _muted)))),
      ]);
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth > 520 ? 500.0 : box.maxWidth;
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
Widget _sectionTitle(IconData icon, String text, {String? trailing}) =>
    Row(children: [
      Icon(icon, size: 13, color: _blue),
      const SizedBox(width: 5),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: _ink, fontWeight: FontWeight.w700))),
      if (trailing != null)
        Text(trailing, style: TextStyle(fontSize: 10, color: _blue))
    ]);
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
      return const Color(0xffe8f8ef);
    case 'rejected':
    case 'denied':
      return const Color(0xffffeeee);
    default:
      return const Color(0xfffff4d6);
  }
}

Color _statusForeground(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return const Color(0xff16834b);
    case 'rejected':
    case 'denied':
      return const Color(0xffd84747);
    default:
      return const Color(0xffb7791f);
  }
}

Widget _profileStat(String title, String value) => Expanded(
        child: Column(children: [
      Text(title, style: TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 5),
      Text(value,
          style:
              TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700))
    ]));

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
