// API LIST — STAFF APP

const String baseUrl = 'https://hrsystembackend-4xzs.onrender.com';

// ───────────── AUTH ─────────────
const String authLogin = '/api/auth/login'; // POST

// ───────────── PROFILE ─────────────
const String profile = '/api/staff/profile'; // GET, PUT
const String birthdaysToday = '/api/birthdays/today'; // GET

// ───────────── ATTENDANCE ─────────────
const String checkIn = '/api/staff/attendance/check-in'; // POST
const String checkOut = '/api/staff/attendance/check-out'; // POST
const String breakStart = '/api/staff/attendance/:attendanceId/breaks/start'; // POST
const String breakEnd = '/api/staff/attendance/:attendanceId/breaks/end'; // POST
const String attendance = '/api/staff/attendance'; // GET
const String attendanceById = '/api/staff/attendance/:attendanceId'; // GET
const String attendanceClearHistory = '/api/staff/attendance/history'; // DELETE
const String attendanceClearHistoryPost = '/api/staff/attendance/clear-history'; // POST

// ───────────── LEAVES ─────────────
const String leaves = '/api/staff/leaves'; // GET, POST
const String leaveById = '/api/staff/leaves/:id'; // DELETE
const String documentDownload = '/api/staff/documents/:id/download'; // GET

// ───────────── DAILY UPDATES ─────────────
const String dailyUpdates = '/api/staff/daily-updates'; // GET, POST

// ───────────── DEPARTMENT CHAT ─────────────
const String chatMessages = '/api/staff/departments/:deptKey/messages'; // GET, POST
const String chatSearch = '/api/staff/departments/:deptKey/messages/search'; // GET
const String chatClear = '/api/staff/departments/:deptKey/messages/clear'; // POST
const String chatMessageById = '/api/staff/departments/:deptKey/messages/:messageId'; // DELETE
const String chatDeleteForMe = '/api/staff/departments/:deptKey/messages/:messageId/delete-for-me'; // PATCH
