<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../services/AuthService.php';

class PlayController {
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
        
        // Try user_sessions first (for session-based auth)
        $stmt = $this->db->prepare('SELECT s.*, u.* FROM user_sessions s 
                                   JOIN users u ON s.user_id = u.id 
                                   WHERE s.session_token = ? AND s.expires_at > NOW()');
        $stmt->execute([$token]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            return $result;
        }
        
        // Fallback to users.auth_token (for token-based auth)
        $stmt = $this->db->prepare('SELECT * FROM users 
                                   WHERE auth_token = ? AND (token_expires_at IS NULL OR token_expires_at > NOW()) AND is_active = 1');
        $stmt->execute([$token]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $result ?: null;
    }

    /**
     * Start a play session
     * POST /play/start-session
     */
    public function startPlaySession() {
        try {
            // Get current user (can be null for anonymous users)
            $user = $this->getCurrentUser();
            
            $input = json_decode(file_get_contents('php://input'), true);
            
            // Validate required fields
            $required = ['song_type', 'song_id'];
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

            $userId = $user ? $user['id'] : null;
            $songType = trim($input['song_type']);
            $songId = trim($input['song_id']);

            // Generate unique session ID
            $sessionToken = bin2hex(random_bytes(16));

            // Insert new play session
            $sql = "INSERT INTO play_sessions (session_id, user_id, song_type, song_id) VALUES (?, ?, ?, ?)";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$sessionToken, $userId, $songType, $songId]);
            
            $sessionDbId = $this->db->lastInsertId();

            Response::success([
                'session_id' => $sessionDbId,
                'session_token' => $sessionToken,
                'message' => 'Play session started successfully'
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * End a play session and increment play count if threshold is met
     * POST /play/end-session
     */
    public function endPlaySession() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            // Validate required fields
            $required = ['session_id', 'play_duration'];
            foreach ($required as $field) {
                if (!isset($input[$field])) {
                    Response::error("Thiếu thông tin: $field");
                    return;
                }
            }

            $sessionId = intval($input['session_id']);
            $playDuration = intval($input['play_duration']); // in seconds
            $songTitle = $input['song_title'] ?? '';
            $artistName = $input['artist_name'] ?? '';

            // Minimum play duration to count as a play (10 seconds)
            $minPlayDuration = 10;
            $countedAsPlay = $playDuration >= $minPlayDuration;

            // Update play session
            $sql = "UPDATE play_sessions 
                    SET end_time = NOW(), play_duration = ?, counted_as_play = ? 
                    WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$playDuration, $countedAsPlay ? 1 : 0, $sessionId]);

            // Get session details to increment play count
            $sql = "SELECT song_type, song_id FROM play_sessions WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$sessionId]);
            $session = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$session) {
                Response::error('Session không tồn tại');
                return;
            }

            // If play duration meets threshold, increment play count
            if ($countedAsPlay) {
                $this->incrementPlayCount(
                    $session['song_type'], 
                    $session['song_id'], 
                    $songTitle, 
                    $artistName
                );
            }

            Response::success([
                'counted_as_play' => $countedAsPlay,
                'play_duration' => $playDuration,
                'min_duration_required' => $minPlayDuration,
                'message' => $countedAsPlay 
                    ? 'Play count incremented successfully' 
                    : 'Play duration too short to count'
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Increment play count for a song
     */
    private function incrementPlayCount($songType, $songId, $songTitle = '', $artistName = '') {
        try {
            // Check if song already exists in song_plays table
            $sql = "SELECT id, play_count FROM song_plays WHERE song_type = ? AND song_id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$songType, $songId]);
            $existingPlay = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($existingPlay) {
                // Increment existing play count
                $sql = "UPDATE song_plays 
                        SET play_count = play_count + 1, 
                            last_played_at = NOW(),
                            updated_at = NOW()
                        WHERE song_type = ? AND song_id = ?";
                $stmt = $this->db->prepare($sql);
                $stmt->execute([$songType, $songId]);
            } else {
                // Insert new record
                $sql = "INSERT INTO song_plays (song_type, song_id, song_title, artist_name, play_count, last_played_at) 
                        VALUES (?, ?, ?, ?, 1, NOW())";
                $stmt = $this->db->prepare($sql);
                $stmt->execute([$songType, $songId, $songTitle, $artistName]);
            }
        } catch (Exception $e) {
            // Log error but don't throw to prevent breaking the main flow
            error_log('Error incrementing play count: ' . $e->getMessage());
        }
    }

    /**
     * Get play count for a specific song
     * GET /play/count/{song_type}/{song_id}
     */
    public function getPlayCount($songType, $songId) {
        try {
            // Validate song_type
            if (!in_array($songType, ['admin', 'itunes'])) {
                Response::error('song_type phải là "admin" hoặc "itunes"');
                return;
            }

            $sql = "SELECT play_count FROM song_plays WHERE song_type = ? AND song_id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$songType, $songId]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);

            $playCount = $result ? $result['play_count'] : 0;

            Response::success([
                'song_type' => $songType,
                'song_id' => $songId,
                'play_count' => $playCount
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Get play counts for multiple songs
     * POST /play/counts
     */
    public function getPlayCounts() {
        try {
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!isset($input['songs']) || !is_array($input['songs'])) {
                Response::error('Thiếu thông tin: songs array');
                return;
            }

            $songs = $input['songs'];
            $playCounts = [];

            // Build WHERE clause for all songs
            $conditions = [];
            $params = [];
            
            foreach ($songs as $song) {
                if (isset($song['song_type']) && isset($song['song_id'])) {
                    $conditions[] = "(song_type = ? AND song_id = ?)";
                    $params[] = $song['song_type'];
                    $params[] = $song['song_id'];
                }
            }

            if (!empty($conditions)) {
                $sql = "SELECT song_type, song_id, play_count FROM song_plays WHERE " . implode(' OR ', $conditions);
                $stmt = $this->db->prepare($sql);
                $stmt->execute($params);
                $results = $stmt->fetchAll(PDO::FETCH_ASSOC);

                // Create lookup array
                foreach ($results as $result) {
                    $key = $result['song_type'] . '_' . $result['song_id'];
                    $playCounts[$key] = $result['play_count'];
                }
            }

            // Build response with play counts for all requested songs
            $response = [];
            foreach ($songs as $song) {
                if (isset($song['song_type']) && isset($song['song_id'])) {
                    $key = $song['song_type'] . '_' . $song['song_id'];
                    $response[] = [
                        'song_type' => $song['song_type'],
                        'song_id' => $song['song_id'],
                        'play_count' => $playCounts[$key] ?? 0
                    ];
                }
            }

            Response::success($response);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Get top played songs (Admin only)
     * GET /play/top-songs
     */
    public function getTopPlayedSongs() {
        try {
            // Verify admin access
            $user = $this->getCurrentUser();
            if (!$user || $user['role'] !== 'admin') {
                Response::error('Không có quyền truy cập', 403);
                return;
            }

            $limit = intval($_GET['limit'] ?? 50);
            $offset = intval($_GET['offset'] ?? 0);

            $sql = "SELECT song_type, song_id, song_title, artist_name, play_count, last_played_at 
                    FROM song_plays 
                    ORDER BY play_count DESC, last_played_at DESC 
                    LIMIT ? OFFSET ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$limit, $offset]);
            $songs = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Get total count
            $countSql = "SELECT COUNT(*) as total FROM song_plays";
            $countStmt = $this->db->prepare($countSql);
            $countStmt->execute();
            $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];

            Response::success([
                'songs' => $songs,
                'total' => intval($totalCount),
                'limit' => $limit,
                'offset' => $offset
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }

    /**
     * Get play statistics (Admin only)
     * GET /play/statistics
     */
    public function getPlayStatistics() {
        try {
            // Verify admin access
            $user = $this->getCurrentUser();
            if (!$user || $user['role'] !== 'admin') {
                Response::error('Không có quyền truy cập', 403);
                return;
            }

            // Total plays across all songs
            $totalPlaysSql = "SELECT SUM(play_count) as total_plays FROM song_plays";
            $totalPlaysStmt = $this->db->prepare($totalPlaysSql);
            $totalPlaysStmt->execute();
            $totalPlays = $totalPlaysStmt->fetch(PDO::FETCH_ASSOC)['total_plays'] ?? 0;

            // Total unique songs played
            $totalSongsSql = "SELECT COUNT(*) as total_songs FROM song_plays WHERE play_count > 0";
            $totalSongsStmt = $this->db->prepare($totalSongsSql);
            $totalSongsStmt->execute();
            $totalSongs = $totalSongsStmt->fetch(PDO::FETCH_ASSOC)['total_songs'] ?? 0;

            // Average plays per song
            $avgPlays = $totalSongs > 0 ? round($totalPlays / $totalSongs, 2) : 0;

            // Most played song
            $topSongSql = "SELECT song_title, artist_name, play_count 
                          FROM song_plays 
                          ORDER BY play_count DESC 
                          LIMIT 1";
            $topSongStmt = $this->db->prepare($topSongSql);
            $topSongStmt->execute();
            $topSong = $topSongStmt->fetch(PDO::FETCH_ASSOC);

            // Plays today
            $todayPlaysSql = "SELECT COUNT(*) as today_plays 
                             FROM user_play_sessions 
                             WHERE DATE(session_start) = CURDATE() AND counted_as_play = 1";
            $todayPlaysStmt = $this->db->prepare($todayPlaysSql);
            $todayPlaysStmt->execute();
            $todayPlays = $todayPlaysStmt->fetch(PDO::FETCH_ASSOC)['today_plays'] ?? 0;

            Response::success([
                'total_plays' => intval($totalPlays),
                'total_songs' => intval($totalSongs),
                'average_plays_per_song' => $avgPlays,
                'today_plays' => intval($todayPlays),
                'top_song' => $topSong ?: null
            ]);

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage());
        }
    }
}