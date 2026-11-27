// ─── lib/api_list.dart ──────────────────────────────────────────────────────
// "API List" page for the Staff app: every backend API this app calls,
// grouped by category, with the live base URL at the top.
// Open it at <site>/#/api-list
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/api_config.dart';

class ApiEndpoint {
  const ApiEndpoint(this.method, this.path, this.description, {this.onBackend = true});

  final String method;
  final String path;
  final String description;

  /// false when the dashboard has code for it but the backend has no such route.
  final bool onBackend;
}

class ApiCategory {
  const ApiCategory(this.name, this.icon, this.endpoints);

  final String name;
  final IconData icon;
  final List<ApiEndpoint> endpoints;
}

/// Every API the Staff app calls (from lib/config/api_config.dart + lib/hr_repository.dart).
const List<ApiCategory> staffApiCategories = [
  ApiCategory('Authentication', Icons.lock_outline, [
    ApiEndpoint('POST', '/api/auth/login', 'Staff login (email, password, work mode)'),
  ]),
  ApiCategory('Profile', Icons.person_outline, [
    ApiEndpoint('GET', '/api/staff/profile', 'My profile'),
    ApiEndpoint('PUT', '/api/staff/profile', 'Update my profile'),
    ApiEndpoint('GET', '/api/birthdays/today', "Today's birthdays"),
  ]),
  ApiCategory('Attendance', Icons.access_time, [
    ApiEndpoint('POST', '/api/staff/attendance/check-in', 'Check in'),
    ApiEndpoint('POST', '/api/staff/attendance/check-out', 'Check out'),
    ApiEndpoint('POST', '/api/staff/attendance/:attendanceId/breaks/start', 'Start break'),
    ApiEndpoint('POST', '/api/staff/attendance/:attendanceId/breaks/end', 'End break'),
    ApiEndpoint('GET', '/api/staff/attendance', 'My attendance history'),
    ApiEndpoint('GET', '/api/staff/attendance/:attendanceId', 'Attendance details'),
    ApiEndpoint('DELETE', '/api/staff/attendance/history', 'Clear my history (hidden only, kept in DB)'),
    ApiEndpoint('POST', '/api/staff/attendance/clear-history', 'Clear my history (fallback)'),
  ]),
  ApiCategory('Leaves', Icons.event_busy_outlined, [
    ApiEndpoint('GET', '/api/staff/leaves', 'My leave requests'),
    ApiEndpoint('POST', '/api/staff/leaves', 'Apply leave (with optional attachment)'),
    ApiEndpoint('DELETE', '/api/staff/leaves/:id', 'Cancel leave'),
    ApiEndpoint('GET', '/api/staff/documents/:id/download', 'Download leave / medical document'),
  ]),
  ApiCategory('Daily Updates', Icons.edit_note, [
    ApiEndpoint('GET', '/api/staff/daily-updates', 'My daily updates'),
    ApiEndpoint('POST', '/api/staff/daily-updates', 'Submit daily update'),
  ]),
  ApiCategory('Department Chat', Icons.forum_outlined, [
    ApiEndpoint('GET', '/api/staff/departments/:deptKey/messages', 'Department messages'),
    ApiEndpoint('GET', '/api/staff/departments/:deptKey/messages/search', 'Search messages'),
    ApiEndpoint('POST', '/api/staff/departments/:deptKey/messages', 'Send message'),
    ApiEndpoint('POST', '/api/staff/departments/:deptKey/messages/clear', 'Clear chat'),
    ApiEndpoint('PATCH', '/api/staff/departments/:deptKey/messages/:messageId/delete-for-me', 'Delete for me'),
    ApiEndpoint('DELETE', '/api/staff/departments/:deptKey/messages/:messageId', 'Delete for everyone'),
  ]),
];

class ApiListPage extends StatefulWidget {
  const ApiListPage({super.key});

  static const String routeName = '/api-list';

  @override
  State<ApiListPage> createState() => _ApiListPageState();
}

class _ApiListPageState extends State<ApiListPage> {
  String _query = '';

  String get _baseUrl => ApiConfig.socketUrl;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied: $text'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final categories = staffApiCategories
        .map((c) => ApiCategory(
              c.name,
              c.icon,
              c.endpoints
                  .where((e) =>
                      q.isEmpty ||
                      e.path.toLowerCase().contains(q) ||
                      e.method.toLowerCase().contains(q) ||
                      e.description.toLowerCase().contains(q) ||
                      c.name.toLowerCase().contains(q))
                  .toList(),
            ))
        .where((c) => c.endpoints.isNotEmpty)
        .toList();
    final total = staffApiCategories.fold<int>(0, (n, c) => n + c.endpoints.length);

    return Scaffold(
      appBar: AppBar(title: const Text('API List — Staff App')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BaseUrlCard(baseUrl: _baseUrl, total: total, onCopy: _copy),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search API (path, method, description)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          for (final c in categories)
            _CategoryCard(category: c, baseUrl: _baseUrl, onCopy: _copy, expanded: q.isNotEmpty),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No API matches your search.')),
            ),
        ],
      ),
    );
  }
}

class _BaseUrlCard extends StatelessWidget {
  const _BaseUrlCard({required this.baseUrl, required this.total, required this.onCopy});

  final String baseUrl;
  final int total;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base URL', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    baseUrl,
                    style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy base URL',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => onCopy(baseUrl),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$total APIs • full URL = Base URL + path • tap an API to copy its full URL',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.baseUrl,
    required this.onCopy,
    required this.expanded,
  });

  final ApiCategory category;
  final String baseUrl;
  final ValueChanged<String> onCopy;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('${category.name}-$expanded'),
        initiallyExpanded: expanded,
        leading: Icon(category.icon),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Chip(label: Text('${category.endpoints.length}'), visualDensity: VisualDensity.compact),
        children: [
          for (final e in category.endpoints) _EndpointTile(endpoint: e, baseUrl: baseUrl, onCopy: onCopy),
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({required this.endpoint, required this.baseUrl, required this.onCopy});

  final ApiEndpoint endpoint;
  final String baseUrl;
  final ValueChanged<String> onCopy;

  static const Map<String, Color> _methodColors = {
    'GET': Color(0xff16a34a),
    'POST': Color(0xff2563eb),
    'PUT': Color(0xffd97706),
    'PATCH': Color(0xff7c3aed),
    'DELETE': Color(0xffdc2626),
  };

  @override
  Widget build(BuildContext context) {
    final color = _methodColors[endpoint.method] ?? Colors.grey;
    return ListTile(
      dense: true,
      onTap: () => onCopy('$baseUrl${endpoint.path}'),
      leading: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(
          endpoint.method,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      title: Text(endpoint.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      subtitle: Text(endpoint.description),
      trailing: endpoint.onBackend
          ? const Icon(Icons.copy, size: 16)
          : const Tooltip(
              message: 'The app has code for this, but the backend has no such route',
              child: Chip(
                label: Text('Not on backend', style: TextStyle(fontSize: 11)),
                backgroundColor: Color(0xfffff7ed),
                visualDensity: VisualDensity.compact,
              ),
            ),
    );
  }
}
