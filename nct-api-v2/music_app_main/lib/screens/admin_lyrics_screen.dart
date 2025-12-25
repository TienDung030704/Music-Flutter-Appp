import 'package:flutter/material.dart';
import '../services/lyrics_service.dart';
import '../services/auth_service.dart';
import '../helpers/notification_helper.dart';

class AdminLyricsScreen extends StatefulWidget {
  const AdminLyricsScreen({super.key});

  @override
  State<AdminLyricsScreen> createState() => _AdminLyricsScreenState();
}

class _AdminLyricsScreenState extends State<AdminLyricsScreen> {
  List<Map<String, dynamic>> _lyricsList = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadLyrics();
  }

  Future<void> _checkAuthAndLoadLyrics() async {
    // Check if user is logged in and has admin privileges
    final isLoggedIn = await AuthService.isLoggedIn();

    if (!isLoggedIn) {
      if (mounted) {
        NotificationHelper.showError(
          'Vui lòng đăng nhập để truy cập trang quản lý lyrics',
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Get current user to check admin role
    final user = await AuthService.getCurrentUser();
    if (user == null || user.role != 'admin') {
      if (mounted) {
        NotificationHelper.showError(
          'Bạn không có quyền truy cập trang quản lý lyrics',
        );
        Navigator.of(context).pop();
      }
      return;
    }

    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    final result = await LyricsService.getAllLyrics(page: _currentPage);

    if (result.success && result.data != null) {
      final lyricsList =
          (result.data!['lyrics'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        if (_currentPage == 1) {
          _lyricsList = lyricsList;
        } else {
          _lyricsList.addAll(lyricsList);
        }
        _hasMore = lyricsList.length >= 10;
        _currentPage++;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      NotificationHelper.showError(
        result.error ?? 'Không thể tải danh sách lyrics',
      );
    }
  }

  void _refreshLyrics() {
    setState(() {
      _lyricsList.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadLyrics();
  }

  Future<void> _deleteLyrics(String songId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa lời bài hát này?'),
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
      final result = await LyricsService.deleteLyrics(songId);
      if (result.success) {
        NotificationHelper.showSuccess('Đã xóa lời bài hát');
        _refreshLyrics();
      } else {
        NotificationHelper.showError(result.error ?? 'Xóa thất bại');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lyrics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshLyrics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search và filter sẽ thêm sau
          Expanded(
            child: _isLoading && _lyricsList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _lyricsList.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có lyrics nào\nNhấn + để thêm mới',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _refreshLyrics(),
                    child: ListView.builder(
                      itemCount: _lyricsList.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _lyricsList.length) {
                          if (_isLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _loadLyrics();
                            });
                            return const SizedBox();
                          }
                        }

                        final song = _lyricsList[index];
                        final hasSyncLyrics = song['has_sync_lyrics'] == 1;
                        final hasLyrics = song['has_lyrics'] == 1;
                        final imageUrl = song['image_url'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasLyrics
                                      ? (hasSyncLyrics
                                            ? Colors.green
                                            : Colors.orange)
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: Icon(
                                                  Icons.music_note,
                                                  color: Colors.grey[600],
                                                ),
                                              );
                                            },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: Icon(
                                          hasLyrics
                                              ? (hasSyncLyrics
                                                    ? Icons.sync
                                                    : Icons.text_fields)
                                              : Icons.music_note,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              song['song_title'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nghệ sĩ: ${song['artist_name'] ?? 'Unknown'}',
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasLyrics
                                        ? (hasSyncLyrics
                                              ? Colors.green
                                              : Colors.orange)
                                        : Colors.grey,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasLyrics
                                        ? (hasSyncLyrics
                                              ? 'Có đồng bộ'
                                              : 'Chỉ có lời')
                                        : 'Chưa có lời',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text(
                                        'Xóa',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _showAddLyricsDialog(existingLyrics: song);
                                    break;
                                  case 'delete':
                                    _deleteLyrics(song['song_id'].toString());
                                    break;
                                }
                              },
                            ),
                            onTap: () =>
                                _showAddLyricsDialog(existingLyrics: song),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLyricsDialog(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLyricsDialog({
    Map<String, dynamic>? songData,
    Map<String, dynamic>? existingLyrics,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddLyricsDialog(
        songData: songData,
        existingLyrics: existingLyrics,
        onSaved: _refreshLyrics,
      ),
    );
  }
}

class AddLyricsDialog extends StatefulWidget {
  final Map<String, dynamic>? songData;
  final Map<String, dynamic>? existingLyrics;
  final VoidCallback onSaved;

  const AddLyricsDialog({
    super.key,
    this.songData,
    this.existingLyrics,
    required this.onSaved,
  });

  @override
  State<AddLyricsDialog> createState() => _AddLyricsDialogState();
}

class _AddLyricsDialogState extends State<AddLyricsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _songIdController = TextEditingController();
  final _songTitleController = TextEditingController();
  final _artistController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _startTimeController = TextEditingController(text: '15'); // Default 15s

  @override
  void initState() {
    super.initState();

    // Use songData as primary source, fallback to existingLyrics
    final song = widget.songData ?? widget.existingLyrics;

    if (song != null) {
      _songIdController.text = song['song_id']?.toString() ?? '';
      _songTitleController.text = song['song_title'] ?? '';
      _artistController.text = song['artist_name'] ?? '';

      // Load existing lyrics if available
      if (widget.existingLyrics != null) {
        _loadExistingLyrics(song['song_id']?.toString() ?? '');
      }
    }
  }

  void _loadExistingLyrics(String songId) async {
    final result = await LyricsService.getLyrics(songId);
    if (result.success && result.data != null && mounted) {
      setState(() {
        _lyricsController.text = result.data!.lyricsContent ?? '';
        _startTimeController.text = result.data!.startTime?.toString() ?? '15';
      });
    }
  }

  void _saveLyrics() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await LyricsService.saveLyrics(
      songId: _songIdController.text,
      songTitle: _songTitleController.text,
      artistName: _artistController.text.isNotEmpty
          ? _artistController.text
          : null,
      lyricsContent: _lyricsController.text.isNotEmpty
          ? _lyricsController.text
          : null,
      syncLyrics: [], // Không sử dụng sync lyrics phức tạp nữa
      startTime: int.tryParse(_startTimeController.text) ?? 15,
    );

    if (result.success) {
      if (mounted) {
        Navigator.pop(context);
        NotificationHelper.showSuccess('Đã lưu lời bài hát');
        widget.onSaved();
      }
    } else {
      NotificationHelper.showError(result.error ?? 'Lưu thất bại');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingLyrics != null
            ? 'Chỉnh sửa lời bài hát'
            : 'Thêm lời bài hát',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _songIdController,
                decoration: const InputDecoration(
                  labelText: 'Song ID *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Vui lòng nhập Song ID' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _songTitleController,
                decoration: const InputDecoration(
                  labelText: 'Tên bài hát *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Vui lòng nhập tên bài hát' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Tên nghệ sĩ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lyricsController,
                decoration: const InputDecoration(
                  labelText: 'Lời bài hát',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startTimeController,
                decoration: const InputDecoration(
                  labelText: 'Thời gian bắt đầu (giây)',
                  helperText: 'Lyrics bắt đầu hiển thị ở giây thứ bao nhiêu',
                  border: OutlineInputBorder(),
                  suffixText: 's',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _saveLyrics, child: const Text('Lưu')),
      ],
    );
  }
}
