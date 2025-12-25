<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';

class FavoritesController {
    private $db;
    
    public function __construct() {
        $this->db = new Database();
    }
    
    // Thêm bài hát vào favorites
    public function addToFavorites() {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Chưa đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401, ['need_refresh' => true]);
                return;
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (empty($input['song_id']) || empty($input['song_title'])) {
                Response::error('Thiếu thông tin bài hát', 400);
                return;
            }
            
            // Kiểm tra xem đã có trong favorites chưa
            $existing = $this->db->fetchOne(
                'SELECT id FROM user_favorites WHERE user_id = :user_id AND song_id = :song_id',
                ['user_id' => $user['id'], 'song_id' => $input['song_id']]
            );
            
            if ($existing) {
                Response::error('Bài hát đã có trong danh sách yêu thích', 409);
                return;
            }
            
            $favoriteData = [
                'user_id' => $user['id'],
                'song_id' => $input['song_id'],
                'song_title' => $input['song_title'],
                'artist_name' => $input['artist_name'] ?? null,
                'thumbnail' => $input['thumbnail'] ?? null,
                'duration' => $input['duration'] ?? null
            ];
            
            $favoriteId = $this->db->insert('user_favorites', $favoriteData);
            
            if ($favoriteId) {
                Response::success([
                    'favorite_id' => $favoriteId,
                    'message' => 'Đã thêm vào danh sách yêu thích'
                ], [], 201);
            } else {
                Response::error('Không thể thêm vào danh sách yêu thích', 500);
            }
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    // Xóa bài hát khỏi favorites
    public function removeFromFavorites($songId) {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Chưa đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401, ['need_refresh' => true]);
                return;
            }
            
            $deleted = $this->db->delete(
                'user_favorites', 
                'user_id = :user_id AND song_id = :song_id',
                ['user_id' => $user['id'], 'song_id' => $songId]
            );
            
            if ($deleted > 0) {
                Response::success(['message' => 'Đã xóa khỏi danh sách yêu thích']);
            } else {
                Response::error('Bài hát không có trong danh sách yêu thích', 404);
            }
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    // Lấy danh sách favorites của user
    public function getUserFavorites() {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Chưa đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401, ['need_refresh' => true]);
                return;
            }
            
            $favorites = $this->db->fetchAll(
                'SELECT * FROM user_favorites 
                 WHERE user_id = :user_id 
                 ORDER BY created_at DESC',
                ['user_id' => $user['id']]
            );
            
            Response::success([
                'favorites' => $favorites,
                'total' => count($favorites)
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    // Kiểm tra bài hát có trong favorites không
    public function checkFavoriteStatus($songId) {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Chưa đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401, ['need_refresh' => true]);
                return;
            }
            
            $favorite = $this->db->fetchOne(
                'SELECT id FROM user_favorites WHERE user_id = :user_id AND song_id = :song_id',
                ['user_id' => $user['id'], 'song_id' => $songId]
            );
            
            Response::success([
                'is_favorite' => $favorite !== false,
                'song_id' => $songId
            ]);
            
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }
    
    private function getCurrentUser() {
        $token = $this->getBearerToken();
        
        if (!$token) {
            return null;
        }
        
        // Check token and expiry
        $user = $this->db->fetchOne(
            'SELECT * FROM users WHERE auth_token = :token AND is_active = 1',
            ['token' => $token]
        );
        
        if (!$user) {
            return null;
        }
        
        // Check if token is expired
        if ($user['token_expires_at'] && strtotime($user['token_expires_at']) < time()) {
            return false; // Token expired, need refresh
        }
        
        return $user;
    }
    
    private function getBearerToken() {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
        
        return null;
    }
}