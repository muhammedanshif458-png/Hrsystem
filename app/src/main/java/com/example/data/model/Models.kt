package com.example.data.model

data class Staff(
    val id: String = "",
    val name: String = "",
    val email: String = "",
    val department: String = Department.TECH,
    val role: String = Role.STAFF,
    val join_date: String = "",
    val status: String = Status.ACTIVE,
    val resigned_date: String? = null
)

object Department {
    const val ALL = "All"
    const val TELECALLING = "Telecalling"
    const val TECH = "Tech"

    val list = listOf(TELECALLING, TECH)
}

object Role {
    const val STAFF = "Staff"
    const val HR_MANAGER = "HR Manager"

    val list = listOf(STAFF, HR_MANAGER)
}

object Status {
    const val ACTIVE = "active"
    const val RESIGNED = "resigned"
}

data class Attendance(
    val id: String = "",
    val staff_id: String = "",
    val date: String = "", // YYYY-MM-DD
    val check_in_time: String = "",
    val check_out_time: String? = null,
    val is_late: Boolean = false
)

data class TaskItem(
    val id: String = "",
    val staff_id: String = "",
    val department: String = "",
    val description: String = "",
    val status: String = TaskStatus.PENDING, // pending, in progress, done
    val date: String = "",
    val due_date: String = ""
)

object TaskStatus {
    const val PENDING = "pending"
    const val IN_PROGRESS = "in progress"
    const val DONE = "done"

    val list = listOf(PENDING, IN_PROGRESS, DONE)
}

data class DailyUpdate(
    val id: String = "",
    val staff_id: String = "",
    val date: String = "",
    val update_text: String = ""
)
