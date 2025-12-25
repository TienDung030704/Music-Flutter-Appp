import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/admin_service.dart';
import '../widgets/admin_comments_management.dart';
import '../widgets/admin_play_statistics.dart';
import 'admin_lyrics_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  final Map<String, String> _categories = const {
    'Tuyệt Phẩm Bolero': 'bolero Quang Lê Cẩm Ly',
    'V-Pop Thịnh Hành': 'vpop hits',
    'Nhạc Trẻ Remix': 'vinahouse remix',
  };

  final Map<String, List<Song>> _categorySongs = {};
  bool _loading = false;

  // User management state
  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = false;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length + 5,
      vsync: this,
    ); // +5 for overview, users, lyrics, comments, and play stats
    _loadAllCategories();
    _loadUserStats();
    _loadUsers(); // Auto-load users on startup
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCategories() async {
    setState(() => _loading = true);

    for (String category in _categories.keys) {
      try {
        // Load từ iTunes API
        final query = _categories[category]!;
        final iTunesSongs = await _apiService.searchSongs(query);

        // Load từ admin database
        final adminResponse = await AdminService.getAdminSongs(
          category: category,
        );
        final adminSongs = adminResponse.success
            ? adminResponse.data!
            : <Song>[];

        // Merge cả 2 danh sách (admin songs trước để ưu tiên hiển thị)
        // Duplicate filtering is disabled for now

        // Temporarily disable filtering to test iTunes API
        final filteredITunesSongs = iTunesSongs; // No filtering for now
        /*
        final filteredITunesSongs = iTunesSongs
            .where(
              (song) {
                bool duplicateId = adminIds.contains(song.id);
                bool duplicateTitle = adminTitles.contains(song.title.toLowerCase().trim());
                if (duplicateId || duplicateTitle) {
                  // Skip duplicate song
                }
                return !duplicateId && !duplicateTitle;
              },
            )
            .toList();
        */

        final allSongs = <Song>[...adminSongs, ...filteredITunesSongs];

        _categorySongs[category] = allSongs;
      } catch (e) {
        print('ERROR loading $category: $e');
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);

    final response = await AdminService.getUsers();
    if (response.success) {
      setState(() {
        _users = List<Map<String, dynamic>>.from(response.data!['users']);
      });
    } else {
      Fluttertoast.showToast(
        msg: response.error ?? 'Lỗi tải danh sách người dùng',
      );
    }

    setState(() => _usersLoading = false);
  }

  Future<void> _loadUserStats() async {
    final response = await AdminService.getUserStats();
    if (response.success) {
      setState(() {
        _userStats = response.data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Admin'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Tổng quan'),
            const Tab(text: 'Quản lý người dùng'),
            const Tab(text: 'Quản lý lời bài hát'),
            const Tab(text: 'Quản lý bình luận'),
            const Tab(text: 'Thống kê lượt nghe'),
            ..._categories.keys.map((category) => Tab(text: category)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          const AdminLyricsScreen(),
          _buildCommentsTab(),
          const AdminPlayStatistics(),
          ..._categories.keys.map((category) => _buildCategoryTab(category)),
        ],
      ),
      floatingActionButton:
          _tabController.index >=
              5 // Only show for song category tabs (now index 5+)
          ? FloatingActionButton(
              onPressed: _showAddSongDialog,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê Admin Panel',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Stats Cards
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // Music stats
                // Music stats
                _buildStatCard(
                  'Tổng bài hát',
                  _getTotalSongs().toString(),
                  Icons.music_note,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Thể loại',
                  _categories.length.toString(),
                  Icons.category,
                  Colors.green,
                ),

                // User stats
                if (_userStats != null) ...[
                  _buildStatCard(
                    'Người dùng',
                    _userStats!['totalUsers'].toString(),
                    Icons.people,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Đang hoạt động',
                    _userStats!['activeUsers'].toString(),
                    Icons.verified_user,
                    Colors.teal,
                  ),
                ] else ...[
                  _buildStatCard(
                    'Người dùng',
                    '...',
                    Icons.people,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Đang hoạt động',
                    '...',
                    Icons.verified_user,
                    Colors.teal,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: Column(
        children: [
          // Header with add button
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quản lý người dùng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () => _showAddUserDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Thêm người dùng'),
                ),
              ],
            ),
          ),
          // Users list
          Expanded(
            child: _usersLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có người dùng nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUsers,
                          child: const Text('Tải danh sách'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return _buildUserTile(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['avatar'] != null
              ? NetworkImage(user['avatar'])
              : null,
          backgroundColor: Colors.deepPurple.shade100,
          child: user['avatar'] == null
              ? Text(
                  user['fullName'][0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(user['fullName']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user['role'] == 'admin'
                        ? Colors.purple
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user['role'].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (user['isVerified'])
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: user['isActive'] ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  user['isActive'] ? 'Hoạt động' : 'Bị khóa',
                  style: TextStyle(
                    fontSize: 12,
                    color: user['isActive'] ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Sửa'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_status',
              child: Row(
                children: [
                  Icon(
                    user['isActive'] ? Icons.lock : Icons.lock_open,
                    size: 18,
                    color: user['isActive'] ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user['isActive'] ? 'Khóa' : 'Mở khóa',
                    style: TextStyle(
                      color: user['isActive'] ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (user['role'] != 'admin')
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'toggle_status':
        _toggleUserStatus(user);
        break;
      case 'delete':
        _showDeleteUserConfirmDialog(user);
        break;
    }
  }

  Widget _buildCategoryTab(String category) {
    final songs = _categorySongs[category] ?? [];

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Category Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$category (${songs.length} bài)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _refreshCategory(category),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),

        // Songs List
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _buildSongTile(song, category);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongTile(Song song, String category) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.artwork ?? '',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 50,
              height: 50,
              color: Colors.grey.shade300,
              child: const Icon(Icons.music_note),
            ),
          ),
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          song.artists,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleSongAction(value, song, category),
          itemBuilder: (context) {
            // Check if this is an admin song (has numeric ID) or iTunes song (has non-numeric ID)
            final isAdminSong = int.tryParse(song.id) != null;

            return [
              if (isAdminSong) // Only show edit for admin songs
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Sửa'),
                    ],
                  ),
                ),
              if (isAdminSong) // Only show delete for admin songs
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              if (!isAdminSong) // Show info for iTunes songs
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Từ iTunes', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
            ];
          },
        ),
      ),
    );
  }

  void _handleSongAction(String action, Song song, String category) {
    switch (action) {
      case 'edit':
        _showEditSongDialog(song, category);
        break;
      case 'delete':
        _showDeleteConfirmDialog(song, category);
        break;
      case 'info':
        Fluttertoast.showToast(
          msg: "🎵 Bài hát từ iTunes API - Không thể chỉnh sửa",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        break;
    }
  }

  void _showAddSongDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddSongDialog(
        categories: _categories.keys.toList(),
        onSongAdded: (category) => _refreshCategory(category),
      ),
    );
  }

  void _showEditSongDialog(Song song, String category) {
    showDialog(
      context: context,
      builder: (context) => _EditSongDialog(
        song: song,
        category: category,
        categories: _categories.keys.toList(),
        onSongUpdated: (category) => _refreshCategory(category),
      ),
    );
  }

  void _showDeleteConfirmDialog(Song song, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa bài "${song.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSong(song, category);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCategory(String category) async {
    try {
      // Load từ iTunes API
      final query = _categories[category]!;
      final iTunesSongs = await _apiService.searchSongs(query);

      // Load từ admin database
      final adminResponse = await AdminService.getAdminSongs(
        category: category,
      );
      final adminSongs = adminResponse.success ? adminResponse.data! : <Song>[];

      // Merge cả 2 danh sách (admin songs trước để ưu tiên hiển thị)
      // Tránh duplicate và protect admin songs
      final adminIds = adminSongs.map((s) => s.id).toSet();
      final adminTitles = adminSongs
          .map((s) => s.title.toLowerCase().trim())
          .toSet();

      final filteredITunesSongs = iTunesSongs
          .where(
            (song) =>
                !adminIds.contains(song.id) &&
                !adminTitles.contains(song.title.toLowerCase().trim()),
          )
          .toList();

      final allSongs = <Song>[...adminSongs, ...filteredITunesSongs];

      setState(() {
        _categorySongs[category] = allSongs;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải lại: $e')));
    }
  }

  Future<void> _deleteSong(Song song, String category) async {
    try {
      final response = await AdminService.deleteSong(song.id);

      if (response.success) {
        // Remove song from current list immediately
        setState(() {
          _categorySongs[category]?.removeWhere((s) => s.id == song.id);
        });

        Fluttertoast.showToast(
          msg: "🗑️ Đã xóa \"${song.title}\" thành công!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: "❌ Lỗi xóa: ${response.error}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Lỗi xóa: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // ==================== USER MANAGEMENT METHODS ====================

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(
        onUserAdded: () {
          _loadUsers();
          _loadUserStats();
        },
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        onUserUpdated: () {
          _loadUsers();
          _loadUserStats();
        },
      ),
    );
  }

  void _showDeleteUserConfirmDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa người dùng "${user['fullName']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(user);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    try {
      final response = await AdminService.toggleUserStatus(user['id']);

      if (response.success) {
        _loadUsers();
        _loadUserStats();

        final statusText = response.data!['isActive'] ? 'kích hoạt' : 'khóa';
        Fluttertoast.showToast(
          msg: "✅ Đã $statusText tài khoản \"${user['fullName']}\"",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: "❌ Lỗi: ${response.error}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Lỗi kết nối: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    try {
      final response = await AdminService.deleteUser(user['id']);

      if (response.success) {
        _loadUsers();
        _loadUserStats();

        Fluttertoast.showToast(
          msg: "✅ Đã xóa người dùng \"${user['fullName']}\"",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: "❌ Lỗi: ${response.error}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Lỗi kết nối: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  int _getTotalSongs() {
    return _categorySongs.values.fold(
      0,
      (total, songs) => total + songs.length,
    );
  }

  Widget _buildCommentsTab() {
    return const AdminCommentsManagement();
  }
}

// Add Song Dialog
class _AddSongDialog extends StatefulWidget {
  final List<String> categories;
  final Function(String) onSongAdded;

  const _AddSongDialog({required this.categories, required this.onSongAdded});

  @override
  State<_AddSongDialog> createState() => _AddSongDialogState();
}

class _AddSongDialogState extends State<_AddSongDialog> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _thumbnailController = TextEditingController();
  String? _selectedCategory;
  final _fileUrlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm bài hát mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên bài hát'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Ca sĩ'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _thumbnailController,
              decoration: const InputDecoration(labelText: 'URL ảnh'),
            ),
            const SizedBox(height: 16),
            // URL input for audio file
            TextField(
              controller: _fileUrlController,
              decoration: const InputDecoration(
                labelText: 'URL file nhạc (mp3, wav, etc.)',
                hintText: 'https://example.com/song.mp3',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Thể loại'),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _addSong, child: const Text('Thêm')),
      ],
    );
  }

  Future<void> _addSong() async {
    if (_titleController.text.isNotEmpty &&
        _artistController.text.isNotEmpty &&
        _selectedCategory != null &&
        _fileUrlController.text.isNotEmpty) {
      try {
        final response = await AdminService.addSongWithUrl(
          title: _titleController.text,
          artist: _artistController.text,
          thumbnail: _thumbnailController.text,
          category: _selectedCategory!,
          audioUrl: _fileUrlController.text,
        );

        if (response.success) {
          // Gọi callback để refresh parent với bài hát mới
          widget.onSongAdded(_selectedCategory!);
          Navigator.pop(context);

          Fluttertoast.showToast(
            msg: "✅ Đã thêm \"${_titleController.text}\" thành công!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Lỗi: ${response.error}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "❌ Lỗi upload: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: "⚠️ Vui lòng điền đầy đủ thông tin và nhập URL file nhạc",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
}

// Edit Song Dialog
class _EditSongDialog extends StatefulWidget {
  final Song song;
  final String category;
  final List<String> categories;
  final Function(String) onSongUpdated;

  const _EditSongDialog({
    required this.song,
    required this.category,
    required this.categories,
    required this.onSongUpdated,
  });

  @override
  State<_EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends State<_EditSongDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _thumbnailController;
  late TextEditingController _streamUrlController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artists);
    _thumbnailController = TextEditingController(
      text: widget.song.artwork ?? '',
    );
    _streamUrlController = TextEditingController(
      text: widget.song.streamUrl ?? '',
    );
    _selectedCategory = widget.category;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa bài hát'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên bài hát'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Ca sĩ'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _thumbnailController,
              decoration: const InputDecoration(labelText: 'URL ảnh'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _streamUrlController,
              decoration: const InputDecoration(labelText: 'URL nhạc'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Thể loại'),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _updateSong, child: const Text('Cập nhật')),
      ],
    );
  }

  Future<void> _updateSong() async {
    if (_titleController.text.isNotEmpty && _artistController.text.isNotEmpty) {
      try {
        final response = await AdminService.updateSong(
          songId: widget.song.id,
          title: _titleController.text,
          artist: _artistController.text,
          thumbnail: _thumbnailController.text,
          category: _selectedCategory,
          streamUrl: _streamUrlController.text,
        );

        if (response.success) {
          widget.onSongUpdated(_selectedCategory);
          Navigator.pop(context);

          Fluttertoast.showToast(
            msg: "✅ Đã cập nhật \"${_titleController.text}\" thành công!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Lỗi: ${response.error}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "❌ Lỗi kết nối: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }
}

// ==================== USER DIALOGS ====================

class _AddUserDialog extends StatefulWidget {
  final VoidCallback onUserAdded;

  const _AddUserDialog({required this.onUserAdded});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();

  String _selectedRole = 'user';
  String _selectedGender = 'male';
  bool _isActive = true;
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người dùng mới'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Họ và tên *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Vui lòng nhập email';
                  if (!value!.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mật khẩu *'),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Vui lòng nhập mật khẩu';
                  if (value!.length < 6) return 'Mật khẩu phải ít nhất 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avatarController,
                decoration: const InputDecoration(labelText: 'URL avatar'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Nam')),
                  DropdownMenuItem(value: 'female', child: Text('Nữ')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value!),
                  ),
                  const Text('Tài khoản hoạt động'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isVerified,
                    onChanged: (value) => setState(() => _isVerified = value!),
                  ),
                  const Text('Đã xác thực'),
                ],
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
        ElevatedButton(onPressed: _createUser, child: const Text('Tạo')),
      ],
    );
  }

  Future<void> _createUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await AdminService.createUser(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _selectedRole,
          avatar: _avatarController.text.isNotEmpty
              ? _avatarController.text
              : null,
          phone: _phoneController.text.isNotEmpty
              ? _phoneController.text
              : null,
          gender: _selectedGender,
          isActive: _isActive,
          isVerified: _isVerified,
        );

        if (response.success) {
          widget.onUserAdded();
          Navigator.pop(context);

          Fluttertoast.showToast(
            msg:
                "✅ Đã tạo người dùng \"${_fullNameController.text}\" thành công!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Lỗi: ${response.error}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "❌ Lỗi kết nối: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }
}

class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUserUpdated;

  const _EditUserDialog({required this.user, required this.onUserUpdated});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;

  late String _selectedRole;
  late String _selectedGender;
  late bool _isActive;
  late bool _isVerified;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user['fullName']);
    _emailController = TextEditingController(text: widget.user['email']);
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _avatarController = TextEditingController(
      text: widget.user['avatar'] ?? '',
    );
    _selectedRole = widget.user['role'] ?? 'user';
    _selectedGender = widget.user['gender'] ?? 'male';
    _isActive = widget.user['isActive'] ?? true;
    _isVerified = widget.user['isVerified'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa thông tin người dùng'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Họ và tên *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Vui lòng nhập email';
                  if (!value!.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (để trống nếu không đổi)',
                ),
                obscureText: true,
                validator: (value) {
                  if (value?.isNotEmpty == true && value!.length < 6) {
                    return 'Mật khẩu phải ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avatarController,
                decoration: const InputDecoration(labelText: 'URL avatar'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Nam')),
                  DropdownMenuItem(value: 'female', child: Text('Nữ')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value!),
                  ),
                  const Text('Tài khoản hoạt động'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isVerified,
                    onChanged: (value) => setState(() => _isVerified = value!),
                  ),
                  const Text('Đã xác thực'),
                ],
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
        ElevatedButton(onPressed: _updateUser, child: const Text('Cập nhật')),
      ],
    );
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await AdminService.updateUser(
          userId: widget.user['id'],
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
          role: _selectedRole,
          avatar: _avatarController.text.isNotEmpty
              ? _avatarController.text
              : null,
          phone: _phoneController.text.isNotEmpty
              ? _phoneController.text
              : null,
          gender: _selectedGender,
          isActive: _isActive,
          isVerified: _isVerified,
        );

        if (response.success) {
          widget.onUserUpdated();
          Navigator.pop(context);

          Fluttertoast.showToast(
            msg:
                "✅ Đã cập nhật người dùng \"${_fullNameController.text}\" thành công!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Lỗi: ${response.error}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "❌ Lỗi kết nối: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }
}
