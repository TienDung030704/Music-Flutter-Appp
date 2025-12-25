import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';

class CommentBottomSheet extends StatefulWidget {
  final String songType;
  final String songId;
  final String songTitle;
  final String artistName;

  const CommentBottomSheet({
    Key? key,
    required this.songType,
    required this.songId,
    required this.songTitle,
    required this.artistName,
  }) : super(key: key);

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CommentsPagination? _commentsPagination;
  bool _isLoading = false;
  bool _isAddingComment = false;
  bool _isLoadingMore = false;
  String? _editingCommentId;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreComments();
    }
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) _commentsPagination = null;
    });

    final result = await _commentService.getCommentsBySong(
      songType: widget.songType,
      songId: widget.songId,
      page: reset ? 1 : (_commentsPagination?.currentPage ?? 0) + 1,
      limit: 10,
    );

    if (result['success']) {
      setState(() {
        if (reset || _commentsPagination == null) {
          _commentsPagination = result['data'];
        } else {
          // Append new comments
          final newData = result['data'] as CommentsPagination;
          _commentsPagination = CommentsPagination(
            comments: [..._commentsPagination!.comments, ...newData.comments],
            currentPage: newData.currentPage,
            totalPages: newData.totalPages,
            totalComments: newData.totalComments,
            perPage: newData.perPage,
          );
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể tải bình luận',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore ||
        _commentsPagination == null ||
        !_commentsPagination!.hasNextPage)
      return;

    setState(() {
      _isLoadingMore = true;
    });

    final result = await _commentService.getCommentsBySong(
      songType: widget.songType,
      songId: widget.songId,
      page: _commentsPagination!.currentPage + 1,
      limit: 10,
    );

    if (result['success']) {
      final newData = result['data'] as CommentsPagination;
      setState(() {
        _commentsPagination = CommentsPagination(
          comments: [..._commentsPagination!.comments, ...newData.comments],
          currentPage: newData.currentPage,
          totalPages: newData.totalPages,
          totalComments: newData.totalComments,
          perPage: newData.perPage,
        );
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isAddingComment = true;
    });

    final result = await _commentService.addComment(
      songType: widget.songType,
      songId: widget.songId,
      songTitle: widget.songTitle,
      artistName: widget.artistName,
      commentText: _commentController.text.trim(),
    );

    setState(() {
      _isAddingComment = false;
    });

    if (result['success']) {
      _commentController.clear();
      _loadComments(reset: true); // Reload comments
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Đã thêm bình luận thành công!',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } else {
      if (mounted) {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể thêm bình luận',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _updateComment(int commentId) async {
    if (_commentController.text.trim().isEmpty) return;

    final result = await _commentService.updateComment(
      commentId: commentId,
      commentText: _commentController.text.trim(),
    );

    if (result['success']) {
      _commentController.clear();
      setState(() {
        _editingCommentId = null;
      });
      _loadComments(reset: true);
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Đã cập nhật bình luận!',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } else {
      if (mounted) {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể cập nhật bình luận',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final result = await _commentService.deleteComment(commentId);

    if (result['success']) {
      _loadComments(reset: true);
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Đã xóa bình luận!',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    } else {
      if (mounted) {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Không thể xóa bình luận',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _showCommentOptions(Comment comment) {
    if (!comment.canEdit(_currentUserId)) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Chỉnh sửa'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _editingCommentId = comment.id.toString();
                _commentController.text = comment.commentText;
              });
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Xóa', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(comment.id);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bình luận'),
        content: Text('Bạn có chắc chắn muốn xóa bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId);
            },
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bình luận',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),

          // Song info
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.music_note, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.songTitle,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.artistName,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: _isLoading && _commentsPagination == null
                ? Center(child: CircularProgressIndicator())
                : _commentsPagination == null ||
                      _commentsPagination!.comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có bình luận nào\nHãy là người đầu tiên bình luận!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _commentsPagination!.comments.length +
                        (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _commentsPagination!.comments.length) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final comment = _commentsPagination!.comments[index];
                      final canEdit = comment.canEdit(_currentUserId);

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        comment.getRelativeTime(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canEdit)
                                  IconButton(
                                    onPressed: () =>
                                        _showCommentOptions(comment),
                                    icon: Icon(Icons.more_vert, size: 16),
                                  ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(comment.commentText),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _editingCommentId != null
                          ? 'Chỉnh sửa bình luận...'
                          : 'Viết bình luận...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    maxLength: 500,
                  ),
                ),
                SizedBox(width: 8),
                _isAddingComment
                    ? CircularProgressIndicator()
                    : IconButton(
                        onPressed: _editingCommentId != null
                            ? () =>
                                  _updateComment(int.parse(_editingCommentId!))
                            : _addComment,
                        icon: Icon(
                          _editingCommentId != null ? Icons.check : Icons.send,
                          color: Colors.blue,
                        ),
                      ),
                if (_editingCommentId != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _editingCommentId = null;
                        _commentController.clear();
                      });
                    },
                    icon: Icon(Icons.close),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
