# Staff Screen Verification Report

## 1. Project Identification
* **Frontend Project:** `hr-core (1)` (Flutter Mobile Application)
* **Backend Project:** Missing from local workspace; interacting with remote host `https://hrsystembackend-4xzs.onrender.com/api`.
* **Note:** The Staff portal is integrated as part of `lib/staff_screens.dart` within the broader HR Core app.

## 2. Screen Inventory & Wiring

### 2.1 Login / Auth (`lib/login_screen.dart` - assumed entry point)
* **Action:** Login with Email/Password
* **Data Source:** Existing Backend API
* **Route:** `POST /auth/login`
* **Status:** Verified and connected via `HRRepository.signIn`. Token is stored in `TokenStorage`.

### 2.2 Staff Dashboard (`lib/staff_screens.dart` - `_DashboardPage`)
* **Action:** Display active shifts, tasks summary, recent leaves.
* **Data Source:** Mock / Local
* **Route:** `GET /staff/dashboard` (Configured but blocked by missing contract schema)
* **Status:** UI uses mock data. API exists in `ApiConfig` but is not connected.

### 2.3 Staff Profile (`lib/staff_screens.dart` - `_ProfilePage`)
* **Action:** View Profile Data
* **Data Source:** Existing Backend API
* **Route:** `GET /staff/profile`
* **Status:** Connected and successfully wiring backend values to UI via `fetchProfile()`.
* **Action:** Edit Phone / Address
* **Data Source:** Existing Backend API
* **Route:** `PUT /staff/profile`
* **Status:** Connected via native AlertDialog inside UI, invoking `updateProfile()`.

### 2.4 Staff Attendance (`lib/staff_screens.dart` - `_AttendancePage`)
* **Action:** Check-in & Check-out
* **Data Source:** Existing Backend API
* **Route:** `POST /staff/attendance/check-in`, `POST /staff/attendance/check-out`
* **Status:** Connected in repository. `checkIn` and `checkOut` trigger `fetchStaffAttendance()` to update state.
* **Action:** Attendance History List
* **Data Source:** Existing Backend API
* **Route:** `GET /staff/attendance`
* **Status:** Connected. State management `ValueListenableBuilder` naturally reacts to `fetchStaffAttendance()` updates.

### 2.5 Staff Leaves (`lib/staff_screens.dart` - `_LeavePage`)
* **Action:** Leave Application Form
* **Data Source:** Existing Backend API
* **Route:** `POST /staff/leaves`
* **Status:** Connected. `requestLeave()` securely maps fields and updates the local repository.
* **Action:** Leave History
* **Data Source:** Existing Backend API
* **Route:** `GET /staff/leaves`
* **Status:** Connected. `fetchStaffLeaves()` pulls data properly.
* **Action:** Cancel/Delete Leave
* **Data Source:** Existing Backend API
* **Route:** `DELETE /staff/leaves/:id`
* **Status:** Connected in repository (`deleteLeaveRequest()`).

### 2.6 Break Management (`lib/staff_screens.dart`)
* **Action:** Start/End Breaks
* **Data Source:** Local storage only
* **Route:** Missing Backend Requirement
* **Status:** Preserved as a local behavior since no backend endpoint exists.

### 2.7 Chat, Tasks, Daily Update, WFH, Medical Uploads, Settings
* **Data Source:** Local mock data / Unimplemented
* **Route:** Missing Backend Requirements
* **Status:** Preserved existing mock functionality. No documented API exists in `api_contract.md`.
