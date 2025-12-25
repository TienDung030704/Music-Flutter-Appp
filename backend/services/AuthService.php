<?php

class AuthService {
    private $baseUrl;
    
    public function __construct($baseUrl = 'http://localhost/Music-App-Flutter/backend') {
        $this->baseUrl = rtrim($baseUrl, '/');
    }
    
    public function register($fullName, $email, $password) {
        return $this->makeRequest('POST', '/auth/register', [
            'full_name' => $fullName,
            'email' => $email,
            'password' => $password
        ]);
    }
    
    public function login($email, $password) {
        return $this->makeRequest('POST', '/auth/login', [
            'email' => $email,
            'password' => $password
        ]);
    }
    
    public function logout($token) {
        return $this->makeRequest('POST', '/auth/logout', [], [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    public function forgotPassword($email) {
        return $this->makeRequest('POST', '/auth/forgot-password', [
            'email' => $email
        ]);
    }
    
    public function resetPassword($token, $password) {
        return $this->makeRequest('POST', '/auth/reset-password', [
            'token' => $token,
            'password' => $password
        ]);
    }
    
    public function getProfile($token) {
        return $this->makeRequest('GET', '/profile', [], [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    public function updateProfile($token, $data) {
        return $this->makeRequest('PUT', '/profile', $data, [
            'Authorization: Bearer ' . $token
        ]);
    }
    
    private function makeRequest($method, $endpoint, $data = [], $headers = []) {
        $url = $this->baseUrl . $endpoint;
        
        $ch = curl_init();
        
        $defaultHeaders = [
            'Content-Type: application/json'
        ];
        
        $headers = array_merge($defaultHeaders, $headers);
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        } elseif ($method === 'PUT') {
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        } elseif ($method === 'DELETE') {
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        curl_close($ch);
        
        if ($error) {
            return [
                'success' => false,
                'error' => 'Lỗi kết nối: ' . $error,
                'http_code' => 0
            ];
        }
        
        $decodedResponse = json_decode($response, true);
        
        return [
            'success' => $httpCode >= 200 && $httpCode < 300,
            'data' => $decodedResponse,
            'http_code' => $httpCode,
            'raw_response' => $response
        ];
    }

    // Server-side methods for backend controllers
    private static $db = null;

    private static function getDB() {
        if (self::$db === null) {
            require_once __DIR__ . '/../database/Database.php';
            $database = new Database();
            self::$db = $database->getConnection();
        }
        return self::$db;
    }

    /**
     * Refresh expired token (server-side)
     */
    public function refreshToken($token) {
        try {
            $db = self::getDB();
            
            // Find user by expired token or refresh token
            $sql = "SELECT id, refresh_token FROM users WHERE (auth_token = ? OR refresh_token = ?)";
            $stmt = $db->prepare($sql);
            $stmt->execute([$token, $token]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$user) {
                error_log("DEBUG - RefreshToken: User not found for token");
                return null;
            }
            
            // Generate new tokens
            $newAuthToken = bin2hex(random_bytes(32));
            $newRefreshToken = bin2hex(random_bytes(32));
            $newExpiresAt = date('Y-m-d H:i:s', time() + (24 * 60 * 60)); // 24 hours
            
            // Update tokens
            $sql = "UPDATE users SET auth_token = ?, refresh_token = ?, token_expires_at = ? WHERE id = ?";
            $stmt = $db->prepare($sql);
            $stmt->execute([$newAuthToken, $newRefreshToken, $newExpiresAt, $user['id']]);
            
            error_log("DEBUG - RefreshToken: New tokens generated for user ID " . $user['id']);
            
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
     * Get current user ID from token with auto-refresh (server-side)
     */
    public function getCurrentUserId() {
        try {
            $headers = getallheaders();
            error_log("DEBUG - AuthService headers: " . json_encode($headers));
            $token = null;

            // Check Authorization header (case insensitive)
            $authHeader = null;
            foreach ($headers as $key => $value) {
                if (strtolower($key) === 'authorization') {
                    $authHeader = $value;
                    break;
                }
            }
            
            error_log("DEBUG - AuthService found authHeader: " . ($authHeader ?? 'null'));
            
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

            // First try to validate token normally
            $db = self::getDB();
            $sql = "SELECT id FROM users WHERE auth_token = ? AND token_expires_at > NOW()";
            $stmt = $db->prepare($sql);
            $stmt->execute([$token]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($user) {
                error_log("DEBUG - AuthService: Valid token found for user ID " . $user['id']);
                return intval($user['id']);
            }
            
            // If token is expired, try to refresh it
            error_log("DEBUG - AuthService: Token expired, attempting refresh");
            $refreshResult = $this->refreshToken($token);
            
            if ($refreshResult) {
                error_log("DEBUG - AuthService: Token refreshed successfully for user ID " . $refreshResult['user_id']);
                
                // Return user ID and set response header with new token
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
     * Check if user is admin (server-side)
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
     * Get user info by ID (server-side)
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

