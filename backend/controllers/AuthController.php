<?php

require_once __DIR__ . '/../database/Database.php';

class AuthController {
    private $db;
    
    public function __construct() {
        $this->db = new Database();
    }
    
    public function register() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            // Validate input
            $validation = $this->validateRegisterInput($input);
            if (!$validation['valid']) {
                Response::error($validation['message'], 400);
            }
            
            // Check if email already exists
            if ($this->emailExists($input['email'])) {
                Response::error('Email đã được sử dụng', 409);
            }
            
            // Hash password
            $hashedPassword = password_hash($input['password'], PASSWORD_DEFAULT);
            
            // Create user
            $userData = [
                'full_name' => $input['full_name'],
                'email' => $input['email'],
                'password' => $hashedPassword,
                'role' => 'user',
                'verification_token' => bin2hex(random_bytes(32)),
                'is_active' => true,
                'is_verified' => false
            ];
            
            $userId = $this->db->insert('users', $userData);
            
            if ($userId) {
                $user = $this->getUserById($userId);
                unset($user['password']);
                
                // Create notification for admins about new user registration
                require_once __DIR__ . '/NotificationController.php';
                NotificationController::notifyAdmins(
                    $userId,
                    'new_user',
                    'Người dùng mới',
                    $input['full_name'] . ' đã đăng ký tài khoản mới',
                    [
                        'user_id' => $userId,
                        'user_name' => $input['full_name'],
                        'user_email' => $input['email']
                    ]
                );
                
                Response::success([
                    'user' => $user,
                    'message' => 'Đăng ký thành công'
                ], [], 201);
            } else {
                Response::error('Không thể tạo tài khoản', 500);
            }
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function login() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            // Validate input
            if (empty($input['email']) || empty($input['password'])) {
                Response::error('Email và mật khẩu không được để trống', 400);
            }
            
            // Get user by email
            $user = $this->getUserByEmail($input['email']);
            
            if (!$user) {
                Response::error('Email hoặc mật khẩu không đúng', 401);
            }
            
            // Check if user is active
            if (!$user['is_active']) {
                Response::error('Tài khoản đã bị khóa', 403);
            }
            
            // Verify password
            if (!password_verify($input['password'], $user['password'])) {
                Response::error('Email hoặc mật khẩu không đúng', 401);
            }
            
            // Create tokens
            $accessToken = bin2hex(random_bytes(32));
            $refreshToken = bin2hex(random_bytes(32));
            $accessExpiresAt = date('Y-m-d H:i:s', time() + 86400); // 1 day
            $refreshExpiresAt = date('Y-m-d H:i:s', time() + 604800); // 1 week (7 * 24 * 60 * 60)
            $sessionExpiresAt = date('Y-m-d H:i:s', time() + 7200); // 2 hours for session
            
            $sessionData = [
                'user_id' => $user['id'],
                'session_token' => $accessToken,
                'device_info' => $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown',
                'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'Unknown',
                'expires_at' => $sessionExpiresAt
            ];
            
            $this->db->insert('user_sessions', $sessionData);
            
            // Update user tokens
            $this->db->update('users', 
                [
                    'last_login' => date('Y-m-d H:i:s'),
                    'auth_token' => $accessToken,
                    'refresh_token' => $refreshToken,
                    'token_expires_at' => $accessExpiresAt,
                    'refresh_token_expires_at' => $refreshExpiresAt
                ], 
                'id = :id', 
                ['id' => $user['id']]
            );
            
            // Remove password from response
            unset($user['password']);
            
            Response::success([
                'user' => $user,
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token' => $accessToken, // Backward compatibility
                'expires_at' => $accessExpiresAt,
                'message' => 'Đăng nhập thành công'
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function logout() {
        try {
            $token = $this->getBearerToken();
            
            if (!$token) {
                Response::error('Token không hợp lệ', 401);
            }
            
            // Delete session and clear tokens
            $this->db->delete('user_sessions', 'session_token = :token', ['token' => $token]);
            $this->db->update('users', 
                [
                    'auth_token' => null,
                    'refresh_token' => null,
                    'token_expires_at' => null,
                    'refresh_token_expires_at' => null
                ], 
                'auth_token = :token', 
                ['token' => $token]
            );
            
            Response::success(['message' => 'Đăng xuất thành công']);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    public function refreshToken() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (empty($input['refresh_token'])) {
                Response::error('Refresh token không được để trống', 400);
                return;
            }
            
            // Find user by refresh token
            $user = $this->db->fetchOne(
                'SELECT * FROM users WHERE refresh_token = :refresh_token AND refresh_token_expires_at > NOW()',
                ['refresh_token' => $input['refresh_token']]
            );
            
            if (!$user || !$user['is_active']) {
                Response::error('Refresh token không hợp lệ hoặc đã hết hạn', 401);
                return;
            }
            
            // Generate new tokens
            $newAccessToken = bin2hex(random_bytes(32));
            $newRefreshToken = bin2hex(random_bytes(32));
            $newExpiresAt = date('Y-m-d H:i:s', time() + 86400); // 1 day
            $newRefreshExpiresAt = date('Y-m-d H:i:s', time() + 604800); // 1 week
            
            // Update user tokens
            $this->db->update('users', 
                [
                    'auth_token' => $newAccessToken,
                    'refresh_token' => $newRefreshToken,
                    'token_expires_at' => $newExpiresAt,
                    'refresh_token_expires_at' => $newRefreshExpiresAt
                ], 
                'id = :id', 
                ['id' => $user['id']]
            );
            
            // Delete old session and create new one
            $this->db->delete('user_sessions', 'user_id = :user_id', ['user_id' => $user['id']]);
            $this->db->insert('user_sessions', [
                'user_id' => $user['id'],
                'session_token' => $newAccessToken,
                'device_info' => $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown',
                'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'Unknown',
                'expires_at' => date('Y-m-d H:i:s', time() + 7200)
            ]);
            
            Response::success([
                'access_token' => $newAccessToken,
                'refresh_token' => $newRefreshToken,
                'token' => $newAccessToken, // Backward compatibility
                'expires_at' => $newExpiresAt,
                'message' => 'Token đã được làm mới'
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function forgotPassword() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (empty($input['email'])) {
                Response::error('Email không được để trống', 400);
            }
            
            $user = $this->getUserByEmail($input['email']);
            
            if (!$user) {
                Response::error('Email không tồn tại', 404);
            }
            
            // Generate reset token
            $resetToken = bin2hex(random_bytes(32));
            $expiresAt = date('Y-m-d H:i:s', time() + 3600); // 1 hour
            
            $this->db->update('users', [
                'reset_token' => $resetToken,
                'reset_token_expires' => $expiresAt
            ], 'id = :id', ['id' => $user['id']]);
            
            // In a real app, you would send email here
            // For now, just return the token (remove in production)
            
            Response::success([
                'message' => 'Liên kết khôi phục mật khẩu đã được gửi đến email của bạn',
                'reset_token' => $resetToken // Remove this in production
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function resetPassword() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (empty($input['token']) || empty($input['password'])) {
                Response::error('Token và mật khẩu mới không được để trống', 400);
            }
            
            if (strlen($input['password']) < 6) {
                Response::error('Mật khẩu phải có ít nhất 6 ký tự', 400);
            }
            
            // Find user by reset token
            $user = $this->db->fetchOne(
                'SELECT * FROM users WHERE reset_token = :token AND reset_token_expires > NOW()',
                ['token' => $input['token']]
            );
            
            if (!$user) {
                Response::error('Token không hợp lệ hoặc đã hết hạn', 400);
            }
            
            // Update password and clear reset token
            $hashedPassword = password_hash($input['password'], PASSWORD_DEFAULT);
            
            $this->db->update('users', [
                'password' => $hashedPassword,
                'reset_token' => null,
                'reset_token_expires' => null
            ], 'id = :id', ['id' => $user['id']]);
            
            Response::success(['message' => 'Mật khẩu đã được thay đổi thành công']);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function getProfile() {
        try {
            $user = $this->getCurrentUser();
            
            if (!$user) {
                Response::error('Unauthorized', 401);
            }
            
            // Get user stats
            $stats = $this->getUserStats($user['id']);
            
            Response::success([
                'user' => $user,
                'stats' => $stats
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    public function updateProfile() {
        try {
            $user = $this->getCurrentUser();
            
            if (!$user) {
                Response::error('Unauthorized', 401);
                return;
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            
            $allowedFields = ['full_name', 'phone', 'date_of_birth', 'gender'];
            $updateData = [];
            
            foreach ($allowedFields as $field) {
                if (isset($input[$field])) {
                    $updateData[$field] = $input[$field];
                }
            }
            
            if (empty($updateData)) {
                Response::error('Không có dữ liệu để cập nhật', 400);
            }
            
            $this->db->update('users', $updateData, 'id = :id', ['id' => $user['id']]);
            
            $updatedUser = $this->getUserById($user['id']);
            unset($updatedUser['password']);
            
            Response::success([
                'user' => $updatedUser,
                'message' => 'Cập nhật thông tin thành công'
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    private function validateRegisterInput($input) {
        if (empty($input['full_name'])) {
            return ['valid' => false, 'message' => 'Họ tên không được để trống'];
        }
        
        if (empty($input['email']) || !filter_var($input['email'], FILTER_VALIDATE_EMAIL)) {
            return ['valid' => false, 'message' => 'Email không hợp lệ'];
        }
        
        if (empty($input['password']) || strlen($input['password']) < 6) {
            return ['valid' => false, 'message' => 'Mật khẩu phải có ít nhất 6 ký tự'];
        }
        
        return ['valid' => true];
    }
    
    private function emailExists($email) {
        $user = $this->db->fetchOne('SELECT id FROM users WHERE email = :email', ['email' => $email]);
        return $user !== false;
    }
    
    private function getUserById($id) {
        return $this->db->fetchOne('SELECT * FROM users WHERE id = :id', ['id' => $id]);
    }
    
    private function getUserByEmail($email) {
        return $this->db->fetchOne('SELECT * FROM users WHERE email = :email', ['email' => $email]);
    }
    
    private function getBearerToken() {
        $authHeader = '';
        
        // Method 1: getallheaders()
        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }
        
        // Method 2: $_SERVER['HTTP_AUTHORIZATION']
        if (empty($authHeader)) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        }
        
        // Method 3: apache_request_headers()
        if (empty($authHeader) && function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }
        
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
        
        return null;
    }
    
    private function getCurrentUser() {
        $token = $this->getBearerToken();
        
        if (!$token) {
            return null;
        }
        
        $session = $this->db->fetchOne(
            'SELECT s.*, u.* FROM user_sessions s 
             JOIN users u ON s.user_id = u.id 
             WHERE s.session_token = :token AND s.expires_at > :current_time',
            [
                'token' => $token,
                'current_time' => date('Y-m-d H:i:s')
            ]
        );
        
        if ($session) {
            unset($session['password']);
            return $session;
        }
        
        return null;
    }
    
    private function getUserStats($userId) {
        $favorites = $this->db->fetchOne(
            'SELECT COUNT(*) as count FROM user_favorites WHERE user_id = :user_id',
            ['user_id' => $userId]
        );
        
        $playlists = $this->db->fetchOne(
            'SELECT COUNT(*) as count FROM playlists WHERE user_id = :user_id',
            ['user_id' => $userId]
        );
        
        $history = $this->db->fetchOne(
            'SELECT COUNT(*) as count FROM listening_history WHERE user_id = :user_id',
            ['user_id' => $userId]
        );
        
        return [
            'favorites' => $favorites['count'] ?? 0,
            'playlists' => $playlists['count'] ?? 0,
            'history' => $history['count'] ?? 0
        ];
    }
    
    public function changePassword() {
        try {
            error_log('=== CHANGE PASSWORD DEBUG ===');
            
            $input = json_decode(file_get_contents('php://input'), true);
            error_log('Input data: ' . json_encode($input));
            
            // Validate input
            if (empty($input['currentPassword']) || empty($input['newPassword'])) {
                error_log('Empty password fields');
                Response::error('Mật khẩu hiện tại và mật khẩu mới không được để trống', 400);
                return;
            }
            
            if (strlen($input['newPassword']) < 6) {
                Response::error('Mật khẩu mới phải có ít nhất 6 ký tự', 400);
                return;
            }
            
            // Get authorization header - try multiple methods
            $authHeader = '';
            
            // Method 1: getallheaders()
            if (function_exists('getallheaders')) {
                $headers = getallheaders();
                $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
            }
            
            // Method 2: $_SERVER variables if getallheaders didn't work
            if (empty($authHeader)) {
                $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
            }
            
            // Method 3: Alternative server variable
            if (empty($authHeader)) {
                $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
            }
            
            error_log('Auth header: ' . $authHeader);
            
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                error_log('Invalid token format');
                Response::error('Token không hợp lệ', 401);
                return;
            }
            
            $token = substr($authHeader, 7);
            error_log('Token: ' . substr($token, 0, 20) . '...');
            
            // First try to get user from session token
            $session = $this->db->fetchOne(
                'SELECT * FROM user_sessions WHERE session_token = :token AND expires_at > :current_time',
                [
                    'token' => $token,
                    'current_time' => date('Y-m-d H:i:s')
                ]
            );
            error_log('Session found: ' . ($session ? 'YES' : 'NO'));
            
            $user = null;
            if ($session) {
                // Get current user from session
                $user = $this->getUserById($session['user_id']);
                error_log('User found via session: ' . ($user ? $user['email'] : 'NO'));
            } else {
                // If no session, try to get user by auth_token directly
                error_log('No session found, trying to get user by auth_token');
                $currentTime = date('Y-m-d H:i:s');
                error_log('Current time: ' . $currentTime);
                
                $user = $this->db->fetchOne(
                    'SELECT *, token_expires_at FROM users WHERE auth_token = :token AND is_active = 1',
                    [
                        'token' => $token
                    ]
                );
                
                if ($user) {
                    error_log('User found: ' . $user['email'] . ', token expires: ' . $user['token_expires_at']);
                    if ($user['token_expires_at'] <= $currentTime) {
                        error_log('Token expired: ' . $user['token_expires_at'] . ' <= ' . $currentTime);
                        $user = null; // Set to null if expired
                    }
                } else {
                    error_log('No user found with this token');
                }
                
                error_log('User found via auth_token: ' . ($user ? $user['email'] : 'NO'));
            }
            
            if (!$user) {
                error_log('User not found or token expired');
                Response::error('Token không hợp lệ hoặc đã hết hạn', 401);
                return;
            }
            
            // Verify current password
            $passwordValid = password_verify($input['currentPassword'], $user['password']);
            error_log('Password verification: ' . ($passwordValid ? 'VALID' : 'INVALID'));
            if (!$passwordValid) {
                error_log('Current password is incorrect');
                Response::error('Mật khẩu hiện tại không đúng', 400);
                return;
            }
            
            // Hash new password
            $hashedNewPassword = password_hash($input['newPassword'], PASSWORD_DEFAULT);
            
            // Update password
            $updated = $this->db->update(
                'users',
                ['password' => $hashedNewPassword],
                'id = :id',
                ['id' => $user['id']]
            );
            
            if ($updated) {
                // Invalidate all existing sessions for security
                $this->db->delete(
                    'user_sessions',
                    'user_id = :user_id',
                    ['user_id' => $user['id']]
                );
                
                Response::success([
                    'message' => 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'
                ]);
            } else {
                Response::error('Không thể đổi mật khẩu. Vui lòng thử lại.', 500);
            }
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
}