package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = BrandSlate,
    onPrimary = Color.White,
    primaryContainer = SurfaceSubtle,
    onPrimaryContainer = TextPrimary,
    secondary = TechPrimary,
    onSecondary = Color.White,
    secondaryContainer = TechLightBg,
    onSecondaryContainer = TechDark,
    tertiary = TelecallingPrimary,
    onTertiary = Color.White,
    tertiaryContainer = TelecallingLightBg,
    onTertiaryContainer = TelecallingDark,
    background = CanvasBg,
    onBackground = TextPrimary,
    surface = SurfaceWhite,
    onSurface = TextPrimary,
    surfaceVariant = SurfaceSubtle,
    onSurfaceVariant = TextSecondary,
    outline = BorderMedium,
    outlineVariant = BorderSubtle
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFF1F5F9),
    onPrimary = Color(0xFF0F172A),
    primaryContainer = Color(0xFF1E293B),
    onPrimaryContainer = Color(0xFFF8FAFC),
    secondary = Color(0xFF2DD4BF),
    onSecondary = Color(0xFF042F2E),
    secondaryContainer = Color(0xFF134E4A),
    onSecondaryContainer = Color(0xFFCCFBF1),
    tertiary = Color(0xFFF472B6),
    onTertiary = Color(0xFF500724),
    tertiaryContainer = Color(0xFF701A75),
    onTertiaryContainer = Color(0xFFFDF4FF),
    background = Color(0xFF0B0F17),
    onBackground = Color(0xFFF3F4F6),
    surface = Color(0xFF111827),
    onSurface = Color(0xFFF3F4F6),
    surfaceVariant = Color(0xFF1F2937),
    onSurfaceVariant = Color(0xFF9CA3AF),
    outline = Color(0xFF374151),
    outlineVariant = Color(0xFF1F2937)
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = false, // Default to clean SaaS light theme
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}

