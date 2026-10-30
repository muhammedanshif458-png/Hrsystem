## Base URL
`https://hrsystembackend-4xzs.onrender.com/api`

---

## Authentication

### POST /api/auth/login
* **Authentication:** None
* **Status:** PARTIALLY VERIFIED
* **Request Body:** (Verified via validation errors)
  ```json
  {
    "email": "string (required, valid email)",
    "password": "string (required)",
    "workMode": "OFFICE | WORK_FROM_HOME",
    "location": {
      "latitude": "number",
      "longitude": "number",
      "accuracy": "number (meters)",
      "capturedAt": "ISO-8601 timestamp"
    }
  }
* Work mode/location acceptance and the backend missing-location policy are not yet verified. The StaffHub login UI requires a successful one-time GPS capture for either work mode.
  ```
* **Success Status:** 200 OK
* **Success Response:** NOT VERIFIED
  * Cannot determine if the token is in `token`, `accessToken`, etc.
  * Cannot determine if user object is returned or its exact fields.
* **Error Status 422 (Validation Failed):** (VERIFIED)
  ```json
  {
    "success": false,
    "message": "Validation failed",
    "errors": [
      {
        "field": "email",
        "message": "Email is required",
        "value": ""
      }
    ]
  }
  ```
* **Error Status 401 (Invalid Credentials):** (VERIFIED)
  ```json
  {
    "success": false,
    "message": "Invalid email or password",
    "error": null
  }
  ```
* **Flutter Screen:** `LoginScreen`
* **Flutter Action:** `_repository.signIn(email, password)`

---

### Protected Endpoints (General)
* **Authentication Requirement:** Token required.
* **Format:** Expects `Authorization: Bearer <token>`
* **Error Status 401 (Unauthenticated):** (VERIFIED)
  ```json
  {
    "success": false,
    "message": "Access denied. No authorization token provided.",
    "error": null
  }
  ```

---

## Unverified Endpoints

All endpoints below are **NOT VERIFIED** because we lack valid credentials to bypass the 401 Unauthorized barrier.

### Authentication
* POST /api/auth/logout
* POST /api/auth/refresh-token
* POST /api/auth/forgot-password
* POST /api/auth/reset-password

### Staff APIs
* GET /api/staff/dashboard
* GET /api/staff/profile
* PUT /api/staff/profile
* POST /api/staff/attendance/check-in
* POST /api/staff/attendance/check-out
* GET /api/staff/attendance
* POST /api/staff/attendance/:attendanceId/breaks/start with `breakType` equal to `tea_break_1`, `lunch`, or `tea_break_2` (backend implementation unverified)
* POST /api/staff/attendance/:attendanceId/breaks/end with the same `breakType` (backend implementation unverified)
* POST /api/staff/leaves
* GET /api/staff/leaves
* GET /api/staff/leaves/:id
* DELETE /api/staff/leaves/:id

### HR APIs
* GET /api/hr/dashboard
* GET /api/hr/employees
* POST /api/hr/employees
* GET /api/hr/employees/:id
* PUT /api/hr/employees/:id
* DELETE /api/hr/employees/:id
