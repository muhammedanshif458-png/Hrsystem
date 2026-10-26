# Staff API Contract

## Authentication
### Login
* **Method & Path:** `POST /auth/login`
* **Authentication:** None
* **Query Parameters:** None
* **Request Body:**
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```
* **Success Response:** Missing exact schema (Returns standard Envelope with `accessToken`).
* **Error Response:** 401 Unauthorized / 422 Validation Failed
* **Status:** Implemented and Verified in code.

---

## Staff Profile

### Fetch Profile
* **Method & Path:** `GET /staff/profile`
* **Authentication:** Required (Bearer Token)
* **Request Body:** None
* **Expected Success Response:**
  ```json
  {
    "success": true,
    "data": {
      "employeeId": "EMP1005",
      "firstName": "Mark",
      "department": "Sales",
      "phoneNumber": "1234567890",
      "address": "123 Street"
    }
  }
  ```
* **Status:** Connected and parsed correctly.

### Update Profile
* **Method & Path:** `PUT /staff/profile`
* **Authentication:** Required (Bearer Token)
* **Request Body:**
  ```json
  {
    "phone": "0987654321",
    "address": "456 New Ave"
  }
  ```
* **Status:** Connected and parsed correctly.

---

## Staff Attendance

### Fetch Attendance
* **Method & Path:** `GET /staff/attendance`
* **Authentication:** Required
* **Request Body:** None
* **Expected Success Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "_id": "att123",
        "date": "2026-10-09",
        "checkInTime": "09:00 AM",
        "checkOutTime": "05:00 PM",
        "workingHours": "8h 0m",
        "isLate": false
      }
    ]
  }
  ```
* **Status:** Connected and parsed correctly.

### Check-in
* **Method & Path:** `POST /staff/attendance/check-in`
* **Authentication:** Required
* **Request Body:** `{}`
* **Expected Success Response:**
  ```json
  {
    "success": true,
    "data": {
      "checkInTime": "09:05 AM"
    }
  }
  ```
* **Status:** Connected and parsed correctly.

### Check-out
* **Method & Path:** `POST /staff/attendance/check-out`
* **Authentication:** Required
* **Request Body:** `{}`
* **Expected Success Response:**
  ```json
  {
    "success": true,
    "data": {
      "workingHours": "7.5"
    }
  }
  ```
* **Status:** Connected and parsed correctly.

---

## Staff Leaves

### Fetch Leaves
* **Method & Path:** `GET /staff/leaves`
* **Authentication:** Required
* **Request Body:** None
* **Expected Success Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "_id": "lv123",
        "leaveType": "SICK",
        "startDate": "2026-10-10",
        "endDate": "2026-10-11",
        "reason": "Feeling unwell",
        "status": "pending",
        "createdAt": "2026-10-08T10:00:00Z"
      }
    ]
  }
  ```
* **Status:** Connected and parsed correctly.

### Request Leave
* **Method & Path:** `POST /staff/leaves`
* **Authentication:** Required
* **Request Body:**
  ```json
  {
    "leaveType": "SICK",
    "startDate": "2026-10-10",
    "endDate": "2026-10-11",
    "reason": "Feeling unwell"
  }
  ```
* **Status:** Connected and parsed correctly.

### Delete/Cancel Leave
* **Method & Path:** `DELETE /staff/leaves/:id`
* **Authentication:** Required
* **Request Body:** None
* **Status:** Connected and parsed correctly.
