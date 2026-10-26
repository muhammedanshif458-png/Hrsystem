# StaffHub attendance backend contract audit

## Client contract observed in this repository

`ApiConfig` defines `POST /staff/attendance/check-in`,
`POST /staff/attendance/check-out`, and `GET /staff/attendance`, relative to the
configured API base URL (the documented deployment base is
`https://hrsystembackend-4xzs.onrender.com/api`). The client sends an empty JSON
object to both POST operations and does not send employee or department fields.
`ApiService` adds the saved session token as `Authorization: Bearer …`.

The repository's local API contract marks protected attendance endpoints
unverified for lack of valid credentials. No HrsystemBackend source is present in
this project. Consequently the client source alone cannot prove that the backend
resolves the employee and department from the authenticated user, enforces the
department schedule/effective date/timezone/grace period, or preserves fields on
check-out.

## Break API status and required backend work

No break start/end endpoint is present in the original client API contract, and
the checked-in backend source is absent. The previous Flutter `toggleBreak`
implementation modified SharedPreferences only; it did not persist break
records on the server. Its frontend start-time gate used fixed local times of
11:30, 13:30, and 16:00. That gate has been removed from break starts. There is
no evidence in this repository that the deployed backend applies a scheduled
break restriction, so its exact server-side restriction cannot be established
without backend source or a verified authenticated call.

The updated Flutter client expects these authenticated routes, which must be
implemented by the backend before live break persistence is available:

* `POST /staff/attendance/{attendanceId}/breaks/start` with
  `{"breakType":"morning|lunch|afternoon"}`.
* `POST /staff/attendance/{attendanceId}/breaks/end` with the same `breakType`.
* Both return `{ "success": true }` only after writing; GET
  `/staff/attendance` returns the attendance record with its break array,
  including stable break id, type, ISO-8601 `startTime`, nullable `endTime`, and
  duration. The client refreshes attendance after every successful operation.

Backend handlers must derive the employee from the bearer token, verify that
the attendance record belongs to that employee and shift, permit any of the
three configured break types at any time during an active shift, atomically
reject a second simultaneous break, reject starts before check-in/after
check-out, and reject ending a break that is not active. If the deployed server
currently enforces the schedule, remove that validation for break start; no
exact server restriction is claimed here. These routes and behavior are a
required integration contract, not proof that the current backend implements
them.

## Fields StaffHub reads

Attendance records are read from the `data` array of the successful GET envelope.
The model recognizes `_id`/`id`, `employee`/`staffId`, `department`, `date`,
`checkIn`/`checkInAt`/`checkInTimestamp`, `checkInTime`,
`checkOut`/`checkOutAt`/`checkOutTimestamp`, `checkOutTime`, `workingHours` or
`workedDuration`, `isLate` or `late` (also `status: LATE`), `minutesLate`, and
`scheduleSnapshot` (or `schedule`). The client does not calculate late status.
The check-in POST response must have `{success: true, data: <record>}`; it is
followed by GET and the refreshed record is preferred. Check-out requires a
successful envelope and is followed by GET.

## Backend contract needed to complete verification

The backend should return the saved attendance record from check-in and GET with
an unambiguous ISO-8601 `checkIn` timestamp, employee identifier, department,
`isLate` boolean, `minutesLate` integer (zero when on time), and an immutable
`scheduleSnapshot` containing the effective check-in time, timezone, grace
period, and effective date. Check-out should update and return `checkOut` and
`workingHours` while preserving all check-in and schedule fields. The backend
must derive identity/department from the authenticated session and apply its
configured departmental schedule. These are required contract expectations,
not claims about the currently deployed server.

Live authenticated verification was not performed. Automated API tests use a
mock HTTP adapter and establish only the StaffHub request, parsing, and refresh
behavior.
