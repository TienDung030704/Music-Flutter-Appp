import 'package:flutter/material.dart';
import '../widgets/admin_comments_management.dart';

class SimpleAdminCommentsScreen extends StatelessWidget {
  const SimpleAdminCommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Bình luận'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const AdminCommentsManagement(),
    );
  }
}
