package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.data.repository.HRRepositoryImpl
import com.example.ui.components.AddStaffModal
import com.example.ui.components.AssignTaskModal
import com.example.ui.components.FirestoreRulesDialog
import com.example.ui.components.ForgotPasswordDialog
import com.example.ui.screens.HRDashboardScreen
import com.example.ui.screens.LoginScreen
import com.example.ui.screens.StaffPortalScreen
import com.example.ui.screens.StaffProfileScreen
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.viewmodel.HRViewModel
import com.example.ui.viewmodel.Screen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val repository = HRRepositoryImpl(applicationContext)

        setContent {
            val hrViewModel = remember { HRViewModel(repository) }
            val currentScreen by hrViewModel.currentScreen.collectAsState()
            val toastMessage by hrViewModel.toastMessage.collectAsState()
            val snackbarHostState = remember { SnackbarHostState() }

            LaunchedEffect(toastMessage) {
                toastMessage?.let {
                    snackbarHostState.showSnackbar(it)
                    hrViewModel.clearToast()
                }
            }

            MyApplicationTheme {
                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    snackbarHost = { SnackbarHost(snackbarHostState) }
                ) { innerPadding ->
                    Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
                        when (val screen = currentScreen) {
                            is Screen.Login -> LoginScreen(viewModel = hrViewModel)
                            is Screen.StaffPortal -> StaffPortalScreen(viewModel = hrViewModel)
                            is Screen.HRDashboard -> HRDashboardScreen(viewModel = hrViewModel)
                            is Screen.StaffProfile -> StaffProfileScreen(
                                staffId = screen.staffId,
                                viewModel = hrViewModel
                            )
                        }

                        // Add Staff Modal
                        val isAddStaffOpen by hrViewModel.isAddStaffModalOpen.collectAsState()
                        if (isAddStaffOpen) {
                            AddStaffModal(
                                onDismiss = { hrViewModel.isAddStaffModalOpen.value = false },
                                onSave = { name, email, department, role, joinDate ->
                                    hrViewModel.addStaff(name, email, department, role, joinDate)
                                }
                            )
                        }

                        // Assign Task Modal
                        val isAssignTaskOpen by hrViewModel.isAssignTaskModalOpen.collectAsState()
                        val staffList by hrViewModel.staffList.collectAsState()
                        val preselectedStaffId by hrViewModel.assignTaskPreselectedStaffId.collectAsState()
                        if (isAssignTaskOpen) {
                            AssignTaskModal(
                                staffList = staffList,
                                preselectedStaffId = preselectedStaffId,
                                onDismiss = {
                                    hrViewModel.isAssignTaskModalOpen.value = false
                                    hrViewModel.assignTaskPreselectedStaffId.value = null
                                },
                                onSave = { staffId, department, description, dueDate ->
                                    hrViewModel.assignTask(staffId, department, description, dueDate)
                                }
                            )
                        }

                        // Forgot Password Dialog
                        val isForgotPassOpen by hrViewModel.isForgotPasswordOpen.collectAsState()
                        if (isForgotPassOpen) {
                            ForgotPasswordDialog(
                                onDismiss = { hrViewModel.isForgotPasswordOpen.value = false },
                                onSubmit = { email ->
                                    hrViewModel.sendPasswordReset(email)
                                }
                            )
                        }

                        // Firestore Rules Dialog
                        val isRulesOpen by hrViewModel.isFirestoreRulesOpen.collectAsState()
                        if (isRulesOpen) {
                            FirestoreRulesDialog(
                                onDismiss = { hrViewModel.isFirestoreRulesOpen.value = false }
                            )
                        }
                    }
                }
            }
        }
    }
}
