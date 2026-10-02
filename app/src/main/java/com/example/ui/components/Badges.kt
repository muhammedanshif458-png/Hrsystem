package com.example.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.Department
import com.example.data.model.Status
import com.example.data.model.TaskStatus
import com.example.ui.theme.*

@Composable
fun DepartmentBadge(
    department: String,
    modifier: Modifier = Modifier
) {
    val isTelecalling = department.equals(Department.TELECALLING, ignoreCase = true)
    val bgColor = if (isTelecalling) TelecallingLightBg else TechLightBg
    val borderColor = if (isTelecalling) TelecallingBorder else TechBorder
    val textColor = if (isTelecalling) TelecallingDark else TechDark

    Box(
        modifier = modifier
            .background(bgColor, RoundedCornerShape(8.dp))
            .border(BorderStroke(1.dp, borderColor), RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (isTelecalling) "Telecalling" else "Tech",
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = textColor
        )
    }
}

@Composable
fun StatusBadge(
    status: String,
    modifier: Modifier = Modifier
) {
    val (bgColor, borderColor, textColor, label) = when (status.lowercase()) {
        Status.ACTIVE, "on time", "active" -> {
            Tuple4(StatusGreenBg, StatusGreenBorder, StatusGreenText, if (status.equals("active", true)) "Active" else "On time")
        }
        "late" -> {
            Tuple4(StatusAmberBg, StatusAmberBorder, StatusAmberText, "Late")
        }
        Status.RESIGNED, "resigned" -> {
            Tuple4(StatusGrayBg, StatusGrayBorder, StatusGrayText, "Resigned")
        }
        "on leave", "inactive" -> {
            Tuple4(StatusGrayBg, StatusGrayBorder, StatusGrayText, "On leave")
        }
        TaskStatus.PENDING, "pending" -> {
            Tuple4(Color(0xFFFEF9C3), Color(0xFFFEF08A), Color(0xFF854D0E), "Pending")
        }
        TaskStatus.IN_PROGRESS, "in progress" -> {
            Tuple4(BrandBlueBg, BrandBlueBorder, Color(0xFF1D4ED8), "In progress")
        }
        TaskStatus.DONE, "done" -> {
            Tuple4(StatusGreenBg, StatusGreenBorder, StatusGreenText, "Done")
        }
        else -> {
            Tuple4(StatusGrayBg, StatusGrayBorder, StatusGrayText, status)
        }
    }

    Box(
        modifier = modifier
            .background(bgColor, RoundedCornerShape(8.dp))
            .border(BorderStroke(1.dp, borderColor), RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = textColor
        )
    }
}

private data class Tuple4<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
