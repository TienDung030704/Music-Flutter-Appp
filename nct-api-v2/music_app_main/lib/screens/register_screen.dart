import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../helpers/notification_helper.dart';

// Màn hình đăng ký tài khoản mới cho người dùng
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers để quản lý các input field
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  // Key để validate toàn bộ form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Biến trạng thái của màn hình
  bool _isLoading = false; // Trạng thái đang xử lý đăng ký
  bool _obscurePassword = true; // Ẩn/hiện mật khẩu
  bool _obscureConfirmPassword = true; // Ẩn/hiện xác nhận mật khẩu
  bool _acceptTerms = false; // Đồng ý điều khoản

  @override
  void dispose() {
    // Giải phóng bộ nhớ khi widget bị hủy
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Xử lý logic đăng ký tài khoản
  Future<void> _handleRegister() async {
    // Kiểm tra validation form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Kiểm tra đồng ý điều khoản
    if (!_acceptTerms) {
      NotificationHelper.showWarning('Vui lòng đồng ý với điều khoản sử dụng');
      return;
    }

    // Bắt đầu trạng thái loading
    setState(() => _isLoading = true);

    try {
      // Gọi API đăng ký
      final result = await AuthService.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Kết thúc loading
      setState(() => _isLoading = false);

      // Xử lý kết quả đăng ký
      if (result.success) {
        NotificationHelper.showSuccess('Đăng ký thành công!');
        // Delay để hiển thị thông báo trước khi chuyển màn hình
        await Future.delayed(Duration(milliseconds: 1500));
        Navigator.pop(context);
      } else {
        NotificationHelper.showError(result.message ?? 'Đăng ký thất bại');
      }
    } catch (e) {
      // Xử lý lỗi kết nối
      setState(() => _isLoading = false);
      NotificationHelper.showError('Lỗi kết nối: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // Thanh tiêu đề với nút quay lại
      appBar: AppBar(
        backgroundColor: AppTheme.background,
elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đăng ký',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Nội dung có thể cuộn với form đăng ký
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),

              // Tiêu đề chính
              Text(
                'Tạo tài khoản mới',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              SizedBox(height: 8),

              // Mô tả phụ
              Text(
                'Điền thông tin để tạo tài khoản KDT Music',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),

              SizedBox(height: 32),

              // Ô input họ và tên với validation
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  hintText: 'Nhập họ và tên đầy đủ',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppTheme.accent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
                // Validator kiểm tra tên hợp lệ
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  if (value.length < 2) {
                    return 'Họ và tên phải có ít nhất 2 ký tự';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Ô input email với validation
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Nhập địa chỉ email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppTheme.accent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
                // Validator kiểm tra email hợp lệ
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Ô input mật khẩu với nút ẩn/hiện
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  hintText: 'Tạo mật khẩu mạnh',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
                // Validator kiểm tra độ dài mật khẩu
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu';
                  }
                  if (value.length < 6) {
return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Ô input xác nhận mật khẩu
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  hintText: 'Nhập lại mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
                // Validator kiểm tra mật khẩu khớp nhau
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (value != _passwordController.text) {
                    return 'Mật khẩu không khớp';
                  }
                  return null;
                },
              ),

              SizedBox(height: 24),

              // Checkbox đồng ý điều khoản
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() => _acceptTerms = value ?? false);
                    },
                    activeColor: AppTheme.accent,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _acceptTerms = !_acceptTerms);
                      },
                      child: Text(
                        'Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Nút đăng ký với loading indicator
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Đăng ký',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              SizedBox(height: 24),

              // Link chuyển về màn hình đăng nhập
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đã có tài khoản? ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
