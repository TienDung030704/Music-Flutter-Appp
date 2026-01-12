import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../helpers/notification_helper.dart';

// Widget màn hình cài đặt của ứng dụng
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Biến lưu trạng thái chế độ tối/sáng
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Màu nền thay đổi theo chế độ tối/sáng
      backgroundColor: _isDarkMode ? AppTheme.darkBackground : Colors.grey[50],
      // Thanh tiêu đề với nút quay lại
      appBar: AppBar(
        backgroundColor: _isDarkMode
            ? AppTheme.darkBackground
            : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thiết lập',
          style: TextStyle(
            color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Nội dung chính có thể cuộn
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),

            // Danh sách các mục cài đặt chính
            // Mục trình phát nhạc
            _buildSettingItem(
              icon: Icons.play_arrow,
              title: 'Trình phát nhạc',
              onTap: () => _showComingSoon('Trình phát nhạc'),
            ),

            // Mục chọn giao diện với nhãn "MỚI"
            _buildSettingItem(
              icon: Icons.palette_outlined,
              title: 'Giao diện chủ đề',
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'MỚI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => _showThemeDialog(),
            ),

            // Mục tải nhạc
            _buildSettingItem(
              icon: Icons.download_outlined,
              title: 'Tải nhạc',
              onTap: () => _showComingSoon('Tải nhạc'),
            ),

            // Mục thư viện
            _buildSettingItem(
              icon: Icons.video_library_outlined,
              title: 'Thư viện',
onTap: () => _showComingSoon('Thư viện'),
            ),

            // Mục video
            _buildSettingItem(
              icon: Icons.play_circle_outline,
              title: 'Video',
              onTap: () => _showComingSoon('Video'),
            ),

            // Mục tai nghe và bluetooth
            _buildSettingItem(
              icon: Icons.headphones,
              title: 'Tai nghe và Bluetooth',
              onTap: () => _showComingSoon('Tai nghe và Bluetooth'),
            ),

            // Mục thông báo
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              title: 'Thông báo',
              onTap: () => _showComingSoon('Thông báo'),
            ),

            SizedBox(height: 20),

            // Nhóm cài đặt thông tin và hỗ trợ
            // Mục kiểm tra phiên bản với số phiên bản hiện tại
            _buildSettingItem(
              icon: Icons.info_outline,
              title: 'Kiểm tra phiên bản mới',
              trailing: Text(
                '25.11',
                style: TextStyle(
                  color: _isDarkMode
                      ? AppTheme.darkTextSecondary
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              onTap: () => _showComingSoon('Kiểm tra phiên bản mới'),
            ),

            // Mục trợ giúp và báo lỗi
            _buildSettingItem(
              icon: Icons.help_outline,
              title: 'Trợ giúp và báo lỗi',
              onTap: () => _showComingSoon('Trợ giúp và báo lỗi'),
            ),

            // Mục bình chọn ứng dụng
            _buildSettingItem(
              icon: Icons.star_outline,
              title: 'Bình chọn cho Zing MP3',
              onTap: () => _showComingSoon('Bình chọn cho Zing MP3'),
            ),

            // Mục điều khoản sử dụng
            _buildSettingItem(
              icon: Icons.description_outlined,
              title: 'Điều khoản sử dụng',
              onTap: () => _showComingSoon('Điều khoản sử dụng'),
            ),

            // Mục chính sách bảo mật
            _buildSettingItem(
              icon: Icons.security,
              title: 'Chính sách bảo mật',
              onTap: () => _showComingSoon('Chính sách bảo mật'),
            ),

            // Mục cuối cùng - thông tin về ứng dụng
            _buildSettingItem(
              icon: Icons.info,
              title: 'Thông tin về Zing MP3',
              onTap: () => _showAboutDialog(),
              isLast: true,
            ),
            SizedBox(height: 20), // Khoảng cách phía dưới
          ],
        ),
      ),
    );
  }

  // Widget tạo một mục cài đặt với icon, tiêu đề và hành động
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              // Thêm đường viền dưới nếu không phải mục cuối
              border: !isLast
                  ? Border(
                      bottom: BorderSide(
                        color: _isDarkMode ? Colors.white10 : Colors.grey[200]!,
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Icon của mục cài đặt
                Icon(
                  icon,
                  color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  size: 24,
                ),
                SizedBox(width: 16),
                // Tiêu đề mục cài đặt
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _isDarkMode
                          ? AppTheme.darkTextPrimary
                          : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                // Widget phụ (nếu có) như nhãn "MỚI" hoặc số phiên bản
                if (trailing != null) ...[trailing, SizedBox(width: 8)],
                // Mũi tên chỉ sang phải
                Icon(
                  Icons.chevron_right,
                  color: _isDarkMode
                      ? AppTheme.darkTextSecondary
                      : Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hiển thị dialog chọn giao diện sáng/tối
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Chọn giao diện',
          style: TextStyle(
            color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tùy chọn giao diện sáng
            _buildThemeOption('Sáng', !_isDarkMode, () {
              setState(() => _isDarkMode = false);
              Navigator.pop(context);
              _showThemeChangeMessage('Đã chuyển sang giao diện sáng');
            }),
            // Tùy chọn giao diện tối
            _buildThemeOption('Tối', _isDarkMode, () {
setState(() => _isDarkMode = true);
              Navigator.pop(context);
              _showThemeChangeMessage('Đã chuyển sang giao diện tối');
            }),
          ],
        ),
      ),
    );
  }

  // Widget tạo tùy chọn giao diện với radio button
  Widget _buildThemeOption(String title, bool isSelected, VoidCallback onTap) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
        ),
      ),
      leading: Radio<bool>(
        value: isSelected,
        groupValue: true,
        onChanged: (value) => onTap(),
        activeColor: AppTheme.accent,
      ),
      onTap: onTap,
    );
  }

  // Hiển thị thông báo khi thay đổi giao diện
  void _showThemeChangeMessage(String message) {
    NotificationHelper.showCustom(message, AppTheme.accent);
  }

  // Hiển thị thông báo tính năng đang phát triển
  void _showComingSoon(String feature) {
    NotificationHelper.showInfo('Tính năng "$feature" đang phát triển');
  }

  // Hiển thị dialog thông tin về ứng dụng
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'KDT Music - Zing MP3',
          style: TextStyle(
            color: _isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị phiên bản ứng dụng
            Text(
              'Phiên bản: 25.11',
              style: TextStyle(
                color: _isDarkMode
                    ? AppTheme.darkTextSecondary
                    : Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            // Mô tả ứng dụng
            Text(
              'Ứng dụng nghe nhạc trực tuyến',
              style: TextStyle(
                color: _isDarkMode
                    ? AppTheme.darkTextSecondary
                    : Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            // Thông tin bản quyền
            Text(
              '© 2025 KDT Music',
              style: TextStyle(
                color: _isDarkMode
                    ? AppTheme.darkTextSecondary
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          // Nút đóng dialog
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}
