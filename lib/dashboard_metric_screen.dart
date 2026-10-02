import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'badges.dart';
import 'hr_view_model.dart';
import 'models.dart';
import 'date_time_utils.dart';

class DashboardMetricScreenWidget extends StatelessWidget {
  const DashboardMetricScreenWidget({super.key, required this.filter, required this.viewModel});

  final String filter;
  final HRViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final today = DateTimeUtils.getTodayIsoDate();
        final staff = _staffForFilter(today);
        final title = _titleForFilter();
        final tasks = filter == 'tasks'
            ? viewModel.tasksList.where((task) => task.status != TaskStatus.done).toList()
            : const <TaskItem>[];

        return Scaffold(
          backgroundColor: AppColors.canvasBg,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceWhite,
            surfaceTintColor: AppColors.surfaceWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => viewModel.navigateTo(HRDashboardScreen()),
            ),
            title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1104),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  Text('$title (${filter == 'tasks' ? tasks.length : staff.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (filter == 'tasks')
                    ...tasks.map(_taskCard)
                  else if (staff.isEmpty)
                    const _EmptyState()
                  else
                    ...staff.map((member) => _staffCard(member, today)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Staff> _staffForFilter(String today) {
    return viewModel.staffList.where((staff) {
      final attendance = viewModel.attendanceList.where((item) => item.staffId == staff.id && item.date == today);
      return switch (filter) {
        'active' => staff.status == Status.active,
        'present' => attendance.isNotEmpty,
        'leave' => staff.onLeaveToday,
        'late' => attendance.any((item) => item.isLate),
        'resigned' => staff.status == Status.resigned,
        _ => true,
      };
    }).toList();
  }

  String _titleForFilter() => switch (filter) {
        'active' => 'Active staff',
        'present' => 'Present today',
        'leave' => 'On leave today',
        'late' => 'Late check-ins',
        'tasks' => 'Open tasks',
        'resigned' => 'Resigned staff',
        _ => 'Total staff',
      };

  Widget _staffCard(Staff staff, String today) {
    final attendance = viewModel.attendanceList.where((item) => item.staffId == staff.id && item.date == today).firstOrNull;
    final status = staff.onLeaveToday ? 'on leave' : staff.status;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.borderSubtle)),
      child: ListTile(
        onTap: () => viewModel.navigateTo(StaffProfileScreen(staff.id)),
        title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${staff.email}\n${attendance?.checkInTime ?? 'Not checked in'}', style: const TextStyle(height: 1.5)),
        isThreeLine: true,
        leading: DepartmentBadge(department: staff.department),
        trailing: StatusBadge(status: status),
      ),
    );
  }

  Widget _taskCard(TaskItem task) {
    final staff = viewModel.staffList.firstWhere((member) => member.id == task.staffId, orElse: () => const Staff());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.borderSubtle)),
      child: ListTile(
        title: Text(task.description, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${staff.name}  •  Due ${task.dueDate}'),
        trailing: StatusBadge(status: task.status),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: Text('No records found', style: TextStyle(color: AppColors.textMuted))),
        ),
      );
}