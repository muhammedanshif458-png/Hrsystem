package com.example.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.model.Attendance
import com.example.data.model.DailyUpdate
import com.example.data.model.Department
import com.example.data.model.Role
import com.example.data.model.Staff
import com.example.data.model.TaskItem
import com.example.data.repository.HRRepository
import com.example.util.DateTimeUtils
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

sealed interface Screen {
    data object Login : Screen
    data object StaffPortal : Screen
    data object HRDashboard : Screen
    data class StaffProfile(val staffId: String) : Screen
}

data class DashboardMetrics(
    val presentToday: Int = 0,
    val lateCheckIns: Int = 0,
    val openTasks: Int = 0,
    val resignedLast30Days: Int = 0
)

class HRViewModel(private val repository: HRRepository) : ViewModel() {

    private val _currentScreen = MutableStateFlow<Screen>(Screen.Login)
    val currentScreen: StateFlow<Screen> = _currentScreen.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _departmentFilter = MutableStateFlow(Department.ALL)
    val departmentFilter: StateFlow<String> = _departmentFilter.asStateFlow()

    private val _toastMessage = MutableStateFlow<String?>(null)
    val toastMessage: StateFlow<String?> = _toastMessage.asStateFlow()

    // Modals visibility
    val isAddStaffModalOpen = MutableStateFlow(false)
    val isAssignTaskModalOpen = MutableStateFlow(false)
    val assignTaskPreselectedStaffId = MutableStateFlow<String?>(null)
    val isEditStaffModalOpen = MutableStateFlow(false)
    val isForgotPasswordOpen = MutableStateFlow(false)
    val isFirestoreRulesOpen = MutableStateFlow(false)

    val currentUser: StateFlow<Staff?> = repository.currentUser
    val staffList: StateFlow<List<Staff>> = repository.staffList
    val attendanceList: StateFlow<List<Attendance>> = repository.attendanceList
    val tasksList: StateFlow<List<TaskItem>> = repository.tasksList
    val dailyUpdatesList: StateFlow<List<DailyUpdate>> = repository.dailyUpdatesList
    val isFirebaseConnected: StateFlow<Boolean> = repository.isFirebaseConnected

    // Computed Dashboard metrics
    val dashboardMetrics: StateFlow<DashboardMetrics> = combine(
        staffList,
        attendanceList,
        tasksList
    ) { staff, attendance, tasks ->
        val today = DateTimeUtils.getTodayIsoDate()
        val activeStaffIds = staff.filter { it.status == "active" }.map { it.id }.toSet()
        val todayAttendance = attendance.filter { it.date == today && activeStaffIds.contains(it.staff_id) }

        val presentToday = todayAttendance.size
        val lateCheckIns = todayAttendance.count { it.is_late }
        val openTasks = tasks.count { it.status != "done" }
        val resignedLast30Days = staff.count { it.status == "resigned" && DateTimeUtils.isWithinLast30Days(it.resigned_date) }

        DashboardMetrics(
            presentToday = presentToday,
            lateCheckIns = lateCheckIns,
            openTasks = openTasks,
            resignedLast30Days = resignedLast30Days
        )
    }.stateIn(viewModelScope, SharingStarted.Eagerly, DashboardMetrics())

    // Filtered staff list for HR dashboard
    val filteredStaffList: StateFlow<List<Staff>> = combine(
        staffList,
        _searchQuery,
        _departmentFilter
    ) { staff, query, dept ->
        staff.filter { s ->
            val matchesDept = dept == Department.ALL || s.department.equals(dept, ignoreCase = true)
            val matchesQuery = query.isBlank() ||
                    s.name.contains(query, ignoreCase = true) ||
                    s.email.contains(query, ignoreCase = true)
            matchesDept && matchesQuery
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    fun navigateTo(screen: Screen) {
        _currentScreen.value = screen
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setDepartmentFilter(department: String) {
        _departmentFilter.value = department
    }

    fun showToast(message: String) {
        _toastMessage.value = message
    }

    fun clearToast() {
        _toastMessage.value = null
    }

    fun login(email: String, pass: String, onError: (String) -> Unit) {
        viewModelScope.launch {
            val result = repository.signIn(email, pass)
            result.onSuccess { staff ->
                routeUserByRole(staff)
            }.onFailure { err ->
                onError(err.message ?: "Authentication failed")
            }
        }
    }

    fun quickLogin(staff: Staff) {
        viewModelScope.launch {
            repository.switchUserDirect(staff)
            routeUserByRole(staff)
        }
    }

    private fun routeUserByRole(staff: Staff) {
        if (staff.role == Role.HR_MANAGER) {
            _currentScreen.value = Screen.HRDashboard
        } else {
            _currentScreen.value = Screen.StaffPortal
        }
    }

    fun logout() {
        repository.signOut()
        _currentScreen.value = Screen.Login
    }

    fun checkIn() {
        val user = currentUser.value ?: return
        viewModelScope.launch {
            repository.checkIn(user.id).onSuccess {
                showToast(if (it.is_late) "Checked in at ${it.check_in_time} (Late check-in)" else "Checked in at ${it.check_in_time} (On time)")
            }.onFailure {
                showToast(it.message ?: "Could not check in")
            }
        }
    }

    fun checkOut(attendanceId: String) {
        viewModelScope.launch {
            repository.checkOut(attendanceId).onSuccess {
                showToast("Checked out successfully")
            }.onFailure {
                showToast(it.message ?: "Could not check out")
            }
        }
    }

    fun submitDailyUpdate(text: String, onSuccess: () -> Unit) {
        val user = currentUser.value ?: return
        viewModelScope.launch {
            repository.submitDailyUpdate(user.id, text).onSuccess {
                showToast("Daily update submitted successfully")
                onSuccess()
            }.onFailure {
                showToast(it.message ?: "Failed to submit update")
            }
        }
    }

    fun updateTaskStatus(taskId: String, newStatus: String) {
        viewModelScope.launch {
            repository.updateTaskStatus(taskId, newStatus).onSuccess {
                showToast("Task status updated to $newStatus")
            }
        }
    }

    fun addStaff(name: String, email: String, department: String, role: String, joinDate: String) {
        viewModelScope.launch {
            repository.addStaff(name, email, department, role, joinDate).onSuccess {
                isAddStaffModalOpen.value = false
                showToast("Staff member added successfully")
            }.onFailure {
                showToast(it.message ?: "Failed to add staff")
            }
        }
    }

    fun updateStaff(staff: Staff) {
        viewModelScope.launch {
            repository.updateStaff(staff).onSuccess {
                isEditStaffModalOpen.value = false
                showToast("Staff details updated")
            }.onFailure {
                showToast(it.message ?: "Failed to update staff")
            }
        }
    }

    fun markStaffResigned(staffId: String) {
        viewModelScope.launch {
            repository.markStaffResigned(staffId, DateTimeUtils.getTodayIsoDate()).onSuccess {
                showToast("Staff marked as resigned")
            }.onFailure {
                showToast(it.message ?: "Failed to update resignation status")
            }
        }
    }

    fun assignTask(staffId: String, department: String, description: String, dueDate: String) {
        viewModelScope.launch {
            repository.assignTask(staffId, department, description, dueDate).onSuccess {
                isAssignTaskModalOpen.value = false
                assignTaskPreselectedStaffId.value = null
                showToast("Task assigned successfully")
            }.onFailure {
                showToast(it.message ?: "Failed to assign task")
            }
        }
    }

    fun sendPasswordReset(email: String) {
        viewModelScope.launch {
            repository.sendPasswordReset(email).onSuccess { msg ->
                isForgotPasswordOpen.value = false
                showToast(msg)
            }.onFailure {
                showToast(it.message ?: "Password reset failed")
            }
        }
    }
}
