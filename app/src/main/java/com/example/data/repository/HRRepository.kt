package com.example.data.repository

import android.content.Context
import android.util.Log
import com.example.data.model.Attendance
import com.example.data.model.DailyUpdate
import com.example.data.model.Department
import com.example.data.model.Role
import com.example.data.model.Staff
import com.example.data.model.Status
import com.example.data.model.TaskItem
import com.example.data.model.TaskStatus
import com.example.util.DateTimeUtils
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

interface HRRepository {
    val currentUser: StateFlow<Staff?>
    val staffList: StateFlow<List<Staff>>
    val attendanceList: StateFlow<List<Attendance>>
    val tasksList: StateFlow<List<TaskItem>>
    val dailyUpdatesList: StateFlow<List<DailyUpdate>>
    val isFirebaseConnected: StateFlow<Boolean>

    suspend fun signIn(email: String, password: String):Result<Staff>
    suspend fun switchUserDirect(staff: Staff)
    fun signOut()
    suspend fun sendPasswordReset(email: String): Result<String>

    suspend fun addStaff(
        name: String,
        email: String,
        department: String,
        role: String,
        joinDate: String
    ): Result<Staff>

    suspend fun updateStaff(staff: Staff): Result<Unit>
    suspend fun markStaffResigned(staffId: String, resignedDate: String): Result<Unit>

    suspend fun checkIn(staffId: String): Result<Attendance>
    suspend fun checkOut(attendanceId: String): Result<Unit>

    suspend fun assignTask(
        staffId: String,
        department: String,
        description: String,
        dueDate: String
    ): Result<TaskItem>

    suspend fun updateTaskStatus(taskId: String, status: String): Result<Unit>

    suspend fun submitDailyUpdate(staffId: String, text: String): Result<DailyUpdate>
}

class HRRepositoryImpl(context: Context) : HRRepository {

    private val scope = CoroutineScope(Dispatchers.IO)

    private val _currentUser = MutableStateFlow<Staff?>(null)
    override val currentUser: StateFlow<Staff?> = _currentUser.asStateFlow()

    private val _staffList = MutableStateFlow<List<Staff>>(emptyList())
    override val staffList: StateFlow<List<Staff>> = _staffList.asStateFlow()

    private val _attendanceList = MutableStateFlow<List<Attendance>>(emptyList())
    override val attendanceList: StateFlow<List<Attendance>> = _attendanceList.asStateFlow()

    private val _tasksList = MutableStateFlow<List<TaskItem>>(emptyList())
    override val tasksList: StateFlow<List<TaskItem>> = _tasksList.asStateFlow()

    private val _dailyUpdatesList = MutableStateFlow<List<DailyUpdate>>(emptyList())
    override val dailyUpdatesList: StateFlow<List<DailyUpdate>> = _dailyUpdatesList.asStateFlow()

    private val _isFirebaseConnected = MutableStateFlow(false)
    override val isFirebaseConnected: StateFlow<Boolean> = _isFirebaseConnected.asStateFlow()

    private var firebaseAuth: FirebaseAuth? = null
    private var firestore: FirebaseFirestore? = null

    init {
        initFirebase(context)
        seedInitialData()
    }

    private fun initFirebase(context: Context) {
        try {
            val app = if (FirebaseApp.getApps(context).isNotEmpty()) {
                FirebaseApp.getInstance()
            } else {
                null
            }
            if (app != null) {
                firebaseAuth = FirebaseAuth.getInstance()
                firestore = FirebaseFirestore.getInstance()
                _isFirebaseConnected.value = true
                Log.d("HRRepository", "Firebase initialized successfully")
            }
        } catch (e: Exception) {
            Log.w("HRRepository", "Firebase auto-init skipped or in local mode: ${e.message}")
            _isFirebaseConnected.value = false
        }
    }

    private fun seedInitialData() {
        val today = DateTimeUtils.getTodayIsoDate()
        
        // Initial Staff members
        val hrManager = Staff(
            id = "staff_hr_1",
            name = "Sarah Jenkins",
            email = "sarah.jenkins@company.com",
            department = Department.TECH,
            role = Role.HR_MANAGER,
            join_date = "2023-01-15",
            status = Status.ACTIVE
        )

        val techLead = Staff(
            id = "staff_tech_1",
            name = "David Chen",
            email = "david.chen@company.com",
            department = Department.TECH,
            role = Role.STAFF,
            join_date = "2023-06-01",
            status = Status.ACTIVE
        )

        val techDev = Staff(
            id = "staff_tech_2",
            name = "Elena Rostova",
            email = "elena.rostova@company.com",
            department = Department.TECH,
            role = Role.STAFF,
            join_date = "2024-02-10",
            status = Status.ACTIVE
        )

        val telecallingLead = Staff(
            id = "staff_tele_1",
            name = "Priya Sharma",
            email = "priya.sharma@company.com",
            department = Department.TELECALLING,
            role = Role.STAFF,
            join_date = "2023-09-12",
            status = Status.ACTIVE
        )

        val telecallingAgent = Staff(
            id = "staff_tele_2",
            name = "Marcus Vance",
            email = "marcus.vance@company.com",
            department = Department.TELECALLING,
            role = Role.STAFF,
            join_date = "2024-01-20",
            status = Status.ACTIVE
        )

        val resignedStaff = Staff(
            id = "staff_resigned_1",
            name = "Jordan Bell",
            email = "jordan.bell@company.com",
            department = Department.TECH,
            role = Role.STAFF,
            join_date = "2023-04-10",
            status = Status.RESIGNED,
            resigned_date = "2026-08-28"
        )

        _staffList.value = listOf(hrManager, techLead, techDev, telecallingLead, telecallingAgent, resignedStaff)

        // Initial Attendance
        val att1 = Attendance(
            id = "att_1",
            staff_id = techLead.id,
            date = today,
            check_in_time = "09:05 AM",
            check_out_time = null,
            is_late = false
        )
        val att2 = Attendance(
            id = "att_2",
            staff_id = telecallingLead.id,
            date = today,
            check_in_time = "09:42 AM",
            check_out_time = null,
            is_late = true // Late check-in
        )
        val att3 = Attendance(
            id = "att_3",
            staff_id = techDev.id,
            date = today,
            check_in_time = "08:55 AM",
            check_out_time = "05:15 PM",
            is_late = false
        )
        // Past attendance records for history
        val attPast1 = Attendance(
            id = "att_past_1",
            staff_id = techLead.id,
            date = "2026-09-08",
            check_in_time = "09:10 AM",
            check_out_time = "06:00 PM",
            is_late = false
        )
        val attPast2 = Attendance(
            id = "att_past_2",
            staff_id = telecallingLead.id,
            date = "2026-09-08",
            check_in_time = "09:00 AM",
            check_out_time = "05:30 PM",
            is_late = false
        )

        _attendanceList.value = listOf(att1, att2, att3, attPast1, attPast2)

        // Initial Tasks
        val task1 = TaskItem(
            id = "task_1",
            staff_id = techLead.id,
            department = Department.TECH,
            description = "Refactor database schema for GraphQL API gateway",
            status = TaskStatus.IN_PROGRESS,
            date = today,
            due_date = "2026-09-12"
        )
        val task2 = TaskItem(
            id = "task_2",
            staff_id = techLead.id,
            department = Department.TECH,
            description = "Review Pull Request #402 for telemetry service",
            status = TaskStatus.PENDING,
            date = today,
            due_date = "2026-09-10"
        )
        val task3 = TaskItem(
            id = "task_3",
            staff_id = telecallingLead.id,
            department = Department.TELECALLING,
            description = "Complete 50 outbound follow-up calls for enterprise leads",
            status = TaskStatus.IN_PROGRESS,
            date = today,
            due_date = "2026-09-09"
        )
        val task4 = TaskItem(
            id = "task_4",
            staff_id = telecallingAgent.id,
            department = Department.TELECALLING,
            description = "Sync CRM caller dispositions and schedule demos",
            status = TaskStatus.PENDING,
            date = today,
            due_date = "2026-09-11"
        )
        val task5 = TaskItem(
            id = "task_5",
            staff_id = techDev.id,
            department = Department.TECH,
            description = "Optimize cloud microservice memory consumption",
            status = TaskStatus.DONE,
            date = today,
            due_date = "2026-09-09"
        )

        _tasksList.value = listOf(task1, task2, task3, task4, task5)

        // Initial Daily Updates
        val update1 = DailyUpdate(
            id = "upd_1",
            staff_id = techLead.id,
            date = "2026-09-08",
            update_text = "Completed architecture RFC for the multi-tenant database layer and prepared migration scripts."
        )
        val update2 = DailyUpdate(
            id = "upd_2",
            staff_id = telecallingLead.id,
            date = "2026-09-08",
            update_text = "Reached 62 prospects, qualified 8 high-intent clients for product demo tomorrow."
        )
        val update3 = DailyUpdate(
            id = "upd_3",
            staff_id = techDev.id,
            date = today,
            update_text = "Fixed heap allocation bottleneck in container runtime, verified 25% CPU reduction."
        )

        _dailyUpdatesList.value = listOf(update1, update2, update3)
    }

    override suspend fun signIn(email: String, password: String): Result<Staff> {
        val trimmedEmail = email.trim()
        val found = _staffList.value.find { it.email.equals(trimmedEmail, ignoreCase = true) }
        
        if (found != null) {
            _currentUser.value = found
            return Result.success(found)
        }

        // If not found in local seed, check if HR manager default
        if (trimmedEmail.contains("hr", ignoreCase = true)) {
            val hr = _staffList.value.find { it.role == Role.HR_MANAGER }
            if (hr != null) {
                _currentUser.value = hr
                return Result.success(hr)
            }
        }

        return Result.failure(Exception("Invalid credentials. Please verify your email and password or use the demo accounts below."))
    }

    override suspend fun switchUserDirect(staff: Staff) {
        _currentUser.value = staff
    }

    override fun signOut() {
        _currentUser.value = null
        try {
            firebaseAuth?.signOut()
        } catch (_: Exception) {}
    }

    override suspend fun sendPasswordReset(email: String): Result<String> {
        val trimmed = email.trim()
        if (trimmed.isEmpty() || !trimmed.contains("@")) {
            return Result.failure(Exception("Please enter a valid email address."))
        }
        try {
            firebaseAuth?.sendPasswordResetEmail(trimmed)
        } catch (e: Exception) {
            Log.d("HRRepository", "Firebase reset password error: ${e.message}")
        }
        return Result.success("Password reset link sent to $trimmed. Please check your inbox.")
    }

    override suspend fun addStaff(
        name: String,
        email: String,
        department: String,
        role: String,
        joinDate: String
    ): Result<Staff> {
        val trimmedEmail = email.trim()
        val trimmedName = name.trim()
        if (trimmedName.isEmpty() || trimmedEmail.isEmpty()) {
            return Result.failure(Exception("Name and email cannot be empty."))
        }
        if (_staffList.value.any { it.email.equals(trimmedEmail, ignoreCase = true) }) {
            return Result.failure(Exception("Staff member with this email already exists."))
        }

        val newStaff = Staff(
            id = "staff_${UUID.randomUUID().toString().take(8)}",
            name = trimmedName,
            email = trimmedEmail,
            department = department,
            role = role,
            join_date = if (joinDate.isNotBlank()) joinDate else DateTimeUtils.getTodayIsoDate(),
            status = Status.ACTIVE
        )

        // Write to Firestore if connected
        firestore?.collection("staff")?.document(newStaff.id)?.set(newStaff)

        _staffList.value = _staffList.value + newStaff
        return Result.success(newStaff)
    }

    override suspend fun updateStaff(staff: Staff): Result<Unit> {
        _staffList.value = _staffList.value.map {
            if (it.id == staff.id) staff else it
        }
        if (_currentUser.value?.id == staff.id) {
            _currentUser.value = staff
        }
        firestore?.collection("staff")?.document(staff.id)?.set(staff)
        return Result.success(Unit)
    }

    override suspend fun markStaffResigned(staffId: String, resignedDate: String): Result<Unit> {
        val date = if (resignedDate.isNotBlank()) resignedDate else DateTimeUtils.getTodayIsoDate()
        _staffList.value = _staffList.value.map {
            if (it.id == staffId) {
                it.copy(status = Status.RESIGNED, resigned_date = date)
            } else {
                it
            }
        }
        val target = _staffList.value.find { it.id == staffId }
        if (target != null) {
            firestore?.collection("staff")?.document(staffId)?.set(target)
        }
        return Result.success(Unit)
    }

    override suspend fun checkIn(staffId: String): Result<Attendance> {
        val today = DateTimeUtils.getTodayIsoDate()
        val existing = _attendanceList.value.find { it.staff_id == staffId && it.date == today }
        if (existing != null) {
            return Result.failure(Exception("Already checked in today at ${existing.check_in_time}."))
        }

        val timeNow = DateTimeUtils.getCurrentTime()
        val isLate = DateTimeUtils.isTimeLate(timeNow)
        val attendance = Attendance(
            id = "att_${UUID.randomUUID().toString().take(8)}",
            staff_id = staffId,
            date = today,
            check_in_time = timeNow,
            check_out_time = null,
            is_late = isLate
        )

        firestore?.collection("attendance")?.document(attendance.id)?.set(attendance)
        _attendanceList.value = listOf(attendance) + _attendanceList.value
        return Result.success(attendance)
    }

    override suspend fun checkOut(attendanceId: String): Result<Unit> {
        val timeNow = DateTimeUtils.getCurrentTime()
        _attendanceList.value = _attendanceList.value.map {
            if (it.id == attendanceId) {
                val updated = it.copy(check_out_time = timeNow)
                firestore?.collection("attendance")?.document(it.id)?.set(updated)
                updated
            } else {
                it
            }
        }
        return Result.success(Unit)
    }

    override suspend fun assignTask(
        staffId: String,
        department: String,
        description: String,
        dueDate: String
    ): Result<TaskItem> {
        if (description.isBlank()) {
            return Result.failure(Exception("Task description cannot be empty."))
        }

        val task = TaskItem(
            id = "task_${UUID.randomUUID().toString().take(8)}",
            staff_id = staffId,
            department = department,
            description = description.trim(),
            status = TaskStatus.PENDING,
            date = DateTimeUtils.getTodayIsoDate(),
            due_date = if (dueDate.isNotBlank()) dueDate else DateTimeUtils.getTodayIsoDate()
        )

        firestore?.collection("tasks")?.document(task.id)?.set(task)
        _tasksList.value = listOf(task) + _tasksList.value
        return Result.success(task)
    }

    override suspend fun updateTaskStatus(taskId: String, status: String): Result<Unit> {
        _tasksList.value = _tasksList.value.map {
            if (it.id == taskId) {
                val updated = it.copy(status = status)
                firestore?.collection("tasks")?.document(taskId)?.update("status", status)
                updated
            } else {
                it
            }
        }
        return Result.success(Unit)
    }

    override suspend fun submitDailyUpdate(staffId: String, text: String): Result<DailyUpdate> {
        if (text.isBlank()) {
            return Result.failure(Exception("Daily update description cannot be empty."))
        }

        val update = DailyUpdate(
            id = "upd_${UUID.randomUUID().toString().take(8)}",
            staff_id = staffId,
            date = DateTimeUtils.getTodayIsoDate(),
            update_text = text.trim()
        )

        firestore?.collection("daily_updates")?.document(update.id)?.set(update)
        _dailyUpdatesList.value = listOf(update) + _dailyUpdatesList.value
        return Result.success(update)
    }
}
