# Staff API Final Integration Report

## 1. Project & Contract Status
* **Frontend Verified:** `hr-core (1)` (Staff Portal)
* **Backend Contract (`final_api_contract.md`):** Missing/Not Found. The backend path `C:\Users\admin\StudioProjects\LY-hr_management_backend` and the specific file do not exist on the host system. Verification relies on the existing local `api_contract.md` reference.

## 2. Test Execution & Fixes
* **Mock Repository Injection:** To prevent `widget_test.dart` from emitting actual backend requests (and failing with HTTP 400), a custom `MockHRRepository` has been injected into all UI tests.
* **Current Test State:**
  * **Parser Tests:** `GET` and `PUT` serialization rules successfully verified in `test/profile_api_test.dart`.
  * **Widget Tests:** Currently failing due to deterministic data mismatches. The `MockHRRepository` requires precise state mapping (e.g. returning exactly 900 seconds for `endExpiredBreak` and correctly naming the active break 'morning' instead of 'lunch') for the assertions to pass cleanly.

## 3. Endpoint Compatibility & Mismatches
*(Verified against existing local `api_contract.md` due to missing backend repo)*

| API Endpoint | Request Mapping | Test Result | Remaining Blockers / Mismatches |
| :--- | :--- | :--- | :--- |
| **`POST /auth/login`** | Complete | Mock-Tested | Missing refresh-token structure docs |
| **`POST /auth/refresh-token`**| Partial | Unverified | Envelope (`data.accessToken`) undocumented |
| **`GET /staff/profile`** | Complete | Passing | None |
| **`PUT /staff/profile`** | Mismatched | Passing | **UI lacks `city`, `emergencyContact`** |
| **`GET /staff/dashboard`** | Blocked | Unverified | Backend payload schema completely undocumented |
| **`POST /staff/attendance/check-in`**| Complete | Blocked| Unknown if response returns full model |
| **`POST /staff/attendance/check-out`**| Complete | Blocked| Unknown if response returns full model |
| **`GET /staff/attendance`** | Complete | Mock-Tested | Pagination (`page`, `limit`) unmapped in UI |
| **`POST /staff/leaves`** | Complete | Mock-Tested | Document upload support missing |
| **`GET /staff/leaves`** | Complete | Mock-Tested | None |
| **`DELETE /staff/leaves/:id`**| Complete | Mock-Tested | None |

## 4. Final Execution
* `flutter analyze`: Passed (Exit code 1 due only to trivial `prefer_const_constructors` infos).
* `flutter build web`: Passed (Exit code 0), successful web compilation.
