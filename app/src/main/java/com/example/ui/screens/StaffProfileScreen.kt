package com.example.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.Attendance
import com.example.data.model.DailyUpdate
import com.example.data.model.Staff
import com.example.data.model.Status
import com.example.data.model.TaskItem
import com.example.data.model.TaskStatus
import com.example.ui.components.DepartmentBadge
import com.example.ui.components.EditStaffModal
import com.example.ui.components.SaaSCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.*
import com.example.ui.viewmodel.HRViewModel
import com.example.ui.viewmodel.Screen
import com.example.util.DateTimeUtils

@Composable
fun StaffProfileScreen(
    staffId: String,
    viewModel: HRViewModel,
    modifier: Modifier = Modifier
) {
    val staffList by viewModel.staffList.collectAsState()
    val attendanceList by viewModel.attendanceList.collectAsState()
    val tasksList by viewModel.tasksList.collectAsState()
    val dailyUpdatesList by viewModel.dailyUpdatesList.collectAsState()

    val staff = staffList.find { it.id == staffId }

    if (staff == null) {
        Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Staff record not found.", color = TextMuted)
        }
        return
    }

    val staffAttendance = remember(attendanceList, staff.id) {
        attendanceList.filter { it.staff_id == staff.id }
    }
    val staffTasks = remember(tasksList, staff.id) {
        tasksList.filter { it.staff_id == staff.id }
    }
    val staffUpdates = remember(dailyUpdatesList, staff.id) {
        dailyUpdatesList.filter { it.staff_id == staff.id }
    }

    var selectedTab by remember { mutableStateOf(0) } // 0: Attendance, 1: Tasks, 2: Daily Updates
    var showResignConfirm by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = CanvasBg,
        topBar = {
            Surface(
                color = SurfaceWhite,
                border = BorderStroke(1.dp, BorderSubtle),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = { viewModel.navigateTo(Screen.HRDashboard) },
                        modifier = Modifier.testTag("back_to_dashboard_button")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = TextPrimary)
                    }
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Staff profile",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(top = 16.dp, bottom = 32.dp)
        ) {
            // Staff Details Header Card
            item {
                SaaSCard(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Top
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(BrandNavy),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = staff.name.take(2).uppercase(),
                                    color = Color.White,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }

                            Column {
                                Text(
                                    text = staff.name,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = TextPrimary
                                )
                                Text(
                                    text = staff.email,
                                    fontSize = 13.sp,
                                    color = TextSecondary
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    DepartmentBadge(department = staff.department)
                                    StatusBadge(status = staff.status)
                                }
                            }
                        }

                        // Edit Button
                        OutlinedButton(
                            onClick = { viewModel.isEditStaffModalOpen.value = true },
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, BorderSubtle),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                            modifier = Modifier.testTag("edit_staff_button")
                        ) {
                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Edit", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Meta Row: Role, Join Date, Resigned Date
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(SurfaceSubtle, RoundedCornerShape(8.dp))
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("Role", fontSize = 11.sp, color = TextMuted)
                            Text(staff.role, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                        }
                        Column {
                            Text("Join date", fontSize = 11.sp, color = TextMuted)
                            Text(DateTimeUtils.formatIsoToReadable(staff.join_date), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                        }
                        if (staff.status == Status.RESIGNED) {
                            Column(horizontalAlignment = Alignment.End) {
                                Text("Resigned on", fontSize = 11.sp, color = TextMuted)
                                Text(
                                    DateTimeUtils.formatIsoToReadable(staff.resigned_date ?: ""),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = StatusGrayText
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Action buttons: Assign Task & Resign
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = {
                                viewModel.assignTaskPreselectedStaffId.value = staff.id
                                viewModel.isAssignTaskModalOpen.value = true
                            },
                            shape = RoundedCornerShape(8.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = BrandSlate),
                            modifier = Modifier.weight(1f).testTag("profile_assign_task_button")
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Assign task", fontSize = 13.sp)
                        }

                        if (staff.status == Status.ACTIVE) {
                            OutlinedButton(
                                onClick = { showResignConfirm = true },
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, Color(0xFFFECACA)),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = ErrorRed),
                                modifier = Modifier.weight(1f).testTag("mark_resigned_button")
                            ) {
                                Icon(Icons.Default.PersonOff, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Mark resigned", fontSize = 13.sp)
                            }
                        }
                    }
                }
            }

            // Tabs for History: Attendance, Tasks, Daily Updates
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        label = { Text("Attendance (${staffAttendance.size})", fontSize = 12.sp) },
                        shape = RoundedCornerShape(8.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = BrandSlate,
                            selectedLabelColor = Color.White
                        ),
                        border = BorderStroke(1.dp, if (selectedTab == 0) BrandSlate else BorderSubtle)
                    )
                    FilterChip(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        label = { Text("Tasks (${staffTasks.size})", fontSize = 12.sp) },
                        shape = RoundedCornerShape(8.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = BrandSlate,
                            selectedLabelColor = Color.White
                        ),
                        border = BorderStroke(1.dp, if (selectedTab == 1) BrandSlate else BorderSubtle)
                    )
                    FilterChip(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        label = { Text("Updates (${staffUpdates.size})", fontSize = 12.sp) },
                        shape = RoundedCornerShape(8.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = BrandSlate,
                            selectedLabelColor = Color.White
                        ),
                        border = BorderStroke(1.dp, if (selectedTab == 2) BrandSlate else BorderSubtle)
                    )
                }
            }

            // Tab Content
            when (selectedTab) {
                0 -> {
                    // Attendance History
                    if (staffAttendance.isEmpty()) {
                        item {
                            EmptyHistoryCard("No attendance history found for this staff member.")
                        }
                    } else {
                        items(staffAttendance) { att ->
                            SaaSCard(modifier = Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(
                                            text = DateTimeUtils.formatIsoToReadable(att.date),
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = TextPrimary
                                        )
                                        Text(
                                            text = "Check in: ${att.check_in_time}  •  Check out: ${att.check_out_time ?: "N/A"}",
                                            fontSize = 12.sp,
                                            color = TextSecondary,
                                            modifier = Modifier.padding(top = 2.dp)
                                        )
                                    }
                                    StatusBadge(status = if (att.is_late) "late" else "on time")
                                }
                            }
                        }
                    }
                }

                1 -> {
                    // Tasks History
                    if (staffTasks.isEmpty()) {
                        item {
                            EmptyHistoryCard("No tasks assigned yet.")
                        }
                    } else {
                        items(staffTasks) { task ->
                            SaaSCard(modifier = Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = task.description,
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = TextPrimary
                                        )
                                        Spacer(modifier = Modifier.height(2.dp))
                                        Text(
                                            text = "Assigned: ${DateTimeUtils.formatIsoToReadable(task.date)}  •  Due: ${DateTimeUtils.formatIsoToReadable(task.due_date)}",
                                            fontSize = 12.sp,
                                            color = TextMuted
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(8.dp))
                                    StatusBadge(status = task.status)
                                }
                            }
                        }
                    }
                }

                2 -> {
                    // Daily Updates History
                    if (staffUpdates.isEmpty()) {
                        item {
                            EmptyHistoryCard("No daily updates submitted yet.")
                        }
                    } else {
                        items(staffUpdates) { update ->
                            SaaSCard(modifier = Modifier.fillMaxWidth()) {
                                Text(
                                    text = DateTimeUtils.formatIsoToReadable(update.date),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = TextPrimary
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = update.update_text,
                                    fontSize = 13.sp,
                                    color = TextSecondary,
                                    lineHeight = 18.sp
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Confirmation dialog for Resignation
    if (showResignConfirm) {
        AlertDialog(
            onDismissRequest = { showResignConfirm = false },
            title = { Text("Mark staff as resigned?", fontSize = 16.sp, fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    "This will set ${staff.name}'s status to 'resigned' with today's date. The record will not be deleted from the database.",
                    fontSize = 13.sp
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showResignConfirm = false
                        viewModel.markStaffResigned(staff.id)
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = ErrorRed)
                ) {
                    Text("Confirm resignation")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showResignConfirm = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Edit Staff Modal
    val isEditOpen by viewModel.isEditStaffModalOpen.collectAsState()
    if (isEditOpen) {
        EditStaffModal(
            staff = staff,
            onDismiss = { viewModel.isEditStaffModalOpen.value = false },
            onSave = { updated -> viewModel.updateStaff(updated) }
        )
    }
}

@Composable
private fun EmptyHistoryCard(message: String) {
    SaaSCard(modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(text = message, fontSize = 13.sp, color = TextMuted)
        }
    }
}
