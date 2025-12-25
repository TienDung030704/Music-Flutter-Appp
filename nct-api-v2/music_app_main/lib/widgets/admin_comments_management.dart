import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/admin_comments_service.dart';
import '../models/admin_comment_models.dart';

class AdminCommentsManagement extends StatefulWidget {
  const AdminCommentsManagement({super.key});

  @override
  State<AdminCommentsManagement> createState() =>
      _AdminCommentsManagementState();
}

class _AdminCommentsManagementState extends State<AdminCommentsManagement> {
  final AdminCommentsService _adminCommentsService = AdminCommentsService();

  AdminCommentsPagination? _commentsPagination;
  AdminCommentStats? _commentStats;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadStats();
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await _adminCommentsService.getAdminComments(
        page: reset ? 1 : (_commentsPagination?.currentPage ?? 0) + 1,
        limit: 20,
        status: _selectedStatus,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      print('AdminCommentsManagement: Load result: $result');

      if (result['success']) {
        final newPagination = AdminCommentsPagination.fromJson(result['data']);
        setState(() {
          if (reset || _commentsPagination == null) {
            _commentsPagination = newPagination;
          } else {
            // Append new comments
            _commentsPagination = AdminCommentsPagination(
              comments: [
                ..._commentsPagination!.comments,
                ...newPagination.comments,
              ],
              currentPage: newPagination.currentPage,
              totalPages: newPagination.totalPages,
              totalComments: newPagination.totalComments,
              perPage: newPagination.perPage,
            );
          }
        });
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể tải bình luận',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      print('AdminCommentsManagement: Exception loading comments: $e');
      Fluttertoast.showToast(
        msg: 'Lỗi tải dữ liệu: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final result = await _adminCommentsService.getCommentStats();

      if (result['success']) {
        setState(() {
          _commentStats = AdminCommentStats.fromJson(result['data']);
        });
      }
    } catch (e) {
      print('AdminCommentsManagement: Error loading stats: $e');
    }
  }

  Future<void> _deleteComment(AdminCommentItem comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa bình luận: "${comment.commentText}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _adminCommentsService.deleteComment(comment.id);

      if (result['success']) {
        Fluttertoast.showToast(msg: 'Đã xóa bình luận');
        _loadComments(reset: true);
        _loadStats();
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể xóa bình luận',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _restoreComment(AdminCommentItem comment) async {
    final result = await _adminCommentsService.restoreComment(comment.id);

    if (result['success']) {
      Fluttertoast.showToast(msg: 'Đã khôi phục bình luận');
      _loadComments(reset: true);
      _loadStats();
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? 'Không thể khôi phục bình luận',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          if (_commentStats != null) _buildStatsCards(),

          const SizedBox(height: 20),

          // Filters
          _buildFilters(),

          const SizedBox(height: 16),

          // Comments list
          Expanded(child: _buildCommentsList()),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.comment, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${_commentStats!.totalComments}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Tổng bình luận'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${_commentStats!.activeComments}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Đang hiển thị'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.hide_source, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${_commentStats!.inactiveComments}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Đã ẩn'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicWidth(
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm bình luận',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _searchQuery = value;
                },
                onSubmitted: (value) {
                  _loadComments(reset: true);
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tất cả')),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Đang hiển thị'),
                  ),
                  DropdownMenuItem(value: 'inactive', child: Text('Đã ẩn')),
                ],
                onChanged: (value) {
                  _selectedStatus = value;
                  _loadComments(reset: true);
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _loadComments(reset: true),
              child: const Text('Tìm kiếm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading && _commentsPagination == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_commentsPagination == null || _commentsPagination!.comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Không có bình luận nào', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount:
          _commentsPagination!.comments.length +
          (_commentsPagination!.hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _commentsPagination!.comments.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _loadComments(),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Tải thêm'),
            ),
          );
        }

        final comment = _commentsPagination!.comments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: comment.avatar != null
                          ? NetworkImage(comment.avatar!)
                          : null,
                      child: comment.avatar == null
                          ? Text(comment.fullName[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${comment.songTitle} - ${comment.artistName}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(comment.isActive ? 'Hiển thị' : 'Đã ẩn'),
                      backgroundColor: comment.isActive
                          ? Colors.green[100]
                          : Colors.red[100],
                      labelStyle: TextStyle(
                        color: comment.isActive
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Comment text
                Text(comment.commentText),
                const SizedBox(height: 8),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.getRelativeTime(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Row(
                      children: [
                        if (comment.isActive)
                          TextButton.icon(
                            onPressed: () => _deleteComment(comment),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Ẩn'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () => _restoreComment(comment),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Khôi phục'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
