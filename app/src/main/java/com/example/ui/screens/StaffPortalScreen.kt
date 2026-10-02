package com.example.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.TaskAlt
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
import com.example.data.model.TaskItem
import com.example.data.model.TaskStatus
import com.example.ui.components.DepartmentBadge
import com.example.ui.components.SaaSCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.*
import com.example.ui.viewmodel.HRViewModel
import com.example.util.DateTimeUtils

@Composable
fun StaffPortalScreen(
    viewModel: HRViewModel,
    modifier: Modifier = Modifier
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val attendanceList by viewModel.attendanceList.collectAsState()
    val tasksList by viewModel.tasksList.collectAsState()
    val dailyUpdatesList by viewModel.dailyUpdatesList.collectAsState()

    val staff = currentUser ?: return
    val todayIso = remember { DateTimeUtils.getTodayIsoDate() }
    val todayDisplay = remember { DateTimeUtils.getTodayFormatted() }

    // Today's attendance for current staff
    val todayAttendance = remember(attendanceList, staff.id) {
        attendanceList.find { it.staff_id == staff.id && it.date == todayIso }
    }

    // Staff tasks
    val staffTasks = remember(tasksList, staff.id) {
        tasksList.filter { it.staff_id == staff.id }
    }

    // Staff attendance history (excluding today or all)
    val staffAttendanceHistory = remember(attendanceList, staff.id) {
        attendanceList.filter { it.staff_id == staff.id }
    }

    // Staff daily updates history
    val staffUpdatesHistory = remember(dailyUpdatesList, staff.id) {
        dailyUpdatesList.filter { it.staff_id == staff.id }
    }

    var selectedTab by remember { mutableStateOf(0) } // 0: Today, 1: History
    var dailyUpdateInput by remember { mutableStateOf("") }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = CanvasBg,
        topBar = {
            StaffPortalHeader(
                staff = staff,
                todayDate = todayDisplay,
                onLogout = { viewModel.logout() }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Tab Selector
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    label = { Text("Today's workspace", fontSize = 13.sp) },
                    leadingIcon = {
                        Icon(Icons.Default.TaskAlt, contentDescription = null, modifier = Modifier.size(16.dp))
                    },
                    shape = RoundedCornerShape(8.dp),
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = BrandSlate,
                        selectedLabelColor = Color.White,
                        selectedLeadingIconColor = Color.White
                    ),
                    border = BorderStroke(1.dp, if (selectedTab == 0) BrandSlate else BorderSubtle),
                    modifier = Modifier.testTag("tab_today_workspace")
                )

                FilterChip(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    label = { Text("History view", fontSize = 13.sp) },
                    leadingIcon = {
                        Icon(Icons.Default.History, contentDescription = null, modifier = Modifier.size(16.dp))
                    },
                    shape = RoundedCornerShape(8.dp),
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = BrandSlate,
                        selectedLabelColor = Color.White,
                        selectedLeadingIconColor = Color.White
                    ),
                    border = BorderStroke(1.dp, if (selectedTab == 1) BrandSlate else BorderSubtle),
                    modifier = Modifier.testTag("tab_history_view")
                )
            }

            if (selectedTab == 0) {
                // Today's workspace
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    contentPadding = PaddingValues(bottom = 32.dp)
                ) {
                    // Check-in card
                    item {
                        CheckInCard(
                            todayAttendance = todayAttendance,
                            onCheckIn = { viewModel.checkIn() },
                            onCheckOut = { todayAttendance?.let { viewModel.checkOut(it.id) } }
                        )
                    }

                    // Today's tasks card
                    item {
                        TodayTasksCard(
                            tasks = staffTasks,
                            onToggleStatus = { task, newStatus ->
                                viewModel.updateTaskStatus(task.id, newStatus)
                            }
                        )
                    }

                    // Daily update submission card
                    item {
                        DailyUpdateCard(
                            updateText = dailyUpdateInput,
                            onTextChange = { dailyUpdateInput = it },
                            onSubmit = {
                                viewModel.submitDailyUpdate(dailyUpdateInput) {
                                    dailyUpdateInput = ""
                                }
                            }
                        )
                    }
                }
            } else {
                // History View (browsable by date)
                StaffHistoryView(
                    attendanceHistory = staffAttendanceHistory,
                    updatesHistory = staffUpdatesHistory
                )
            }
        }
    }
}

@Composable
private fun StaffPortalHeader(
    staff: Staff,
    todayDate: String,
    onLogout: () -> Unit
) {
    Surface(
        color = SurfaceWhite,
        border = BorderStroke(1.dp, BorderSubtle),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "Welcome back, ${staff.name}",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                    DepartmentBadge(department = staff.department)
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = todayDate,
                    fontSize = 12.sp,
                    color = TextMuted
                )
            }

            IconButton(
                onClick = onLogout,
                modifier = Modifier.testTag("staff_logout_button")
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ExitToApp,
                    contentDescription = "Sign out",
                    tint = TextSecondary
                )
            }
        }
    }
}

@Composable
private fun CheckInCard(
    todayAttendance: Attendance?,
    onCheckIn: () -> Unit,
    onCheckOut: () -> Unit
) {
    SaaSCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Attendance status",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
                Text(
                    text = if (todayAttendance == null) "You have not checked in yet today"
                    else if (todayAttendance.check_out_time != null) "Workday completed"
                    else "Currently checked in",
                    fontSize = 12.sp,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }

            if (todayAttendance != null) {
                StatusBadge(status = if (todayAttendance.is_late) "late" else "on time")
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        if (todayAttendance != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SurfaceSubtle, RoundedCornerShape(8.dp))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("Check-in time", fontSize = 11.sp, color = TextMuted)
                    Text(
                        text = todayAttendance.check_in_time,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextPrimary
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("Check-out time", fontSize = 11.sp, color = TextMuted)
                    Text(
                        text = todayAttendance.check_out_time ?: "In progress",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (todayAttendance.check_out_time != null) TextPrimary else TechPrimary
                    )
                }
            }
            Spacer(modifier = Modifier.height(14.dp))
        }

        if (todayAttendance == null) {
            Button(
                onClick = onCheckIn,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(42.dp)
                    .testTag("check_in_button"),
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(containerColor = BrandSlate)
            ) {
                Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Check in", fontSize = 14.sp, fontWeight = FontWeight.Medium)
            }
        } else if (todayAttendance.check_out_time == null) {
            Button(
                onClick = onCheckOut,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(42.dp)
                    .testTag("check_out_button"),
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFFE2E8F0),
                    contentColor = TextPrimary
                )
            ) {
                Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Check out", fontSize = 14.sp, fontWeight = FontWeight.Medium)
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(StatusGreenBg, RoundedCornerShape(8.dp))
                    .padding(10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Checked out at ${todayAttendance.check_out_time}",
                    fontSize = 13.sp,
                    color = StatusGreenText,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
private fun TodayTasksCard(
    tasks: List<TaskItem>,
    onToggleStatus: (task: TaskItem, newStatus: String) -> Unit
) {
    SaaSCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Today's tasks",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Text(
                text = "${tasks.count { it.status == TaskStatus.DONE }}/${tasks.size} done",
                fontSize = 12.sp,
                color = TextMuted
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        if (tasks.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No tasks assigned to you right now.",
                    fontSize = 13.sp,
                    color = TextMuted
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                tasks.forEach { task ->
                    TaskChecklistItem(
                        task = task,
                        onToggle = { newStatus -> onToggleStatus(task, newStatus) }
                    )
                }
            }
        }
    }
}

@Composable
private fun TaskChecklistItem(
    task: TaskItem,
    onToggle: (newStatus: String) -> Unit
) {
    val isDone = task.status == TaskStatus.DONE
    val isInProgress = task.status == TaskStatus.IN_PROGRESS

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isDone) SurfaceSubtle else SurfaceWhite)
            .border(BorderStroke(1.dp, BorderSubtle), RoundedCornerShape(8.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Status toggle checkbox / indicator
        IconButton(
            onClick = {
                val nextStatus = when (task.status) {
                    TaskStatus.PENDING -> TaskStatus.IN_PROGRESS
                    TaskStatus.IN_PROGRESS -> TaskStatus.DONE
                    else -> TaskStatus.PENDING
                }
                onToggle(nextStatus)
            },
            modifier = Modifier
                .size(28.dp)
                .testTag("task_toggle_${task.id}")
        ) {
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .border(
                        BorderStroke(
                            1.5.dp,
                            if (isDone) StatusGreen else if (isInProgress) BrandBlue else BorderMedium
                        ),
                        RoundedCornerShape(4.dp)
                    )
                    .background(if (isDone) StatusGreen else Color.Transparent),
                contentAlignment = Alignment.Center
            ) {
                if (isDone) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = "Done",
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(10.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = task.description,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = if (isDone) TextMuted else TextPrimary
            )
            Spacer(modifier = Modifier.height(2.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Due: ${DateTimeUtils.formatIsoToReadable(task.due_date)}",
                    fontSize = 11.sp,
                    color = TextMuted
                )
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        StatusBadge(status = task.status)
    }
}

@Composable
private fun DailyUpdateCard(
    updateText: String,
    onTextChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    SaaSCard(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Daily update",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        Text(
            text = "Describe what you accomplished today and any roadblocks",
            fontSize = 12.sp,
            color = TextMuted,
            modifier = Modifier.padding(top = 2.dp, bottom = 12.dp)
        )

        OutlinedTextField(
            value = updateText,
            onValueChange = onTextChange,
            placeholder = { Text("What did you work on today?", fontSize = 13.sp) },
            minLines = 3,
            maxLines = 6,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("daily_update_input"),
            shape = RoundedCornerShape(8.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = BrandSlate,
                unfocusedBorderColor = BorderSubtle
            )
        )

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            onClick = onSubmit,
            enabled = updateText.isNotBlank(),
            shape = RoundedCornerShape(8.dp),
            colors = ButtonDefaults.buttonColors(containerColor = BrandSlate),
            modifier = Modifier
                .align(Alignment.End)
                .testTag("submit_daily_update_button")
        ) {
            Text("Submit update", fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun StaffHistoryView(
    attendanceHistory: List<Attendance>,
    updatesHistory: List<DailyUpdate>
) {
    var historySubTab by remember { mutableStateOf(0) } // 0: Attendance, 1: Daily Updates

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TextButton(
                onClick = { historySubTab = 0 },
                colors = ButtonDefaults.textButtonColors(
                    contentColor = if (historySubTab == 0) BrandSlate else TextMuted
                )
            ) {
                Text(
                    "Past attendance (${attendanceHistory.size})",
                    fontWeight = if (historySubTab == 0) FontWeight.Bold else FontWeight.Normal,
                    fontSize = 13.sp
                )
            }
            TextButton(
                onClick = { historySubTab = 1 },
                colors = ButtonDefaults.textButtonColors(
                    contentColor = if (historySubTab == 1) BrandSlate else TextMuted
                )
            ) {
                Text(
                    "Past updates (${updatesHistory.size})",
                    fontWeight = if (historySubTab == 1) FontWeight.Bold else FontWeight.Normal,
                    fontSize = 13.sp
                )
            }
        }

        if (historySubTab == 0) {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
                if (attendanceHistory.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("No past attendance records found.", color = TextMuted, fontSize = 13.sp)
                        }
                    }
                } else {
                    items(attendanceHistory) { att ->
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
                                        text = "In: ${att.check_in_time}  •  Out: ${att.check_out_time ?: "N/A"}",
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
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
                if (updatesHistory.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("No past updates recorded yet.", color = TextMuted, fontSize = 13.sp)
                        }
                    }
                } else {
                    items(updatesHistory) { upd ->
                        SaaSCard(modifier = Modifier.fillMaxWidth()) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = DateTimeUtils.formatIsoToReadable(upd.date),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = TextPrimary
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = upd.update_text,
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
