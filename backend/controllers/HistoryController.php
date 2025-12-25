<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';

class HistoryController {
    private $db;

    public function __construct() {
        $database = new Database();
        $this->db = $database->getConnection();
    }

    /**
     * Add listening history (for testing without authentication)
     * POST /history/add
     */
    public function addHistory() {
        try {
            // Get POST data
            $input = json_decode(file_get_contents('php://input'), true);
            
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                Response::error('Method not allowed', 405);
                return;
            }

            // Get parameters with defaults for testing
            $userId = intval($input['user_id'] ?? 1);
            $songType = trim($input['song_type'] ?? 'itunes');
            $songId = trim($input['song_id'] ?? '');
            $songTitle = trim($input['song_title'] ?? '');
            $artistName = trim($input['artist_name'] ?? '');
            $thumbnail = $input['thumbnail'] ?? null;
            $durationListened = intval($input['duration_listened'] ?? 0);
            $listenDate = $input['listen_date'] ?? date('Y-m-d');

            // Validate required fields
            if (empty($songId) || empty($songTitle) || empty($artistName)) {
                Response::error('Missing required fields: song_id, song_title, artist_name', 400);
                return;
            }

            // Validate song_type
            if (!in_array($songType, ['admin', 'itunes'])) {
                Response::error('Invalid song_type. Must be admin or itunes', 400);
                return;
            }

            // Insert listening history
            $sql = "INSERT INTO listening_history 
                    (user_id, song_type, song_id, song_title, artist_name, thumbnail, listen_date, duration_listened) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE 
                    listened_at = CURRENT_TIMESTAMP, 
                    duration_listened = duration_listened + VALUES(duration_listened)";

            $stmt = $this->db->prepare($sql);
            $result = $stmt->execute([
                $userId, $songType, $songId, $songTitle, $artistName, $thumbnail, $listenDate, $durationListened
            ]);

            if ($result) {
                Response::success([
                    'message' => 'Listening history added successfully',
                    'song_id' => $songId,
                    'song_type' => $songType,
                    'listen_date' => $listenDate
                ]);
            } else {
                Response::error('Failed to add listening history', 500);
            }

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Get recent listening history
     * GET /history/recent?user_id=1&limit=10
     */
    public function getRecentHistory() {
        try {
            $userId = intval($_GET['user_id'] ?? 1);
            $limit = intval($_GET['limit'] ?? 10);

            $stmt = $this->db->prepare('
                SELECT 
                    listen_date, 
                    COUNT(*) as song_count,
                    GROUP_CONCAT(DISTINCT song_title ORDER BY listened_at DESC SEPARATOR ", ") as recent_songs
                FROM listening_history 
                WHERE user_id = ? 
                GROUP BY listen_date 
                ORDER BY listen_date DESC 
                LIMIT ?
            ');
            $stmt->execute([$userId, $limit]);
            $recentDays = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'recent_days' => $recentDays,
                'total_days' => count($recentDays),
                'user_id' => $userId
            ]);

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Get listening history by specific date
     * GET /history/by-date?date=2025-12-20&user_id=1
     */
    public function getHistoryByDate() {
        try {
            $date = $_GET['date'] ?? date('Y-m-d');
            $userId = intval($_GET['user_id'] ?? 1);

            // Validate date format
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                Response::error('Invalid date format. Use YYYY-MM-DD', 400);
                return;
            }

            $stmt = $this->db->prepare('
                SELECT 
                    song_id,
                    song_type,
                    song_title,
                    artist_name,
                    thumbnail,
                    listened_at,
                    duration_listened
                FROM listening_history 
                WHERE user_id = ? AND listen_date = ?
                ORDER BY listened_at DESC
            ');
            $stmt->execute([$userId, $date]);
            $songs = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'date' => $date,
                'user_id' => $userId,
                'count' => count($songs),
                'songs' => $songs
            ]);

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Get listening statistics for a user
     * GET /history/stats?user_id=1
     */
    public function getStats() {
        try {
            $userId = intval($_GET['user_id'] ?? 1);

            // Get today's stats
            $stmtToday = $this->db->prepare('
                SELECT 
                    COUNT(*) as today_count, 
                    SUM(duration_listened) as today_duration
                FROM listening_history 
                WHERE user_id = ? AND listen_date = CURDATE()
            ');
            $stmtToday->execute([$userId]);
            $todayStats = $stmtToday->fetch(PDO::FETCH_ASSOC);

            // Get total stats
            $stmtTotal = $this->db->prepare('
                SELECT 
                    COUNT(*) as total_count, 
                    SUM(duration_listened) as total_duration,
                    COUNT(DISTINCT listen_date) as days_active
                FROM listening_history 
                WHERE user_id = ?
            ');
            $stmtTotal->execute([$userId]);
            $totalStats = $stmtTotal->fetch(PDO::FETCH_ASSOC);

            // Get most played songs
            $stmtTopSongs = $this->db->prepare('
                SELECT 
                    song_title, 
                    artist_name, 
                    song_type,
                    COUNT(*) as play_count
                FROM listening_history 
                WHERE user_id = ? 
                GROUP BY song_id, song_type
                ORDER BY play_count DESC 
                LIMIT 5
            ');
            $stmtTopSongs->execute([$userId]);
            $topSongs = $stmtTopSongs->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'user_id' => $userId,
                'today' => $todayStats,
                'total' => $totalStats,
                'top_songs' => $topSongs
            ]);

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Delete listening history
     * DELETE /history/clear?user_id=1&date=2025-12-20 (optional date)
     */
    public function clearHistory() {
        try {
            $userId = intval($_GET['user_id'] ?? 1);
            $date = $_GET['date'] ?? null;

            if ($date) {
                // Clear specific date
                if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                    Response::error('Invalid date format. Use YYYY-MM-DD', 400);
                    return;
                }

                $stmt = $this->db->prepare('DELETE FROM listening_history WHERE user_id = ? AND listen_date = ?');
                $stmt->execute([$userId, $date]);
                
                Response::success([
                    'message' => "Deleted listening history for date: $date",
                    'affected_rows' => $stmt->rowCount()
                ]);
            } else {
                // Clear all history for user
                $stmt = $this->db->prepare('DELETE FROM listening_history WHERE user_id = ?');
                $stmt->execute([$userId]);
                
                Response::success([
                    'message' => 'Deleted all listening history for user',
                    'affected_rows' => $stmt->rowCount()
                ]);
            }

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }
}

?>