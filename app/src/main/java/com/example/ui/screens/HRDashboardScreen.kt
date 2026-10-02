package com.example.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
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
import com.example.data.model.Department
import com.example.data.model.Staff
import com.example.data.model.Status
import com.example.data.model.TaskItem
import com.example.ui.components.DepartmentBadge
import com.example.ui.components.SaaSCard
import com.example.ui.components.SaaSStatCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.*
import com.example.ui.viewmodel.HRViewModel
import com.example.ui.viewmodel.Screen
import com.example.util.DateTimeUtils

@Composable
fun HRDashboardScreen(
    viewModel: HRViewModel,
    modifier: Modifier = Modifier
) {
    val currentUser by viewModel.currentUser.collectAsState()
    val filteredStaff by viewModel.filteredStaffList.collectAsState()
    val metrics by viewModel.dashboardMetrics.collectAsState()
    val attendanceList by viewModel.attendanceList.collectAsState()
    val tasksList by viewModel.tasksList.collectAsState()
    val dailyUpdatesList by viewModel.dailyUpdatesList.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val departmentFilter by viewModel.departmentFilter.collectAsState()

    val todayIso = remember { DateTimeUtils.getTodayIsoDate() }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = CanvasBg,
        topBar = {
            HRTopBar(
                managerName = currentUser?.name ?: "HR Manager",
                onLogout = { viewModel.logout() },
                onOpenRules = { viewModel.isFirestoreRulesOpen.value = true }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(top = 12.dp, bottom = 32.dp)
        ) {
            // Header controls: Department filter pills, search bar, + Add staff
            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "HR Manager dashboard",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary
                        )

                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    viewModel.assignTaskPreselectedStaffId.value = null
                                    viewModel.isAssignTaskModalOpen.value = true
                                },
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, BorderSubtle),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = TextPrimary),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                                modifier = Modifier.testTag("assign_task_button")
                            ) {
                                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Assign task", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                            }

                            Button(
                                onClick = { viewModel.isAddStaffModalOpen.value = true },
                                shape = RoundedCornerShape(8.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = BrandSlate),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                modifier = Modifier.testTag("add_staff_button")
                            ) {
                                Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("+ Add staff", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                            }
                        }
                    }

                    // Search bar
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { viewModel.setSearchQuery(it) },
                        placeholder = { Text("Search staff by name or email...", fontSize = 13.sp) },
                        singleLine = true,
                        leadingIcon = {
                            Icon(Icons.Default.Search, contentDescription = "Search", tint = TextMuted, modifier = Modifier.size(18.dp))
                        },
                        trailingIcon = {
                            if (searchQuery.isNotBlank()) {
                                IconButton(onClick = { viewModel.setSearchQuery("") }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear", tint = TextMuted, modifier = Modifier.size(16.dp))
                                }
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("staff_search_bar"),
                        shape = RoundedCornerShape(8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = BrandSlate,
                            unfocusedBorderColor = BorderSubtle,
                            focusedContainerColor = SurfaceWhite,
                            unfocusedContainerColor = SurfaceWhite
                        )
                    )

                    // Department Filter Pills
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(Department.ALL, Department.TELECALLING, Department.TECH).forEach { dept ->
                            val isSelected = departmentFilter.equals(dept, ignoreCase = true)
                            val accentColor = when (dept) {
                                Department.TELECALLING -> TelecallingPrimary
                                Department.TECH -> TechPrimary
                                else -> BrandSlate
                            }

                            FilterChip(
                                selected = isSelected,
                                onClick = { viewModel.setDepartmentFilter(dept) },
                                label = {
                                    Text(
                                        text = dept,
                                        fontSize = 12.sp,
                                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                                    )
                                },
                                shape = RoundedCornerShape(8.dp),
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = accentColor,
                                    selectedLabelColor = Color.White,
                                    containerColor = SurfaceWhite,
                                    labelColor = TextSecondary
                                ),
                                border = BorderStroke(1.dp, if (isSelected) accentColor else BorderSubtle),
                                modifier = Modifier.testTag("filter_${dept.lowercase()}")
                            )
                        }
                    }
                }
            }

            // Summary metric cards
            item {
                BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                    if (maxWidth < 600.dp) {
                        // 2x2 grid on mobile
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                SaaSStatCard(
                                    title = "Present today",
                                    value = "${metrics.presentToday}",
                                    subtitle = "Checked in today",
                                    icon = Icons.Default.CheckCircle,
                                    iconTint = StatusGreen,
                                    modifier = Modifier.weight(1f).testTag("stat_present_today")
                                )
                                SaaSStatCard(
                                    title = "Late check-ins",
                                    value = "${metrics.lateCheckIns}",
                                    subtitle = "After 09:30 AM",
                                    icon = Icons.Default.Warning,
                                    iconTint = StatusAmber,
                                    modifier = Modifier.weight(1f).testTag("stat_late_checkins")
                                )
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                SaaSStatCard(
                                    title = "Open tasks",
                                    value = "${metrics.openTasks}",
                                    subtitle = "Pending / In progress",
                                    icon = Icons.Default.Assignment,
                                    iconTint = BrandBlue,
                                    modifier = Modifier.weight(1f).testTag("stat_open_tasks")
                                )
                                SaaSStatCard(
                                    title = "Resigned (last 30d)",
                                    value = "${metrics.resignedLast30Days}",
                                    subtitle = "Status resigned",
                                    icon = Icons.Default.PersonOff,
                                    iconTint = StatusGray,
                                    modifier = Modifier.weight(1f).testTag("stat_resigned")
                                )
                            }
                        }
                    } else {
                        // 4 cards in a row on tablet/expanded
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            SaaSStatCard(
                                title = "Present today",
                                value = "${metrics.presentToday}",
                                subtitle = "Checked in today",
                                icon = Icons.Default.CheckCircle,
                                iconTint = StatusGreen,
                                modifier = Modifier.weight(1f).testTag("stat_present_today")
                            )
                            SaaSStatCard(
                                title = "Late check-ins",
                                value = "${metrics.lateCheckIns}",
                                subtitle = "After 09:30 AM",
                                icon = Icons.Default.Warning,
                                iconTint = StatusAmber,
                                modifier = Modifier.weight(1f).testTag("stat_late_checkins")
                            )
                            SaaSStatCard(
                                title = "Open tasks",
                                value = "${metrics.openTasks}",
                                subtitle = "Pending / In progress",
                                icon = Icons.Default.Assignment,
                                iconTint = BrandBlue,
                                modifier = Modifier.weight(1f).testTag("stat_open_tasks")
                            )
                            SaaSStatCard(
                                title = "Resigned (last 30d)",
                                value = "${metrics.resignedLast30Days}",
                                subtitle = "Status resigned",
                                icon = Icons.Default.PersonOff,
                                iconTint = StatusGray,
                                modifier = Modifier.weight(1f).testTag("stat_resigned")
                            )
                        }
                    }
                }
            }

            // Staff Table Section Header
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Staff directory (${filteredStaff.size})",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary
                    )
                    Text(
                        text = "Tap any staff to view full profile",
                        fontSize = 12.sp,
                        color = TextMuted
                    )
                }
            }

            // Staff Table Rows
            if (filteredStaff.isEmpty()) {
                item {
                    SaaSCard(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "No staff members match the selected filter.",
                                fontSize = 13.sp,
                                color = TextMuted
                            )
                        }
                    }
                }
            } else {
                items(filteredStaff) { staff ->
                    val todayAtt = attendanceList.find { it.staff_id == staff.id && it.date == todayIso }
                    val staffTask = tasksList.find { it.staff_id == staff.id && it.status != "done" }
                        ?: tasksList.find { it.staff_id == staff.id }
                    val staffUpdate = dailyUpdatesList.find { it.staff_id == staff.id }

                    StaffTableRowCard(
                        staff = staff,
                        todayAttendance = todayAtt,
                        currentTask = staffTask,
                        lastUpdate = staffUpdate,
                        onClick = {
                            viewModel.navigateTo(Screen.StaffProfile(staff.id))
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun HRTopBar(
    managerName: String,
    onLogout: () -> Unit,
    onOpenRules: () -> Unit
) {
    Surface(
        color = SurfaceWhite,
        border = BorderStroke(1.dp, BorderSubtle),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(BrandNavy),
                    contentAlignment = Alignment.Center
                ) {
                    Text("HR", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
                Column {
                    Text(
                        text = "HR System",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                    Text(
                        text = managerName,
                        fontSize = 12.sp,
                        color = TextSecondary
                    )
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onOpenRules) {
                    Icon(
                        Icons.Default.Security,
                        contentDescription = "Firestore security rules",
                        tint = TextSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
                IconButton(
                    onClick = onLogout,
                    modifier = Modifier.testTag("hr_logout_button")
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ExitToApp,
                        contentDescription = "Sign out",
                        tint = TextSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun StaffTableRowCard(
    staff: Staff,
    todayAttendance: Attendance?,
    currentTask: TaskItem?,
    lastUpdate: DailyUpdate?,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .testTag("staff_row_${staff.id}"),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = SurfaceWhite),
        border = BorderStroke(1.dp, BorderSubtle),
        elevation = CardDefaults.cardElevation(0.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Row 1: Name, Department badge, Status badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = staff.name,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary
                    )
                    Text(
                        text = staff.email,
                        fontSize = 12.sp,
                        color = TextMuted
                    )
                }

                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    DepartmentBadge(department = staff.department)
                    StatusBadge(status = staff.status)
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Row 2: Check-in time, Today's task, Last update
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SurfaceSubtle, RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Check-in status
                Column(modifier = Modifier.weight(1f)) {
                    Text("Check-in", fontSize = 11.sp, color = TextMuted)
                    Text(
                        text = if (todayAttendance == null) "Not checked in"
                        else if (todayAttendance.is_late) "${todayAttendance.check_in_time} (Late)"
                        else "${todayAttendance.check_in_time} (On time)",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (todayAttendance == null) TextMuted
                        else if (todayAttendance.is_late) StatusAmberText
                        else StatusGreenText
                    )
                }

                // Today's task
                Column(modifier = Modifier.weight(1.3f).padding(horizontal = 6.dp)) {
                    Text("Today's task", fontSize = 11.sp, color = TextMuted)
                    Text(
                        text = currentTask?.description ?: "No task assigned",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextPrimary,
                        maxLines = 1
                    )
                }

                // Last updated
                Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                    Text("Last update", fontSize = 11.sp, color = TextMuted)
                    Text(
                        text = if (lastUpdate != null) DateTimeUtils.formatIsoToReadable(lastUpdate.date) else "No update",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary
                    )
                }
            }
        }
    }
}
