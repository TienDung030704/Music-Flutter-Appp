<?php
require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../services/AuthService.php';

class DownloadController {
    private $db;
    
    public function __construct() {
        $this->db = new Database();
    }

    /**
     * Add a song to user's downloads
     * POST /downloads
     */
    public function addDownload() {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Cần đăng nhập để tải về', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401);
                return;
            }

            $input = json_decode(file_get_contents('php://input'), true);
            
            // Validate required fields
            $required = ['song_type', 'song_id', 'song_title', 'artist_name'];
            foreach ($required as $field) {
                if (!isset($input[$field]) || empty(trim($input[$field]))) {
                    Response::error("Thiếu thông tin: $field");
                    return;
                }
            }

            $songType = trim($input['song_type']);
            $songId = trim($input['song_id']);
            $songTitle = trim($input['song_title']);
            $artistName = trim($input['artist_name']);
            $artworkUrl = $input['artwork_url'] ?? null;
            $downloadUrl = $input['download_url'] ?? null;
            $fileSize = isset($input['file_size']) ? intval($input['file_size']) : null;
            $duration = isset($input['duration']) ? intval($input['duration']) : null;

            // Validate download URL
            if (empty($downloadUrl) || !$this->isValidUrl($downloadUrl)) {
                Response::error('URL tải về không hợp lệ');
                return;
            }

            // Check if already downloaded
            $existing = $this->db->fetchOne(
                'SELECT id FROM downloads WHERE user_id = ? AND song_type = ? AND song_id = ?',
                [$user['id'], $songType, $songId]
            );
            
            if ($existing) {
                Response::error('Bài hát đã có trong danh sách tải về');
                return;
            }

            // Add to downloads
            $stmt = $this->db->query(
                'INSERT INTO downloads (user_id, song_type, song_id, song_title, artist_name, artwork_url, download_url, file_size, duration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$user['id'], $songType, $songId, $songTitle, $artistName, $artworkUrl, $downloadUrl, $fileSize, $duration]
            );

            // Create notification for admins
            require_once __DIR__ . '/NotificationController.php';
            NotificationController::notifyAdmins(
                $user['id'],
                'download',
                'Tải xuống mới',
                $user['full_name'] . ' đã tải bài hát "' . $songTitle . '"',
                [
                    'song_id' => $songId,
                    'song_type' => $songType,
                    'song_title' => $songTitle,
                    'artist_name' => $artistName,
                    'downloader_name' => $user['full_name']
                ]
            );

            Response::success([
                'message' => 'Đã thêm vào danh sách tải về'
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Remove a song from user's downloads by ID
     * DELETE /downloads/{id}
     */
    public function removeDownload($downloadId) {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Cần đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401);
                return;
            }

            $downloadId = intval($downloadId);
            if (!$downloadId) {
                Response::error('ID tải về không hợp lệ');
                return;
            }

            // Verify ownership before deleting
            $existing = $this->db->fetchOne(
                'SELECT id FROM downloads WHERE id = ? AND user_id = ?',
                [$downloadId, $user['id']]
            );
            
            if (!$existing) {
                Response::error('Không tìm thấy bài hát trong danh sách tải về');
                return;
            }

            // Delete the download
            $this->db->query(
                'DELETE FROM downloads WHERE id = ? AND user_id = ?',
                [$downloadId, $user['id']]
            );

            Response::success(['message' => 'Đã xóa khỏi danh sách tải về']);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Get user's downloaded songs
     * GET /downloads
     */
    public function getDownloads() {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::error('Cần đăng nhập', 401);
                return;
            }
            if ($user === false) {
                Response::error('Token đã hết hạn', 401);
                return;
            }

            // Get downloads
            $downloads = $this->db->fetchAll(
                'SELECT id, song_type, song_id, song_title, artist_name, artwork_url, download_url, file_size, duration, created_at FROM downloads WHERE user_id = ? ORDER BY created_at DESC',
                [$user['id']]
            );

            Response::success($downloads);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Check if a song is downloaded
     * GET /downloads/check?song_type=xxx&song_id=xxx
     */
    public function checkDownload() {
        try {
            $user = $this->getCurrentUser();
            if ($user === null) {
                Response::success(['is_downloaded' => false]);
                return;
            }
            if ($user === false) {
                Response::success(['is_downloaded' => false]);
                return;
            }

            $songType = $_GET['song_type'] ?? null;
            $songId = $_GET['song_id'] ?? null;

            if (!$songType || !$songId) {
                Response::error('Thiếu thông tin song_type hoặc song_id');
                return;
            }

            $download = $this->db->fetchOne(
                'SELECT id FROM downloads WHERE user_id = ? AND song_type = ? AND song_id = ?',
                [$user['id'], $songType, $songId]
            );
            
            $isDownloaded = $download !== false;

            Response::success(['is_downloaded' => $isDownloaded]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    private function getCurrentUser() {
        $token = $this->getBearerToken();
        
        if (!$token) {
            return null;
        }
        
        // Check token and expiry
        $user = $this->db->fetchOne(
            'SELECT * FROM users WHERE auth_token = ? AND is_active = 1',
            [$token]
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
    private function isValidUrl($url) {
        return filter_var($url, FILTER_VALIDATE_URL) !== false && 
               (strpos($url, 'http://') === 0 || strpos($url, 'https://') === 0);
    }}
?>