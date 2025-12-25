<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../services/AuthService.php';

class ListeningHistoryController {
    private $db;

    public function __construct() {
        $database = new Database();
        $this->db = $database->getConnection();
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
        
        $stmt = $this->db->prepare('SELECT s.*, u.* FROM user_sessions s 
                                   JOIN users u ON s.user_id = u.id 
                                   WHERE s.session_token = ? AND s.expires_at > NOW()');
        $stmt->execute([$token]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $result ?: null;
    }

    /**
     * Add a song to listening history
     * POST /listening-history/add
     */
    public function addListeningHistory() {
        try {
            // Verify authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Token không hợp lệ');
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

            // Validate song_type
            if (!in_array($input['song_type'], ['admin', 'itunes'])) {
                Response::error('song_type phải là "admin" hoặc "itunes"');
                return;
            }

            $userId = $user['id'];
            $songType = trim($input['song_type']);
            $songId = trim($input['song_id']);
            $songTitle = trim($input['song_title']);
            $artistName = trim($input['artist_name']);
            $thumbnail = $input['thumbnail'] ?? null;
            $durationListened = $input['duration_listened'] ?? 0;
            $listenDate = date('Y-m-d');

            // Insert or update listening history
            $sql = "INSERT INTO listening_history 
                    (user_id, song_type, song_id, song_title, artist_name, thumbnail, listen_date, duration_listened) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE 
                    listened_at = CURRENT_TIMESTAMP, 
                    duration_listened = duration_listened + VALUES(duration_listened)";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                $userId, $songType, $songId, $songTitle, $artistName, $thumbnail, $listenDate, $durationListened
            ]);

            // Create notification for admins (only for first listen of the day to avoid spam)
            $checkExistingSql = "SELECT COUNT(*) as count FROM listening_history 
                               WHERE user_id = ? AND song_type = ? AND song_id = ? AND listen_date = ?";
            $checkStmt = $this->db->prepare($checkExistingSql);
            $checkStmt->execute([$userId, $songType, $songId, $listenDate]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing['count'] == 1) { // First time listening today
                require_once __DIR__ . '/NotificationController.php';
                $user = $this->getCurrentUser();
                if ($user) {
                    NotificationController::notifyAdmins(
                        $userId,
                        'listening',
                        'Lượt nghe mới',
                        $user['full_name'] . ' đã nghe bài hát "' . $songTitle . '"',
                        [
                            'song_id' => $songId,
                            'song_type' => $songType,
                            'song_title' => $songTitle,
                            'artist_name' => $artistName,
                            'listener_name' => $user['full_name']
                        ]
                    );
                }
            }

            Response::success([
                'message' => 'Đã thêm vào lịch sử nghe',
                'song_id' => $songId,
                'song_type' => $songType
            ]);

        } catch (Exception $e) {
            error_log("Error adding listening history: " . $e->getMessage());
            Response::error('Không thể thêm vào lịch sử nghe', $e->getMessage());
        }
    }

    /**
     * Get listening history by date
     * GET /listening-history/by-date?date=YYYY-MM-DD
     */
    public function getListeningHistoryByDate() {
        try {
            // Verify authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Token không hợp lệ');
                return;
            }

            $date = $_GET['date'] ?? date('Y-m-d');
            
            // Validate date format
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                Response::error('Định dạng ngày không hợp lệ (YYYY-MM-DD)');
                return;
            }

            $userId = $user['id'];

            $sql = "SELECT * FROM listening_history 
                    WHERE user_id = ? AND listen_date = ? 
                    ORDER BY listened_at DESC";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, $date]);
            $history = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'date' => $date,
                'count' => count($history),
                'songs' => $history
            ]);

        } catch (Exception $e) {
            error_log("Error getting listening history by date: " . $e->getMessage());
            Response::error('Không thể lấy lịch sử nghe', $e->getMessage());
        }
    }

    /**
     * Get recent listening history (last 7 days)
     * GET /listening-history/recent
     */
    public function getRecentListeningHistory() {
        try {
            // Verify authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Token không hợp lệ');
                return;
            }

            $userId = $user['id'];
            $limit = $_GET['limit'] ?? 50;

            $sql = "SELECT listen_date, 
                           COUNT(*) as song_count,
                           GROUP_CONCAT(DISTINCT song_title ORDER BY listened_at DESC SEPARATOR ', ') as recent_songs
                    FROM listening_history 
                    WHERE user_id = ? AND listen_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
                    GROUP BY listen_date 
                    ORDER BY listen_date DESC
                    LIMIT ?";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, (int)$limit]);
            $recentDays = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'recent_days' => $recentDays,
                'total_days' => count($recentDays)
            ]);

        } catch (Exception $e) {
            error_log("Error getting recent listening history: " . $e->getMessage());
            Response::error('Không thể lấy lịch sử nghe gần đây', $e->getMessage());
        }
    }

    /**
     * Get listening statistics
     * GET /listening-history/stats
     */
    public function getListeningStats() {
        try {
            // Verify authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Token không hợp lệ');
                return;
            }

            $userId = $user['id'];

            // Get today's stats
            $sqlToday = "SELECT COUNT(*) as today_count, 
                                SUM(duration_listened) as today_duration
                         FROM listening_history 
                         WHERE user_id = ? AND listen_date = CURDATE()";
            $stmtToday = $this->db->prepare($sqlToday);
            $stmtToday->execute([$userId]);
            $todayStats = $stmtToday->fetch(PDO::FETCH_ASSOC);

            // Get total stats
            $sqlTotal = "SELECT COUNT(*) as total_count, 
                                SUM(duration_listened) as total_duration,
                                COUNT(DISTINCT listen_date) as days_active
                         FROM listening_history 
                         WHERE user_id = ?";
            $stmtTotal = $this->db->prepare($sqlTotal);
            $stmtTotal->execute([$userId]);
            $totalStats = $stmtTotal->fetch(PDO::FETCH_ASSOC);

            // Get most played songs
            $sqlTopSongs = "SELECT song_title, artist_name, COUNT(*) as play_count
                           FROM listening_history 
                           WHERE user_id = ? 
                           GROUP BY song_id, song_type
                           ORDER BY play_count DESC 
                           LIMIT 5";
            $stmtTopSongs = $this->db->prepare($sqlTopSongs);
            $stmtTopSongs->execute([$userId]);
            $topSongs = $stmtTopSongs->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'today' => $todayStats,
                'total' => $totalStats,
                'top_songs' => $topSongs
            ]);

        } catch (Exception $e) {
            error_log("Error getting listening stats: " . $e->getMessage());
            Response::error('Không thể lấy thống kê nghe nhạc', $e->getMessage());
        }
    }

    /**
     * Clear listening history
     * DELETE /listening-history/clear
     */
    public function clearListeningHistory() {
        try {
            // Verify authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Token không hợp lệ');
                return;
            }

            $userId = $user['id'];
            $input = json_decode(file_get_contents('php://input'), true);
            
            // If date is provided, clear only that date
            if (isset($input['date']) && !empty($input['date'])) {
                $date = $input['date'];
                if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                    Response::error('Định dạng ngày không hợp lệ (YYYY-MM-DD)');
                    return;
                }

                $sql = "DELETE FROM listening_history WHERE user_id = ? AND listen_date = ?";
                $stmt = $this->db->prepare($sql);
                $stmt->execute([$userId, $date]);
                
                Response::success([
                    'message' => 'Đã xóa lịch sử nghe ngày ' . $date,
                    'affected_rows' => $stmt->rowCount()
                ]);
            } else {
                // Clear all history
                $sql = "DELETE FROM listening_history WHERE user_id = ?";
                $stmt = $this->db->prepare($sql);
                $stmt->execute([$userId]);
                
                Response::success([
                    'message' => 'Đã xóa toàn bộ lịch sử nghe',
                    'affected_rows' => $stmt->rowCount()
                ]);
            }

        } catch (Exception $e) {
            error_log("Error clearing listening history: " . $e->getMessage());
            Response::error('Không thể xóa lịch sử nghe', $e->getMessage());
        }
    }

    /**
     * Test method for debugging - Get recent history without authentication
     * GET /listening-history/test-recent
     */
    public function testGetRecentHistory() {
        try {
            // For testing - use default user_id = 1
            $userId = intval($_GET['user_id'] ?? 1);

            $sql = "SELECT listen_date, 
                           COUNT(*) as song_count,
                           GROUP_CONCAT(DISTINCT song_title ORDER BY listened_at DESC SEPARATOR ', ') as recent_songs
                    FROM listening_history 
                    WHERE user_id = ? AND listen_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
                    GROUP BY listen_date 
                    ORDER BY listen_date DESC
                    LIMIT 10";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId]);
            $recentDays = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'recent_days' => $recentDays,
                'total_days' => count($recentDays),
                'user_id' => $userId,
                'message' => 'Test data loaded successfully'
            ]);

        } catch (Exception $e) {
            error_log("Error getting test recent history: " . $e->getMessage());
            Response::error('Không thể lấy lịch sử test', 500, ['message' => $e->getMessage()]);
        }
    }

    /**
     * Test method - Get history by date without authentication
     * GET /listening-history/test-by-date?date=YYYY-MM-DD&user_id=1
     */
    public function testGetHistoryByDate() {
        try {
            $date = $_GET['date'] ?? date('Y-m-d');
            $userId = intval($_GET['user_id'] ?? 1);
            
            // Validate date format
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                Response::error('Định dạng ngày không hợp lệ (YYYY-MM-DD)', 400);
                return;
            }

            $sql = "SELECT 
                        song_id,
                        song_type,
                        song_title,
                        artist_name,
                        thumbnail,
                        listened_at,
                        duration_listened
                    FROM listening_history 
                    WHERE user_id = ? AND listen_date = ?
                    ORDER BY listened_at DESC";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, $date]);
            $history = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'date' => $date,
                'user_id' => $userId,
                'count' => count($history),
                'songs' => $history
            ]);

        } catch (Exception $e) {
            error_log("Error getting test history by date: " . $e->getMessage());
            Response::error('Không thể lấy lịch sử theo ngày', 500, ['message' => $e->getMessage()]);
        }
    }

    /**
     * Test method - Add history without authentication 
     * POST /listening-history/test-add
     */
    public function testAddHistory() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            $userId = intval($input['user_id'] ?? 1);
            $songType = trim($input['song_type'] ?? 'itunes');
            $songId = trim($input['song_id'] ?? '');
            $songTitle = trim($input['song_title'] ?? '');
            $artistName = trim($input['artist_name'] ?? '');
            $thumbnail = $input['thumbnail'] ?? null;
            $durationListened = intval($input['duration_listened'] ?? 0);
            $listenDate = $input['listen_date'] ?? date('Y-m-d');

            if (empty($songId) || empty($songTitle) || empty($artistName)) {
                Response::error('Thiếu thông tin bắt buộc', 400);
                return;
            }

            $sql = "INSERT INTO listening_history 
                    (user_id, song_type, song_id, song_title, artist_name, thumbnail, listen_date, duration_listened) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                $userId, $songType, $songId, $songTitle, $artistName, $thumbnail, $listenDate, $durationListened
            ]);

            Response::success([
                'message' => 'Đã thêm lịch sử nghe (test mode)',
                'song_id' => $songId,
                'user_id' => $userId
            ]);

        } catch (Exception $e) {
            error_log("Error adding test history: " . $e->getMessage());
            Response::error('Không thể thêm lịch sử test', 500, ['message' => $e->getMessage()]);
        }
    }
}

?>