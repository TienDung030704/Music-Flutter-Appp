import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../helpers/notification_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  NotificationPagination? _notificationPagination;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await NotificationService.getNotifications(page: 1);

      if (result.success && result.data != null) {
        setState(() {
          _notificationPagination = NotificationPagination.fromJson(
            result.data!,
          );
          _currentPage = 1;
        });
      } else {
        NotificationHelper.showError(result.error ?? 'Không thể tải thông báo');
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore ||
        _notificationPagination == null ||
        !_notificationPagination!.hasMorePages) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await NotificationService.getNotifications(page: nextPage);

      if (result.success && result.data != null) {
        final newPagination = NotificationPagination.fromJson(result.data!);

        setState(() {
          _notificationPagination = NotificationPagination(
            notifications: [
              ..._notificationPagination!.notifications,
              ...newPagination.notifications,
            ],
            currentPage: newPagination.currentPage,
            totalPages: newPagination.totalPages,
            totalItems: newPagination.totalItems,
            perPage: newPagination.perPage,
          );
          _currentPage = nextPage;
        });
      } else {
        NotificationHelper.showError(
          result.error ?? 'Không thể tải thêm thông báo',
        );
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    final result = await NotificationService.markAsRead(notification.id);
    if (result.success) {
      setState(() {
        final index = _notificationPagination!.notifications.indexWhere(
          (n) => n.id == notification.id,
        );
        if (index != -1) {
          _notificationPagination!.notifications[index] = NotificationModel(
            id: notification.id,
            senderId: notification.senderId,
            receiverId: notification.receiverId,
            receiverType: notification.receiverType,
            notificationType: notification.notificationType,
            title: notification.title,
            message: notification.message,
            relatedData: notification.relatedData,
            isRead: true,
            createdAt: notification.createdAt,
            updatedAt: notification.updatedAt,
            senderName: notification.senderName,
            senderAvatar: notification.senderAvatar,
          );
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final result = await NotificationService.markAllAsRead();
    if (result.success) {
      setState(() {
        if (_notificationPagination != null) {
          _notificationPagination = NotificationPagination(
            notifications: _notificationPagination!.notifications.map((
              notification,
            ) {
              return NotificationModel(
                id: notification.id,
                senderId: notification.senderId,
                receiverId: notification.receiverId,
                receiverType: notification.receiverType,
                notificationType: notification.notificationType,
                title: notification.title,
                message: notification.message,
                relatedData: notification.relatedData,
                isRead: true,
                createdAt: notification.createdAt,
                updatedAt: notification.updatedAt,
                senderName: notification.senderName,
                senderAvatar: notification.senderAvatar,
              );
            }).toList(),
            currentPage: _notificationPagination!.currentPage,
            totalPages: _notificationPagination!.totalPages,
            totalItems: _notificationPagination!.totalItems,
            perPage: _notificationPagination!.perPage,
          );
        }
      });

      Fluttertoast.showToast(
        msg: 'Đã đánh dấu tất cả thông báo là đã đọc',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      NotificationHelper.showError(
        result.error ?? 'Không thể đánh dấu thông báo',
      );
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'comment':
        return Colors.blue;
      case 'listening':
        return Colors.green;
      case 'download':
        return Colors.orange;
      case 'new_song':
        return Colors.purple;
      case 'new_user':
        return Colors.cyan;
      case 'system':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'comment':
        return Icons.comment;
      case 'listening':
        return Icons.music_note;
      case 'download':
        return Icons.download;
      case 'new_song':
        return Icons.library_music;
      case 'new_user':
        return Icons.person_add;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final color = _getNotificationColor(notification.notificationType);
    final icon = _getNotificationIcon(notification.notificationType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: notification.isRead
            ? AppTheme.surface
            : AppTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12.0),
        border: notification.isRead
            ? null
            : Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (notification.senderName != null)
                  Text(
                    'Từ: ${notification.senderName}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  notification.getTimeAgo(),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _markAsRead(notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_notificationPagination != null &&
              _notificationPagination!.notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Đánh dấu tất cả đã đọc',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_notificationPagination == null ||
        _notificationPagination!.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có thông báo nào',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Các thông báo mới sẽ xuất hiện tại đây',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppTheme.accent,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount:
            _notificationPagination!.notifications.length +
            (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notificationPagination!.notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            );
          }

          final notification = _notificationPagination!.notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }
}
