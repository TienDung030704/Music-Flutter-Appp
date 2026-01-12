import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Màn hình quên mật khẩu cho phép người dùng khôi phục tài khoản
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controller để quản lý input email
  final TextEditingController _emailController = TextEditingController();
  // Key để validate form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Biến trạng thái đang loading
  bool _isLoading = false;
  // Biến trạng thái đã gửi email thành công
  bool _emailSent = false;

  @override
  void dispose() {
    // Giải phóng bộ nhớ khi widget bị hủy
    _emailController.dispose();
    super.dispose();
  }

  // Xử lý logic gửi email khôi phục mật khẩu
  Future<void> _handleForgotPassword() async {
    // Kiểm tra validation form trước khi gửi
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Bắt đầu trạng thái loading
    setState(() => _isLoading = true);

    // Mô phỏng gọi API (delay 2 giây)
    await Future.delayed(Duration(seconds: 2));

    // Kết thúc loading và chuyển sang màn hình thành công
    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
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
          'Quên mật khẩu',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Nội dung có thể cuộn, hiển thị form hoặc màn hình thành công
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: _emailSent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  // Widget hiển thị form nhập email
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 40),

          // Icon khóa reset ở giữa màn hình
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.1),
            ),
            child: Icon(Icons.lock_reset, size: 60, color: AppTheme.accent),
          ),

          SizedBox(height: 40),

          // Tiêu đề chính
Text(
            'Khôi phục mật khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          SizedBox(height: 16),

          // Mô tả hướng dẫn
          Text(
            'Nhập địa chỉ email của bạn và chúng tôi sẽ gửi cho bạn liên kết để đặt lại mật khẩu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),

          SizedBox(height: 40),

          // Ô input email với validation
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Nhập địa chỉ email của bạn',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.accent),
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

          SizedBox(height: 32),

          // Nút gửi email với loading indicator
          ElevatedButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Gửi liên kết khôi phục',
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),

          SizedBox(height: 24),

          // Link quay lại màn hình đăng nhập
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Nhớ mật khẩu? ',
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
    );
  }

  // Widget hiển thị màn hình thành công sau khi gửi email
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 60),

        // Icon thành công
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.1),
          ),
          child: Icon(Icons.mark_email_read, size: 60, color: Colors.green),
        ),

        SizedBox(height: 40),

        // Thông báo thành công
        Text(
          'Email đã được gửi!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),

        SizedBox(height: 16),

        // Thông tin đã gửi email đến địa chỉ nào
        Text(
          'Chúng tôi đã gửi liên kết khôi phục mật khẩu đến',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),

        SizedBox(height: 8),

        // Hiển thị địa chỉ email đã nhập
        Text(
          _emailController.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),

        SizedBox(height: 24),

        // Hộp thông tin hướng dẫn tiếp theo
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(height: 8),
              Text(
                'Kiểm tra hộp thư đến của bạn và nhấn vào liên kết trong email để đặt lại mật khẩu.',
                textAlign: TextAlign.center,
style: TextStyle(fontSize: 14, color: Colors.blue[800]),
              ),
            ],
          ),
        ),

        SizedBox(height: 40),

        // Nút gửi lại email
        OutlinedButton(
          onPressed: () {
            setState(() => _emailSent = false);
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.accent),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Gửi lại email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
            ),
          ),
        ),

        SizedBox(height: 16),

        // Nút quay lại màn hình đăng nhập
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Text(
            'Quay lại đăng nhập',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}