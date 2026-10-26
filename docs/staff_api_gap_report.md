# Staff API Gap Report

## 1. Missing APIs (Backend Endpoints Not Available)
These features exist in the Staff frontend UI and require local storage/mock data because no documented backend endpoint exists.

* **Break Management (Start/End Break):** UI supports tracking active breaks, but `api_contract.md` lists no `POST /staff/attendance/break` endpoint.
* **Chat / Messaging:** UI contains `_ChatPage` and floating action chat features, but no WebSocket or REST API exists.
* **Tasks & Daily Work Update:** Telecalling tasks and end-of-day submissions are preserved as UI components without backend destinations.
* **Resignation Request:** UI supports submitting resignation, but the contract lacks a POST endpoint for this.
* **Medical Document Uploads:** Missing endpoint for multipart file handling (e.g. sick leave evidence).
* **Settings & Notifications:** UI toggles exist, but no `PATCH /staff/settings` is provided.

## 2. Frontend / Backend Contract Mismatches
* **Staff Profile Update (`PUT /staff/profile`):**
  * *Status:* High Priority Mismatch.
  * *Gap:* The current UI only sends `phone` and `address`. The backend contract expects or supports `phone`, `city`, and `emergencyContact`. The UI form needs to be expanded to collect these missing fields.
* **Staff Dashboard (`GET /staff/dashboard`):** 
  * *Status:* High Priority Blocker.
  * *Gap:* The route is documented in `api_contract.md` but lacks any valid JSON response schema documentation. The frontend continues to display mock shifts and tasks until the true shape of `data` is known.
* **Authentication Token Handling:**
  * *Status:* Medium Priority.
  * *Gap:* `POST /auth/login` works, but `POST /auth/refresh-token` lacks documentation on the exact token envelope schema (e.g., does it return `{ data: { accessToken: "..." } }`?). Prevents robust session resumption.

## 3. Unverified Response Schemas
* **Check-in/Check-out Returns:**
  * *Gap:* The check-in and check-out responses only guarantee `data.checkInTime` and `data.workingHours`. It is unverified if they return full attendance models or just those single values. The frontend currently relies on firing a subsequent `GET /staff/attendance` to ensure safety and data consistency.

## 4. Test Verification Status
* **Mock HTTP Tests & Compilation:** 
  * *Gap:* The `flutter test` mock tests currently fail compilation due to a missing `final HRRepository repository;` parameter declaration inside the `StaffHubShell` widget constructor in `lib/staff_screens.dart`. This syntax error was introduced during the dependency injection phase and must be fixed before the UI can successfully run its integrated mock tests.
