package com.example.util

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object DateTimeUtils {
    private val isoDateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private val timeFormat = SimpleDateFormat("hh:mm a", Locale.US)
    private val displayDateFormat = SimpleDateFormat("EEEE, d MMMM yyyy", Locale.US)
    private val shortDateFormat = SimpleDateFormat("MMM d, yyyy", Locale.US)

    fun getTodayIsoDate(): String {
        return isoDateFormat.format(Date())
    }

    fun getCurrentTime(): String {
        return timeFormat.format(Date())
    }

    fun getTodayFormatted(): String {
        return displayDateFormat.format(Date())
    }

    fun formatIsoToReadable(isoDate: String): String {
        return try {
            val parsed = isoDateFormat.parse(isoDate)
            if (parsed != null) shortDateFormat.format(parsed) else isoDate
        } catch (_: Exception) {
            isoDate
        }
    }

    fun isTimeLate(timeStr: String, cutoffHour: Int = 9, cutoffMinute: Int = 30): Boolean {
        return try {
            val parsed = timeFormat.parse(timeStr) ?: return false
            val cal = Calendar.getInstance()
            cal.time = parsed
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val minute = cal.get(Calendar.MINUTE)
            hour > cutoffHour || (hour == cutoffHour && minute > cutoffMinute)
        } catch (_: Exception) {
            false
        }
    }

    fun isWithinLast30Days(dateStr: String?): Boolean {
        if (dateStr.isNullOrBlank()) return false
        return try {
            val parsed = isoDateFormat.parse(dateStr) ?: return false
            val now = Calendar.getInstance()
            val thirtyDaysAgo = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -30)
            }
            parsed.after(thirtyDaysAgo.time) && parsed.before(now.time)
        } catch (_: Exception) {
            false
        }
    }
}
