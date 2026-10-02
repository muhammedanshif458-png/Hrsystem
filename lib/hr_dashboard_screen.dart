// ─── hr_dashboard_screen.dart ──────────────────────────────────────────────────
// Converted from Kotlin HRDashboardScreen.kt in com.example.ui.screens

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_colors.dart';
import 'badges.dart';
import 'cards.dart';
import 'hr_view_model.dart';
import 'models.dart';
import 'date_time_utils.dart';

class HRDashboardScreenWidget extends StatelessWidget {
  const HRDashboardScreenWidget({super.key, required this.viewModel});

  final HRViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        final todayIso = DateTimeUtils.getTodayIsoDate();
        final metrics = vm.dashboardMetrics;
        final filtered = vm.filteredStaffList;

        return Scaffold(
          backgroundColor: AppColors.canvasBg,
          appBar: _HRTopBar(
            managerName: vm.currentUser?.name ?? 'HR Manager',
            onLogout: vm.logout,
            onOpenRules: vm.openFirestoreRules,
          ),
          body: CustomScrollView(
            slivers: [
              // ── Padding sliver ──────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: (MediaQuery.sizeOf(context).width - 980) / 2 > 16
                      ? (MediaQuery.sizeOf(context).width - 980) / 2
                      : 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Department filter chips
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              for (final dept in [
                                Department.all,
                                Department.telecalling,
                                Department.tech
                              ]) ...[
                                _DeptChip(
                                  dept: dept,
                                  selectedDept: vm.departmentFilter,
                                  onTap: () => vm.openDepartmentScreen(dept),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: vm.openAddStaffModal,
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text('Add staff',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandSlate,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (vm.departmentFilter != Department.all)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Text(
                              '${vm.departmentFilter} department',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  vm.openDepartmentScreen(Department.all),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('All staff'),
                            ),
                          ],
                        ),
                      ),

                    // Six key metrics: a balanced three-column, two-row grid on desktop.
                    LayoutBuilder(builder: (_, constraints) {
                      const gap = 16.0;
                      final cardWidth = constraints.maxWidth < 680
                          ? (constraints.maxWidth - gap) / 2
                          : (constraints.maxWidth - (gap * 2)) / 3;
                      final activeStaff = filtered
                          .where((staff) => staff.status == Status.active)
                          .length;
                      final cards = [
                        ('Total staff', '${vm.staffList.length}', 'all'),
                        ('Active staff', '$activeStaff', 'active'),
                        ('Present today', '${metrics.presentToday}', 'present'),
                        ('On leave today', '${metrics.onLeaveToday}', 'leave'),
                        ('Late check-ins', '${metrics.lateCheckIns}', 'late'),
                        (
                          'Resigned (last 30 days)',
                          '${metrics.resignedLast30Days}',
                          'resigned'
                        ),
                      ];
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final card in cards)
                            SizedBox(
                              width: cardWidth,
                              height: 112,
                              child: SaaSStatCard(
                                title: card.$1,
                                value: card.$2,
                                onTap: () => vm.navigateTo(
                                  DashboardMetricScreen(card.$3),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),


                    _HRRequestsCard(viewModel: vm),
                    const SizedBox(height: 16),

                    if (vm.dashboardFilter != 'all')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(
                              _filterLabel(vm.dashboardFilter),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => vm.setDashboardFilter('all'),
                              child: const Text('Show all staff'),
                            ),
                          ],
                        ),
                      ),

                    _StaffDirectoryTable(
                      staffList: filtered,
                      attendanceList: vm.attendanceList,
                      todayIso: todayIso,
                      onStaffTap: (staff) =>
                          vm.navigateTo(StaffProfileScreen(staff.id)),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _filterLabel(String filter) {
    return switch (filter) {
      'active' => 'Active staff',
      'present' => 'Present today',
      'leave' => 'On leave today',
      'late' => 'Late check-ins',
      'tasks' => 'Staff with open tasks',
      'resigned' => 'Resigned staff',
      _ => 'All staff',
    };
  }
}

class _HRRequestsCard extends StatelessWidget {
  const _HRRequestsCard({required this.viewModel});
  final HRViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final leaves = viewModel.leaveRequests;
    final resignations = viewModel.resignationRequests
        .where((r) => r.status == LeaveStatus.pending)
        .toList();
    if (leaves.isEmpty && resignations.isEmpty) return const SizedBox.shrink();
    String staffName(String id) =>
        viewModel.staffList
            .where((s) => s.id == id)
            .map((s) => s.name)
            .firstOrNull ??
        'Staff member';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Leave requests & approvals',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...leaves.map((r) => _leaveCard(context, r, staffName(r.staffId), viewModel)),
        ...resignations.map((r) => _requestRow(
            '${staffName(r.staffId)} · Resignation',
            'Last day: ${r.lastWorkingDate}\n${r.reason}',
            () => viewModel.reviewResignation(r.id, true),
            () => viewModel.reviewResignation(r.id, false))),
      ]),
    );
  }

  Widget _leaveCard(BuildContext context, LeaveRequest request, String employee, HRViewModel vm) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detail('Employee', employee),
          _detail('Leave Type', request.type),
          _detail('Duration', '${request.fromDate} – ${request.toDate}'),
          _detail('Reason', request.reason),
          if (request.type == 'Medical Leave') ...[
            _detail('Medical Document', request.documentName ?? 'Medical document not uploaded'),
            if (request.documentUrl != null && request.documentUrl!.isNotEmpty)
              TextButton.icon(
                  onPressed: () => _openDocument(context, request.documentUrl!),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View Document')),
          ],
          _detail('Status', request.status),
          if (request.status == LeaveStatus.pending)
            Row(children: [
              TextButton(
                  onPressed: () => vm.reviewLeave(request.id, false),
                  child: const Text('Reject')),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: () => vm.reviewLeave(request.id, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandSlate,
                      foregroundColor: Colors.white),
                  child: const Text('Approve')),
            ])
        ]),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: RichText(
            text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                children: [
              TextSpan(
                  text: '$label\n',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600))
            ])),
      );

  Future<void> _openDocument(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document link is unavailable.')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the medical document.')));
    }
  }

  Widget _requestRow(String title, String subtitle, VoidCallback approve,
          VoidCallback reject) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))
              ])),
          TextButton(onPressed: reject, child: const Text('Reject')),
          ElevatedButton(
              onPressed: approve,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandSlate,
                  foregroundColor: Colors.white),
              child: const Text('Approve')),
        ]),
      );
}

class _StaffDirectoryTable extends StatelessWidget {
  const _StaffDirectoryTable({
    required this.staffList,
    required this.attendanceList,
    required this.todayIso,
    required this.onStaffTap,
  });

  final List<Staff> staffList;
  final List<Attendance> attendanceList;
  final String todayIso;
  final ValueChanged<Staff> onStaffTap;

  static const _columns = [
    'Name',
    'Department',
    'Check-in time',
    'Check-out',
    'TWT',
    'Break',
    'Status',
    "Today's task",
    'Last updated',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < 900 ? 900.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: tableWidth,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _TableLine(
                  backgroundColor: AppColors.surfaceWhite,
                  cells: [
                    for (final column in _columns)
                      column == 'TWT'
                          ? const Tooltip(
                              message: 'Total work time',
                              child: Text('TWT',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            )
                          : Text(column,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                  ],
                  isHeader: true,
                ),
                if (staffList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No staff members match the selected filter.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                  )
                else
                  for (final staff in staffList) _buildRow(staff),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(Staff staff) {
    final attendance = attendanceList
        .where((item) => item.staffId == staff.id && item.date == todayIso)
        .firstOrNull;
    final checkIn = attendance?.checkInTime ?? '—';
    final checkOut = attendance?.checkOutTime ?? '—';
    final status = staff.onLeaveToday ? 'on leave' : staff.status;

    return GestureDetector(
      onTap: () => onStaffTap(staff),
      child: _TableLine(
        isHeader: false,
        cells: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(staff.name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(staff.email,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          DepartmentBadge(department: staff.department),
          Text(checkIn,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(checkOut,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
              attendance?.workedDuration.isNotEmpty == true
                  ? attendance!.workedDuration
                  : '—',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
              attendance?.breakDuration.isNotEmpty == true
                  ? attendance!.breakDuration
                  : '—',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          StatusBadge(status: status),
          const Text('—',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(_lastUpdated(staff),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _lastUpdated(Staff staff) {
    final updates = staff.id == 'staff_2' || staff.id == 'staff_3'
        ? 'Sep 8, 2026'
        : staff.id == 'staff_4'
            ? 'Sep 16, 2026'
            : '—';
    return updates;
  }
}

class _TableLine extends StatelessWidget {
  const _TableLine(
      {required this.cells, required this.isHeader, this.backgroundColor});

  final List<Widget> cells;
  final bool isHeader;
  final Color? backgroundColor;

  static const _flexes = [2.2, 1.0, 1.0, 0.9, 0.75, 0.75, 0.9, 1.15, 1.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isHeader ? 44 : 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++)
            Expanded(
              flex: (_flexes[index] * 100).round(),
              child: Align(
                alignment:
                    index == 0 ? Alignment.centerLeft : Alignment.centerLeft,
                child: cells[index],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top App Bar ───────────────────────────────────────────────────────────────

class _HRTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _HRTopBar(
      {required this.managerName,
      required this.onLogout,
      required this.onOpenRules});

  final String managerName;
  final VoidCallback onLogout;
  final VoidCallback onOpenRules;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 36,
                  height: 36,
                  color: AppColors.brandNavy,
                  alignment: Alignment.center,
                  child: const Text('HR',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('HR system',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7),
                        child: Text('·',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textMuted)),
                      ),
                      Text('HR manager',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout,
                    color: AppColors.textPrimary, size: 17),
                label: const Text('Sign out',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Department Filter Chip ────────────────────────────────────────────────────

class _DeptChip extends StatelessWidget {
  const _DeptChip(
      {required this.dept, required this.selectedDept, required this.onTap});

  final String dept;
  final String selectedDept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = dept.toLowerCase() == selectedDept.toLowerCase();
    final accentColor = dept == Department.telecalling
        ? AppColors.telecallingPrimary
        : dept == Department.tech
            ? AppColors.techPrimary
            : AppColors.brandSlate;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? accentColor : AppColors.borderSubtle),
        ),
        child: Text(
          dept,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

