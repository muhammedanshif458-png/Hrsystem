import 'package:flutter/material.dart';
import 'staff_screens.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor:Colors.transparent,
        elevation: 0,
        
        title: const Text(
          "PROFILE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [

        // PROFILE HEADER
        Center(
        child: Column(
        children: [
        CircleAvatar(
        radius: 50,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(
        Icons.person,
        size: 55,
        color: Colors.black,
        ),
        ),

        const SizedBox(height: 15),

        const Text(
        "User Name",
        style: TextStyle(
        color: Colors.white,
        fontSize: 23,
        fontWeight: FontWeight.bold,
        ),
        ),

        const SizedBox(height: 5),

        const Text(
        "user@email.com",
        style: TextStyle(
        color: Colors.grey,
        fontSize: 14,
        ),
        ),

        const SizedBox(height: 20),

        // EDIT PROFILE BUTTON
        SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
        onPressed: () {
        Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) =>
        const EditProfilePage(),
        ),
        );
        },
        style: OutlinedButton.styleFrom(
        side: const BorderSide(
        color: Color(0xFFD4AF37),
        ),
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        ),
        ),
        child: const Text(
        "EDIT PROFILE",
        style: TextStyle(
        color: Color(0xFFD4AF37),
        fontWeight: FontWeight.bold,
        ),
        ),
        ),
        ),
        ],
        ),
        ),

        const SizedBox(height: 30),

        // QUICK ACCESS
        const Text(
        "QUICK ACCESS",
        style: TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        ),
        ),

        const SizedBox(height: 12),

        _quickAccessTile(
        context,
        Icons.event_available_outlined,
        "Attendance",
        "View attendance history",
        const EditProfilePage(),
        ),

        _quickAccessTile(
        context,
        Icons.beach_access_outlined,
        "Leave",
        "Manage leave requests",
        const ChangePasswordPage(),
        ),

        _quickAccessTile(
        context,
        Icons.chat_bubble_outline,
        "Chat",
        "Open team chat",
        const PrivacyPolicyPage(),
        ),

        const SizedBox(height: 25),

        // PERSONAL INFORMATION
        const Text(
        "PERSONAL INFORMATION",
        style: TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        ),
        ),

        const SizedBox(height: 12),

        _profileItem(
        Icons.person_outline,
        "User Name",
        "User Name",
        ),

        _profileItem(
        Icons.email_outlined,
        "Email",
        "user@email.com",
        ),

        _profileItem(
        Icons.location_on_outlined,
        "Address",
        "Your Address",
        ),

        _profileItem(
        Icons.phone_outlined,
        "Phone Number",
        "+91 XXXXX XXXXX",
        ),

        const SizedBox(height: 25),

        // ACCOUNT & SECURITY
        const Text(
        "ACCOUNT & SECURITY",
        style: TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        ),
        ),

        const SizedBox(height: 12),

        _menuItem(
        context,
        Icons.lock_outline,
        "Change Password",
        "Update your account password",
        const ChangePasswordPage(),
        ),

        const SizedBox(height: 25),

        // HELP & INFORMATION
        const Text(
        "HELP & INFORMATION",
        style: TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        ),
        ),

        const SizedBox(height: 12),

        _menuItem(
        context,
        Icons.privacy_tip_outlined,
        "Privacy & Policy",
        "Manage your data & privacy",
        const StaffPrivacyPolicyPage(isStandalone: true),
        ),

        _menuItem(
        context,
        Icons.description_outlined,
        "Terms & Conditions",
        "View company policies",
        const StaffTermsConditionsPage(isStandalone: true),
        ),

        _menuItem(
        context,
        Icons.help_outline,
        "Support & Helpdesk",
        "Raise a support ticket",
        const StaffSupportHelpdeskPage(isStandalone: true),
        ),

        const SizedBox(height: 30),

        // LOGOUT
        SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
        onPressed: () {
        // Keep your existing Firebase logout code here.
        },
        icon: const Icon(Icons.logout),
        label: const Text("LOGOUT"),
        style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        ),
        ),
        ),
        ),

        const SizedBox(height: 30),
        ],
        ),
        ),
        );
        }

        // PROFILE INFORMATION ITEM
        static Widget _profileItem(
        IconData icon,
        String title,
        String value,
        ) {
        return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
        color: Colors.white.withOpacity(0.08),
        ),
        ),
        child: Row(
        children: [
        Icon(
        icon,
        color: const Color(0xFFD4AF37),
        size: 23,
        ),

        const SizedBox(width: 15),

        Expanded(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
        title,
        style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        ),
        ),

        const SizedBox(height: 4),

        Text(
        value,
        style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        ),
        ),
        ],
        ),
        ),
        ],
        ),
        );
        }

        static Widget _quickAccessTile(
        BuildContext context,
        IconData icon,
        String title,
        String subtitle,
        Widget destination,
        ) {
        return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
        color: Colors.white.withOpacity(0.08),
        ),
        ),
        child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: const Color(0xFFD4AF37)),
        title: Text(
        title,
        style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        ),
        ),
        subtitle: Text(
        subtitle,
        style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: () {
        Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
        );
        },
        ),
        ),
        );
        }

        // MENU ITEM
        static Widget _menuItem(
        BuildContext context,
        IconData icon,
        String title,
        String subtitle,
        Widget page,
        ) {
        return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
        color: Colors.white.withOpacity(0.08),
        ),
        ),
        child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
        ),

        leading: Icon(
        icon,
        color: const Color(0xFFD4AF37),
        ),

        title: Text(
        title,
        style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        ),
        ),

        subtitle: Text(
        subtitle,
        style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        ),
        ),

        trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey,
        size: 16,
        ),

        onTap: () {
        Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) => page,
        ),
        );
        },
        ),
        ),
        );
        }
        }


// =====================================================
// EDIT PROFILE PAGE
// =====================================================

        class EditProfilePage extends StatelessWidget {
        const EditProfilePage({super.key});

        @override
        Widget build(BuildContext context) {
        return _simplePage(
        context,
        "EDIT PROFILE",
        [
        _textField("User Name"),
        _textField("Email"),
        _textField("Address"),
        _textField("Phone Number"),

        const SizedBox(height: 20),

        _button("SAVE CHANGES"),
        ],
        );
        }
        }


// =====================================================
// CHANGE PASSWORD PAGE
// =====================================================

        class ChangePasswordPage extends StatelessWidget {
        const ChangePasswordPage({super.key});

        @override
        Widget build(BuildContext context) {
        return _simplePage(
        context,
        "CHANGE PASSWORD",
        [
        _textField("Current Password", password: true),
        _textField("New Password", password: true),
        _textField("Confirm New Password", password: true),

        const SizedBox(height: 20),

        _button("CHANGE PASSWORD"),
        ],
        );
        }
        }


// =====================================================
// PRIVACY POLICY PAGE
// =====================================================

        class PrivacyPolicyPage extends StatelessWidget {
        const PrivacyPolicyPage({super.key});

        @override
        Widget build(BuildContext context) {
        return const StaffPrivacyPolicyPage(isStandalone: true);
        }
        }


// =====================================================
// TERMS & CONDITIONS PAGE
// =====================================================

        class TermsPage extends StatelessWidget {
        const TermsPage({super.key});

        @override
        Widget build(BuildContext context) {
        return const StaffTermsConditionsPage(isStandalone: true);
        }
        }


// =====================================================
// FAQ / SUPPORT PAGE
// =====================================================

        class FAQPage extends StatelessWidget {
        const FAQPage({super.key});

        @override
        Widget build(BuildContext context) {
        return const StaffSupportHelpdeskPage(isStandalone: true);
        }
        }


// =====================================================
// COMMON SIMPLE PAGE
// =====================================================

          Widget _simplePage(
          BuildContext context,
          String title,
          List<Widget> children,
        ) {
      return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
      title,
      style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      ),
      ),
      iconTheme: const IconThemeData(
      color: Colors.white,
      ),
      ),

      body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
      children: children,
      ),
      ),
      );
      }


// =====================================================
// TEXT FIELD
// =====================================================

          Widget _textField(
          String hint, {
        bool password = false,
      }) {
    return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
    obscureText: password,

    style: const TextStyle(
    color: Colors.white,
    ),

    decoration: InputDecoration(
    labelText: hint,
    labelStyle: const TextStyle(
    color: Colors.grey,
    ),

    prefixIcon: Icon(
    password
    ? Icons.lock_outline
        : Icons.person_outline,
    color: const Color(0xFFD4AF37),
    ),

    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(
    color: Colors.white.withOpacity(0.15),
    ),
    ),

    focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(
    Radius.circular(15),
    ),
    borderSide: BorderSide(
    color: Color(0xFFD4AF37),
    ),
    ),
    ),
    ),
    );
    }


// =====================================================
// BUTTON
// =====================================================

        Widget _button(String text) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            // Save / Firebase logic will be added here.
          },

          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),

          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

