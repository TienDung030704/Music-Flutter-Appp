import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../helpers/notification_helper.dart';

class UserProfileScreen extends StatefulWidget {
  final User? currentUser;

  const UserProfileScreen({super.key, required this.currentUser});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _loadUserProfile(); // Load fresh data from server
  }

  // Load user profile from server
  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.getUserProfileFromServer();

      if (result.success && result.data != null) {
        setState(() {
          _currentUser = result.data!;
        });
      } else {
        print('Failed to load profile: ${result.error}');
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Hồ sơ người dùng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              _buildUserInfoSection(),
              const SizedBox(height: 30),

              // Security Section
              _buildSecuritySection(),
              const SizedBox(height: 30),

              // Account Actions
              _buildAccountActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thông tin cá nhân',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Sửa'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar and Basic Info
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.pink.shade100,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.pink.shade300,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.fullName ?? 'Chưa cập nhật',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser?.email ?? 'Chưa cập nhật',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _currentUser?.role == 'admin'
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (_currentUser?.role ?? 'user').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _currentUser?.role == 'admin'
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Additional Info
            _buildInfoRow(
              'Số điện thoại',
              _currentUser?.phone ?? 'Chưa cập nhật',
            ),
            _buildInfoRow(
              'Giới tính',
              _mapGenderToVietnamese(_currentUser?.gender ?? 'Chưa cập nhật'),
            ),
            _buildInfoRow(
              'Ngày sinh',
              _currentUser?.dateOfBirth ?? 'Chưa cập nhật',
            ),
            _buildInfoRow(
              'Trạng thái',
              _currentUser?.isActive == true ? 'Hoạt động' : 'Bị khóa',
            ),
          ],
        ),
      ),
    );
  }

  String _mapGenderToVietnamese(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bảo mật',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Change Password
            ListTile(
              leading: Icon(Icons.lock, color: Colors.orange),
              title: const Text('Đổi mật khẩu'),
              subtitle: const Text('Thay đổi mật khẩu đăng nhập'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePasswordDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động tài khoản',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Logout
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất'),
              subtitle: const Text('Đăng xuất khỏi tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Password
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureCurrentPassword = !obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // New Password
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _handleChangePassword(
                      currentPasswordController.text,
                      newPasswordController.text,
                      confirmPasswordController.text,
                    ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    // Validate inputs
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      NotificationHelper.showError('Vui lòng điền đầy đủ thông tin');
      return;
    }

    if (newPassword.length < 6) {
      NotificationHelper.showError('Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }

    if (newPassword != confirmPassword) {
      NotificationHelper.showError('Xác nhận mật khẩu không khớp');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        Navigator.pop(context); // Close dialog
        NotificationHelper.showSuccess('Đổi mật khẩu thành công!');
      } else {
        NotificationHelper.showError(result.message ?? 'Đổi mật khẩu thất bại');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              await AuthService.logout();
              NotificationHelper.showInfo('Đã đăng xuất thành công');

              // Navigate to login screen and clear all routes to prevent navigation issues
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final fullNameController = TextEditingController(
      text: _currentUser?.fullName ?? '',
    );
    final phoneController = TextEditingController(
      text: _currentUser?.phone ?? '',
    );

    // Use English values for database
    String selectedGender = _currentUser?.gender ?? 'male';

    DateTime? selectedDateOfBirth = _currentUser?.dateOfBirth != null
        ? DateTime.tryParse(_currentUser!.dateOfBirth!)
        : null;

    showDialog(
      context: context,
      builder: (context) {
        // Ensure dialogGender has valid value that matches dropdown items
        String dialogGender = selectedGender;
        if (!['male', 'female', 'other'].contains(dialogGender)) {
          dialogGender = 'male'; // Fallback to default
        }
        DateTime? dialogDate = selectedDateOfBirth;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Sửa thông tin cá nhân'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Name
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Gender
                  DropdownButtonFormField<String>(
                    value: dialogGender,
                    decoration: const InputDecoration(
                      labelText: 'Giới tính',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Nam')),
                      DropdownMenuItem(value: 'female', child: Text('Nữ')),
                      DropdownMenuItem(value: 'other', child: Text('Khác')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        dialogGender = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dialogDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          dialogDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ngày sinh',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        dialogDate != null
                            ? '${dialogDate!.day}/${dialogDate!.month}/${dialogDate!.year}'
                            : 'Chọn ngày sinh',
                        style: TextStyle(
                          color: dialogDate != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _handleUpdateProfile(
                        fullNameController.text,
                        phoneController.text,
                        dialogGender,
                        dialogDate,
                      ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cập nhật'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleUpdateProfile(
    String fullName,
    String phone,
    String gender,
    DateTime? dateOfBirth,
  ) async {
    // Validate inputs
    if (fullName.trim().isEmpty) {
      NotificationHelper.showError('Họ và tên không được để trống');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profileData = <String, dynamic>{
        'full_name': fullName.trim(),
        'gender': gender,
      };

      if (phone.trim().isNotEmpty) {
        profileData['phone'] = phone.trim();
      }

      if (dateOfBirth != null) {
        profileData['date_of_birth'] = dateOfBirth.toIso8601String().split(
          'T',
        )[0]; // Format: YYYY-MM-DD
      }

      final result = await AuthService.updateProfile(profileData);

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        // Update current user data and reload from server
        setState(() {
          _currentUser = result.data;
        });

        // Reload fresh data from server to ensure consistency
        await _loadUserProfile();

        Navigator.pop(context); // Close dialog
        NotificationHelper.showSuccess('Cập nhật thông tin thành công!');
      } else {
        NotificationHelper.showError(result.error ?? 'Cập nhật thất bại');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }
}
