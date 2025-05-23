import 'package:airplan/report_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:airplan/user_page.dart';
import 'services/websocket_service.dart';
import 'services/auth_service.dart';
import 'package:airplan/filtros_admin_content.dart';

class AdminPage extends StatefulWidget {
  final WebSocketService? webSocketService;
  final AuthService? authService;

  const AdminPage({super.key, this.webSocketService, this.authService});

  @override
  AdminPageState createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  late final WebSocketService _webSocketService;
  late final AuthService _authService;

  static final List<String> _appBarTitles = [
    'admin_profile_title'.tr(),
    'Reports'.tr(),
    'content_filters_title'.tr(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _webSocketService = widget.webSocketService ?? WebSocketService();
    _authService = widget.authService ?? AuthService();
  }

  @override
  Widget build(BuildContext context) {
    if (!_webSocketService.isConnected) {
      _webSocketService.connect();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          UserProfileContent(
            authService: _authService,
            webSocketService: _webSocketService,
          ),
          AdminReportsPanel(),
          const FiltrosAdminContent(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'profile_tab_label'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.admin_panel_settings),
            label: 'Reports'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.filter_list),
            label: 'filters_tab_label'.tr(),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class UserProfileContent extends StatelessWidget {
  final AuthService? authService;
  final WebSocketService? webSocketService;

  const UserProfileContent({
    super.key,
    this.authService,
    this.webSocketService,
  });

  @override
  Widget build(BuildContext context) {
    return UserPage(
      isEmbedded: true,
      authService: authService,
      webSocketService: webSocketService,
    );
  }
}

class AdminReportsPanel extends StatefulWidget {
  const AdminReportsPanel({super.key});

  @override
  _AdminReportsPanelState createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<AdminReportsPanel> {
  late Future<List<Report>> _reportsFuture;
  final ReportService _reportService = ReportService();

  @override
  void initState() {
    super.initState();
    _reportsFuture = _reportService.fetchReports();
  }

  void _handleDeleteReport(Report report) async {
    try {
      await _reportService.deleteReport(report);
      setState(() {
        _reportsFuture = _reportService.fetchReports();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_deleting_report'))),
      );
    }
  }

  void _handleBlockUser(Report report) async {
    try {
      await _reportService.blockUser(report.reportingUser, report.reportedUser);
      if (!mounted) return;
      _handleDeleteReport(report); // Eliminar el reporte después de bloquear al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_blocked_successfully'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_blocking_user'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text(tr('error_loading_reports')));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(tr('no_reports_found')));
        }

        final reports = snapshot.data!;
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text('${tr('Usuario Reportado')}: ${report.reportedUser}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tr('Usuario Reportador')}: ${report.reportingUser}'),
                    Text('${tr('Motivo')}: ${report.reason}'),
                    Text('${tr('Fecha')}: ${DateFormat('dd/MM/yy HH:mm:ss').format(report.date.toLocal())}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.red),
                      onPressed: () => _handleBlockUser(report),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () => _handleDeleteReport(report),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}