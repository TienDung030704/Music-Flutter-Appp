<?php
require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';

class PlaylistController
{
    private $db;

    public function __construct()
    {
        $database = new Database();
        $this->db = $database->getConnection();
    }

    // Helper method để get current user từ token
    private function getCurrentUser()
    {
        // Try multiple ways to get Authorization header
        $authHeader = '';
        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }
        
        if (empty($authHeader)) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        }
        
        if (empty($authHeader)) {
            // Apache sometimes uses this
            $authHeader = apache_request_headers()['Authorization'] ?? '';
        }
        
        if (empty($authHeader) || strpos($authHeader, 'Bearer ') !== 0) {
            return null;
        }
        
        $token = substr($authHeader, 7); // Remove 'Bearer ' prefix
        
        if (empty($token)) {
            return null;
        }
        
        // Tìm user với auth_token
        $sql = "SELECT * FROM users WHERE auth_token = :token AND token_expires_at > NOW()";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':token', $token);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // Debug log
        error_log('PlaylistController getCurrentUser - Token: ' . substr($token, 0, 10) . '...');
        
        if (!$user) {
            // Check if token exists but expired
            $sqlExpired = "SELECT id, email, token_expires_at FROM users WHERE auth_token = :token";
            $stmtExpired = $this->db->prepare($sqlExpired);
            $stmtExpired->bindParam(':token', $token);
            $stmtExpired->execute();
            $expiredUser = $stmtExpired->fetch(PDO::FETCH_ASSOC);
            
            if ($expiredUser) {
                error_log('PlaylistController getCurrentUser - Token expired for user: ' . $expiredUser['email'] . ' at ' . $expiredUser['token_expires_at']);
            } else {
                error_log('PlaylistController getCurrentUser - Token not found in database');
            }
        }
        
        error_log('PlaylistController getCurrentUser - User found: ' . ($user ? 'Yes' : 'No'));
        
        return $user;
    }

    // Tạo playlist mới
    public function create()
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            // Lấy dữ liệu từ request
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!isset($input['name']) || empty(trim($input['name']))) {
                Response::error('Tên playlist không được để trống', 400);
                return;
            }

            $name = trim($input['name']);
            $description = isset($input['description']) ? trim($input['description']) : null;
            $is_public = isset($input['is_public']) ? (bool)$input['is_public'] : false;

            // Tạo playlist trong database
            $sql = "INSERT INTO playlists (user_id, name, description, is_public) 
                    VALUES (:user_id, :name, :description, :is_public)";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':user_id', $user['id']);
            $stmt->bindParam(':name', $name);
            $stmt->bindParam(':description', $description);
            $stmt->bindParam(':is_public', $is_public, PDO::PARAM_BOOL);

            if ($stmt->execute()) {
                $playlistId = $this->db->lastInsertId();
                
                // Lấy thông tin playlist vừa tạo
                $playlist = $this->getPlaylistById($playlistId);
                
                Response::success($playlist, ['message' => 'Tạo playlist thành công']);
            } else {
                Response::error('Không thể tạo playlist', 500);
            }
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Lấy danh sách playlist của user
    public function getUserPlaylists()
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            $sql = "SELECT p.*, COUNT(ps.id) as song_count 
                    FROM playlists p 
                    LEFT JOIN playlist_songs ps ON p.id = ps.playlist_id 
                    WHERE p.user_id = :user_id 
                    GROUP BY p.id 
                    ORDER BY p.created_at DESC";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':user_id', $user['id']);
            $stmt->execute();

            $playlists = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            Response::success($playlists, ['message' => 'Lấy danh sách playlist thành công']);
        } catch (Exception $e) {
            error_log('PlaylistController getUserPlaylists error: ' . $e->getMessage());
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Lấy chi tiết playlist
    public function getPlaylist($id)
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            $playlist = $this->getPlaylistById($id);
            
            if (!$playlist) {
                Response::error('Không tìm thấy playlist', 404);
                return;
            }

            // Kiểm tra quyền truy cập
            if ($playlist['user_id'] != $user['id'] && !$playlist['is_public']) {
                Response::error('Không có quyền truy cập playlist này', 403);
                return;
            }

            // Lấy danh sách bài hát trong playlist
            $sql = "SELECT * FROM playlist_songs 
                    WHERE playlist_id = :playlist_id 
                    ORDER BY position ASC, added_at ASC";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':playlist_id', $id);
            $stmt->execute();

            $songs = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $playlist['songs'] = $songs;
            
            Response::success($playlist, ['message' => 'Lấy playlist thành công']);
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Thêm bài hát vào playlist
    public function addSong($playlistId)
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            // Kiểm tra playlist có tồn tại và thuộc về user
            $playlist = $this->getPlaylistById($playlistId);
            if (!$playlist || $playlist['user_id'] != $user['id']) {
                Response::error('Không tìm thấy playlist hoặc không có quyền', 403);
                return;
            }

            // Lấy dữ liệu bài hát
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!isset($input['song_id']) || empty($input['song_id'])) {
                Response::error('Song ID không được để trống', 400);
                return;
            }

            $songId = $input['song_id'];
            $songTitle = $input['song_title'] ?? '';
            $artistName = $input['artist_name'] ?? '';
            $thumbnail = $input['thumbnail'] ?? null;
            $duration = isset($input['duration']) ? (int)$input['duration'] : null;

            // Kiểm tra bài hát đã có trong playlist chưa
            $sql = "SELECT id FROM playlist_songs 
                    WHERE playlist_id = :playlist_id AND song_id = :song_id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':playlist_id', $playlistId);
            $stmt->bindParam(':song_id', $songId);
            $stmt->execute();

            if ($stmt->fetch()) {
                Response::error('Bài hát đã có trong playlist', 400);
                return;
            }

            // Lấy position tiếp theo
            $sql = "SELECT COALESCE(MAX(position), 0) + 1 as next_position 
                    FROM playlist_songs WHERE playlist_id = :playlist_id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':playlist_id', $playlistId);
            $stmt->execute();
            $result = $stmt->fetch();
            $position = $result['next_position'];

            // Thêm bài hát vào playlist
            $sql = "INSERT INTO playlist_songs 
                    (playlist_id, song_id, song_title, artist_name, thumbnail, duration, position) 
                    VALUES (:playlist_id, :song_id, :song_title, :artist_name, :thumbnail, :duration, :position)";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':playlist_id', $playlistId, PDO::PARAM_INT);
            $stmt->bindParam(':song_id', $songId, PDO::PARAM_STR);
            $stmt->bindParam(':song_title', $songTitle, PDO::PARAM_STR);
            $stmt->bindParam(':artist_name', $artistName, PDO::PARAM_STR);
            
            if ($thumbnail === null) {
                $stmt->bindValue(':thumbnail', null, PDO::PARAM_NULL);
            } else {
                $stmt->bindParam(':thumbnail', $thumbnail, PDO::PARAM_STR);
            }
            
            if ($duration === null) {
                $stmt->bindValue(':duration', null, PDO::PARAM_NULL);
            } else {
                $stmt->bindParam(':duration', $duration, PDO::PARAM_INT);
            }
            
            $stmt->bindParam(':position', $position, PDO::PARAM_INT);

            if ($stmt->execute()) {
                Response::success([], ['message' => 'Thêm bài hát vào playlist thành công']);
                if (ob_get_level()) ob_end_flush();
                flush();
                
                // Cập nhật song_count của playlist sau khi response được gửi
                $this->updatePlaylistSongCount($playlistId);
            } else {
                $errorInfo = $stmt->errorInfo();
                error_log("SQL Error in addSong: " . print_r($errorInfo, true));
                Response::error('Không thể thêm bài hát vào playlist: ' . $errorInfo[2], 500);
                if (ob_get_level()) ob_end_flush();
                flush();
            }
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Xóa bài hát khỏi playlist
    public function removeSong($playlistId, $songId)
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            // Kiểm tra playlist có tồn tại và thuộc về user
            $playlist = $this->getPlaylistById($playlistId);
            if (!$playlist || $playlist['user_id'] != $user['id']) {
                Response::error('Không tìm thấy playlist hoặc không có quyền', 403);
                return;
            }

            // Xóa bài hát khỏi playlist
            $sql = "DELETE FROM playlist_songs 
                    WHERE playlist_id = :playlist_id AND song_id = :song_id";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':playlist_id', $playlistId);
            $stmt->bindParam(':song_id', $songId);

            if ($stmt->execute()) {
                // Cập nhật song_count của playlist
                $this->updatePlaylistSongCount($playlistId);
                
                Response::success([], ['message' => 'Xóa bài hát khỏi playlist thành công']);
            } else {
                Response::error('Không thể xóa bài hát khỏi playlist', 500);
            }
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Xóa playlist
    public function delete($id)
    {
        try {
            // Kiểm tra authentication
            $user = $this->getCurrentUser();
            if (!$user) {
                Response::error('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại', 401);
                return;
            }

            // Kiểm tra playlist có tồn tại và thuộc về user
            $playlist = $this->getPlaylistById($id);
            if (!$playlist || $playlist['user_id'] != $user['id']) {
                Response::error('Không tìm thấy playlist hoặc không có quyền', 403);
                return;
            }

            // Xóa playlist (các bài hát sẽ tự động xóa do CASCADE)
            $sql = "DELETE FROM playlists WHERE id = :id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':id', $id);

            if ($stmt->execute()) {
                Response::success([], ['message' => 'Xóa playlist thành công']);
            } else {
                Response::error('Không thể xóa playlist', 500);
            }
        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Helper method để lấy playlist theo ID
    private function getPlaylistById($id)
    {
        $sql = "SELECT * FROM playlists WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':id', $id);
        $stmt->execute();
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    // Helper method để cập nhật song_count của playlist
    private function updatePlaylistSongCount($playlistId)
    {
        $sql = "UPDATE playlists 
                SET song_count = (
                    SELECT COUNT(*) FROM playlist_songs 
                    WHERE playlist_id = :playlist_id1
                ) 
                WHERE id = :playlist_id2";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':playlist_id1', $playlistId, PDO::PARAM_INT);
        $stmt->bindParam(':playlist_id2', $playlistId, PDO::PARAM_INT);
        $stmt->execute();
    }

    // Test endpoint (no auth required)
    public function test()
    {
        // Test database connection
        try {
            $stmt = $this->db->query("SELECT 1");
            $dbStatus = 'OK';
        } catch (Exception $e) {
            $dbStatus = 'Error: ' . $e->getMessage();
        }
        
        // Test auth header
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? 'No auth header';
        
        Response::success([
            'message' => 'PlaylistController is working',
            'database' => $dbStatus,
            'auth_header' => substr($authHeader, 0, 20) . '...',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }

    // Test auth endpoint  
    public function testAuth()
    {
        $user = $this->getCurrentUser();
        if (!$user) {
            Response::error('No user found - check auth token', 401);
            return;
        }
        
        Response::success([
            'message' => 'Auth working',
            'user_id' => $user['id'],
            'user_email' => $user['email'],
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
}
?>