<?php

// Dịch vụ xác thực người dùng - xử lý đăng nhập, đăng ký và quản lý token
class AuthService {
    private $baseUrl;
    
    // Khởi tạo với URL cơ sở của backend
    public function __construct($baseUrl = 'http://localhost/Music-App-Flutter/backend') {
        $this->baseUrl = rtrim($baseUrl, '/');
    }
    
    // Gửi yêu cầu đăng ký tài khoản mới
    public function register($fullName, $email, $password) {
        return $this->makeRequest('POST', '/auth/register', [
            'full_name' => $fullName,
            'email' => $email,
            'password' => $password
        ]);
    }
    
    // Gửi yêu cầu đăng nhập với email và mật khẩu
    public function login($email, $password) {
        return $this->makeRequest('POST', '/auth/login', [
            'email' => $email,
            'password' => $password
        ]);
    }
    
    // Gửi yêu cầu đăng xuất với token xác thực
    public function logout($token) {
        return $this->makeRequest('POST', '/auth/logout', [], [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    // Gửi yêu cầu khôi phục mật khẩu qua email
    public function forgotPassword($email) {
        return $this->makeRequest('POST', '/auth/forgot-password', [
            'email' => $email
        ]);
    }
    
    // Đặt lại mật khẩu mới với token khôi phục
    public function resetPassword($token, $password) {
        return $this->makeRequest('POST', '/auth/reset-password', [
            'token' => $token,
            'password' => $password
        ]);
    }
    
    // Lấy thông tin profile người dùng
    public function getProfile($token) {
        return $this->makeRequest('GET', '/profile', [], [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    // Cập nhật thông tin profile người dùng
    public function updateProfile($token, $data) {
        return $this->makeRequest('PUT', '/profile', $data, [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    // Phương thức riêng để thực hiện HTTP request
    private function makeRequest($method, $endpoint, $data = [], $headers = []) {
        $url = $this->baseUrl . $endpoint;
        
        // Khởi tạo cURL
        $ch = curl_init();
        
        // Header mặc định
        $defaultHeaders = [
            'Content-Type: application/json'
        ];
        
        $headers = array_merge($defaultHeaders, $headers);
        
        // Cấu hình cURL
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        
        // Thiết lập method HTTP và data
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        } elseif ($method === 'PUT') {
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        } elseif ($method === 'DELETE') {
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
        }
        
        // Thực hiện request và lấy kết quả
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        curl_close($ch);
        
        // Xử lý lỗi kết nối
        if ($error) {
            return [
                'success' => false,
                'error' => 'Lỗi kết nối: ' . $error,
                'http_code' => 0
            ];
        }
        
        // Decode JSON response và trả về kết quả
        $decodedResponse = json_decode($response, true);
        
        return [
            'success' => $httpCode >= 200 && $httpCode < 300,
            'data' => $decodedResponse,
            'http_code' => $httpCode,
            'raw_response' => $response
        ];
    }

    // Các phương thức phía server để xử lý backend
    private static $db = null;

    // Lấy kết nối database (singleton pattern)
    private static function getDB() {
        if (self::$db === null) {
            require_once __DIR__ . '/../database/Database.php';
            $database = new Database();
            self::$db = $database->getConnection();
        }
        return self::$db;
    }

    /**
     * Làm mới token hết hạn (phía server)
     */
    public function refreshToken($token) {
        try {
            $db = self::getDB();
            
            // Tìm user theo token hết hạn hoặc refresh token
            $sql = "SELECT id, refresh_token FROM users WHERE (auth_token = ? OR refresh_token = ?)";
            $stmt = $db->prepare($sql);
            $stmt->execute([$token, $token]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$user) {
                error_log("DEBUG - RefreshToken: User not found for token");
                return null;
            }
            
            // Tạo token mới
            $newAuthToken = bin2hex(random_bytes(32));
            $newRefreshToken = bin2hex(random_bytes(32));
            $newExpiresAt = date('Y-m-d H:i:s', time() + (24 * 60 * 60)); // 24 giờ
            
            // Cập nhật token trong database
            $sql = "UPDATE users SET auth_token = ?, refresh_token = ?, token_expires_at = ? WHERE id = ?";
            $stmt = $db->prepare($sql);
            $stmt->execute([$newAuthToken, $newRefreshToken, $newExpiresAt, $user['id']]);
            
            error_log("DEBUG - RefreshToken: New tokens generated for user ID " . $user['id']);
            
            // Trả về token mới
            return [
                'auth_token' => $newAuthToken,
                'refresh_token' => $newRefreshToken,
                'expires_at' => $newExpiresAt,
'user_id' => intval($user['id'])
            ];
            
        } catch (Exception $e) {
            error_log("Error refreshing token: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Lấy ID người dùng từ token với tự động làm mới (phía server)
     */
    public function getCurrentUserId() {
        try {
            // Lấy headers từ request
            $headers = getallheaders();
            error_log("DEBUG - AuthService headers: " . json_encode($headers));
            $token = null;

            // Tìm Authorization header (không phân biệt hoa thường)
            $authHeader = null;
            foreach ($headers as $key => $value) {
                if (strtolower($key) === 'authorization') {
                    $authHeader = $value;
                    break;
                }
            }
            
            error_log("DEBUG - AuthService found authHeader: " . ($authHeader ?? 'null'));
            
            // Extract token từ Bearer format
            if ($authHeader && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
                $token = $matches[1];
                error_log("DEBUG - AuthService extracted token: " . substr($token, 0, 20) . "...");
            } else {
                error_log("DEBUG - AuthService: No valid Authorization header found");
            }

            if (!$token) {
                error_log("DEBUG - AuthService: No token found");
                return null;
            }

            // Kiểm tra token hợp lệ trước
            $db = self::getDB();
            $sql = "SELECT id FROM users WHERE auth_token = ? AND token_expires_at > NOW()";
            $stmt = $db->prepare($sql);
            $stmt->execute([$token]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($user) {
                error_log("DEBUG - AuthService: Valid token found for user ID " . $user['id']);
                return intval($user['id']);
            }
            
            // Nếu token hết hạn, thử làm mới
            error_log("DEBUG - AuthService: Token expired, attempting refresh");
            $refreshResult = $this->refreshToken($token);
            
            if ($refreshResult) {
                error_log("DEBUG - AuthService: Token refreshed successfully for user ID " . $refreshResult['user_id']);
                
                // Trả về user ID và set header với token mới
                header('X-New-Auth-Token: ' . $refreshResult['auth_token']);
                header('X-Token-Refreshed: true');
                
                return $refreshResult['user_id'];
            }
            
            error_log("DEBUG - AuthService: Token refresh failed");
            return null;
            
        } catch (Exception $e) {
            error_log("Error getting current user ID: " . $e->getMessage());
            return null;
        }
    }


    /**
* Kiểm tra user có phải admin không (phía server)
     */
    public function isAdmin($userId) {
        try {
            $db = self::getDB();
            $sql = "SELECT role FROM users WHERE id = ?";
            $stmt = $db->prepare($sql);
            $stmt->execute([$userId]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            return $user && $user['role'] === 'admin';
        } catch (Exception $e) {
            error_log("Error checking admin role: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Lấy thông tin user theo ID (phía server)
     */
    public function getUserById($userId) {
        try {
            $db = self::getDB();
            $sql = "SELECT id, full_name, email, role, avatar FROM users WHERE id = ?";
            $stmt = $db->prepare($sql);
            $stmt->execute([$userId]);
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            error_log("Error getting user by ID: " . $e->getMessage());
            return null;
        }
    }
}

