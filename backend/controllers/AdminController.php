<?php

require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../sdk.php';

class AdminController
{
    private Database $db;
    private NCT $musicService;
    
    private const CATEGORIES = [
        'Tuyệt Phẩm Bolero' => 'bolero Quang Lê Cẩm Ly',
        'V-Pop Thịnh Hành' => 'vpop hits',
        'Nhạc Trẻ Remix' => 'vinahouse remix'
    ];

    public function __construct()
    {
        $this->db = new Database();
        $this->musicService = new NCT();
    }

    // Thêm bài hát mới
    public function createSong(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data || !isset($data['title']) || !isset($data['artist']) || !isset($data['category'])) {
            Response::error('Thiếu thông tin bài hát', 400);
            return;
        }

        try {
            $songData = [
                'title' => $data['title'],
                'artist' => $data['artist'],
                'thumbnail' => $data['thumbnail'] ?? '',
                'category' => $data['category'],
                'stream_url' => $data['streamUrl'] ?? '',
                'duration' => $data['duration'] ?? 0
            ];

            $songId = $this->db->insert('admin_songs', $songData);

            if ($songId) {
                $song = $this->getSongById($songId);
                
                // Create notification for all users about new song
                require_once __DIR__ . '/NotificationController.php';
                $authService = new AuthService();
                $currentAdminId = $authService->getCurrentUserId();
                
                NotificationController::notifyAllUsers(
                    $currentAdminId,
                    'new_song',
                    'Bài hát mới',
                    'Có bài hát mới: "' . $songData['title'] . '" - ' . $songData['artist'],
                    [
                        'song_id' => $songId,
                        'song_title' => $songData['title'],
                        'artist_name' => $songData['artist'],
                        'thumbnail' => $songData['thumbnail'],
                        'category' => $songData['category']
                    ]
                );
                
                Response::success($song);
            } else {
                Response::error('Lỗi thêm bài hát', 500);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Cập nhật bài hát
    public function updateSong(string $id): void
    {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data || !isset($data['title']) || !isset($data['artist'])) {
            Response::error('Thiếu thông tin bài hát', 400);
            return;
        }

        try {
            // Get existing song data first
            $existingSong = $this->db->fetchOne("SELECT * FROM admin_songs WHERE id = ?", [$id]);
            if (!$existingSong) {
                Response::error('Bài hát không tồn tại với ID: ' . $id, 404);
                return;
            }

            // Clean and validate data - preserve existing URLs if new ones are empty or not provided
            $updateData = [
                'title' => trim($data['title']),
                'artist' => trim($data['artist'])
            ];
            
            // Only update thumbnail if provided and not empty
            if (isset($data['thumbnail']) && !empty(trim($data['thumbnail']))) {
                $updateData['thumbnail'] = trim($data['thumbnail']);
            }
            
            // Only update category if provided
            if (isset($data['category'])) {
                $updateData['category'] = trim($data['category']);
            }
            
            // Only update stream_url if provided and not empty
            $streamUrl = $data['streamUrl'] ?? $data['stream_url'] ?? null;
            if ($streamUrl !== null && !empty(trim($streamUrl))) {
                $updateData['stream_url'] = trim($streamUrl);
            }
            
            // Only update duration if provided
            if (isset($data['duration'])) {
                $updateData['duration'] = (int)$data['duration'];
            }

            // Validate required fields
            if (empty($updateData['title']) || empty($updateData['artist'])) {
                Response::error('Tên bài hát và ca sĩ không được để trống', 400);
                return;
            }

            $affected = $this->db->update('admin_songs', $updateData, 'id = :id', ['id' => $id]);

            if ($affected > 0) {
                $song = $this->getSongById($id);
                if ($song) {
                    Response::success($song);
                } else {
                    Response::error('Cập nhật thành công nhưng không thể lấy dữ liệu mới', 500);
                }
            } else {
                // Still return success with existing data even if no changes
                $song = $this->getSongById($id);
                if ($song) {
                    Response::success($song);
                } else {
                    Response::error('Không thể lấy dữ liệu bài hát', 500);
                }
            }
        } catch (Exception $e) {
            Response::error('Lỗi database: ' . $e->getMessage(), 500);
        }
    }

    // Xóa bài hát
    public function deleteSong(string $id): void
    {
        try {
            $affected = $this->db->delete('admin_songs', 'id = :id', ['id' => $id]);

            if ($affected > 0) {
                Response::success(['message' => 'Đã xóa bài hát']);
            } else {
                Response::error('Không tìm thấy bài hát', 404);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Upload bài hát với file audio
    public function uploadSong() {
        try {
            // Check if all required fields are present
            $title = $_POST['title'] ?? null;
            $artist = $_POST['artist'] ?? null;
            $thumbnail = $_POST['thumbnail'] ?? null;
            $category = $_POST['category'] ?? null;

            if (!$title || !$artist || !$category) {
                Response::error('Thiếu thông tin bắt buộc', 400);
                return;
            }

            // Check if file was uploaded
            if (!isset($_FILES['audio']) || $_FILES['audio']['error'] !== UPLOAD_ERR_OK) {
                Response::error('Không có file audio hoặc upload thất bại', 400);
                return;
            }

            $audioFile = $_FILES['audio'];
            
            // Validate file type
            $allowedTypes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg'];
            if (!in_array($audioFile['type'], $allowedTypes)) {
                Response::error('Định dạng file không được hỗ trợ', 400);
                return;
            }

            // Create upload directory if it doesn't exist
            $uploadDir = __DIR__ . '/../uploads/audio/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            // Generate unique filename
            $fileExtension = pathinfo($audioFile['name'], PATHINFO_EXTENSION);
            $fileName = uniqid() . '.' . $fileExtension;
            $filePath = $uploadDir . $fileName;

            // Move uploaded file
            if (!move_uploaded_file($audioFile['tmp_name'], $filePath)) {
                Response::error('Lỗi lưu file audio', 500);
                return;
            }

            // Save to database
            $streamUrl = '/Music-App-Flutter/Music-App-Flutter/backend/uploads/audio/' . $fileName;
            
            $data = [
                'title' => $title,
                'artist' => $artist,
                'album' => '',
                'category' => $category,
                'thumbnail' => $thumbnail ?: '',
                'stream_url' => $streamUrl,
                'duration' => 0,
                'itunes_id' => null
            ];

            $songId = $this->db->insert('admin_songs', $data);

            if ($songId) {
                // Get the created song
                $song = $this->getSongById($songId);
                
                // Create notification for all users about new song
                require_once __DIR__ . '/NotificationController.php';
                $authService = new AuthService();
                $currentAdminId = $authService->getCurrentUserId();
                
                NotificationController::notifyAllUsers(
                    $currentAdminId,
                    'new_song',
                    'Bài hát mới',
                    'Có bài hát mới: "' . $title . '" - ' . $artist,
                    [
                        'song_id' => $songId,
                        'song_title' => $title,
                        'artist_name' => $artist,
                        'thumbnail' => $thumbnail,
                        'category' => $category
                    ]
                );
                
                Response::success($song);
            } else {
                // Clean up uploaded file if database insert failed
                unlink($filePath);
                Response::error('Lỗi lưu bài hát vào database', 500);
            }

        } catch (Exception $e) {
            Response::error('Lỗi server: ' . $e->getMessage(), 500);
        }
    }

    // Đồng bộ từ iTunes API
    public function syncFromItunes(): void
    {
        try {
            $syncedCount = 0;
            
            foreach (self::CATEGORIES as $category => $query) {
                $results = $this->musicService->getSongSearch($query, 1, 20);
                
                foreach ($results as $song) {
                    $exists = $this->db->fetchAll(
                        "SELECT id FROM admin_songs WHERE itunes_id = ?", 
                        [$song['trackId']]
                    );
                    
                    if (empty($exists)) {
                        $insertQuery = "INSERT INTO admin_songs 
                                       (itunes_id, title, artist, thumbnail, category, stream_url, duration, created_at) 
                                       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())";
                        
                        $params = [
                            $song['trackId'],
                            $song['trackName'],
                            $song['artistName'],
                            str_replace('100x100bb', '300x300bb', $song['artworkUrl100'] ?? ''),
                            $category,
                            $song['previewUrl'] ?? '',
                            $song['trackTimeMillis'] ?? 0
                        ];
                        
                        $this->db->insert($insertQuery, $params);
                        $syncedCount++;
                    }
                }
            }
            
            Response::success([
                'message' => "Đã đồng bộ $syncedCount bài hát từ iTunes",
                'syncedCount' => $syncedCount
            ]);
        } catch (Exception $e) {
            Response::error('Sync error: ' . $e->getMessage(), 500);
        }
    }

    // Lấy danh sách bài hát theo thể loại (từ database)
    public function getSongsByCategory(): void
    {
        $category = $_GET['category'] ?? '';
        $search = $_GET['search'] ?? '';

        try {
            $params = [];
            $conditions = [];
            
            if ($category) {
                $conditions[] = "category = ?";
                $params[] = $category;
            }
            
            if ($search) {
                $conditions[] = "(title LIKE ? OR artist LIKE ?)";
                $searchTerm = "%$search%";
                $params[] = $searchTerm;
                $params[] = $searchTerm;
            }
            
            $query = "SELECT * FROM admin_songs";
            if (!empty($conditions)) {
                $query .= " WHERE " . implode(" AND ", $conditions);
            }
            $query .= " ORDER BY created_at DESC";
            
            $songs = $this->db->fetchAll($query, $params);

            $formattedSongs = array_map(function($song) {
                return [
                    'id' => $song['id'],
                    'title' => $song['title'],
                    'artists' => $song['artist'],
                    'artwork' => $song['thumbnail'], // Use 'artwork' for consistency with Flutter
                    'stream_url' => $song['stream_url'],
                    'duration' => (int)$song['duration'],
                    'category' => $song['category'],
                    'itunesId' => $song['itunes_id']
                ];
            }, $songs);

            Response::success($formattedSongs);
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Lấy thống kê admin
    public function getStats(): void
    {
        try {
            // Tổng bài hát
            $totalSongs = $this->db->fetchAll("SELECT COUNT(*) as count FROM admin_songs")[0]['count'];
            
            // Bài hát theo thể loại
            $categoryStats = $this->db->fetchAll("
                SELECT category, COUNT(*) as count 
                FROM admin_songs 
                GROUP BY category
            ");

            // Bài hát mới nhất
            $recentSongs = $this->db->fetchAll("
                SELECT * FROM admin_songs 
                ORDER BY created_at DESC 
                LIMIT 5
            ");

            $stats = [
                'totalSongs' => (int)$totalSongs,
                'categories' => array_reduce($categoryStats, function($carry, $item) {
                    $carry[$item['category']] = (int)$item['count'];
                    return $carry;
                }, []),
                'recentSongs' => $recentSongs
            ];

            Response::success($stats);
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    private function getSongById(string $id): ?array
    {
        try {
            $query = "SELECT * FROM admin_songs WHERE id = :id";
            $song = $this->db->fetchOne($query, ['id' => $id]);
            
            if ($song) {
                return [
                    'id' => $song['id'],
                    'title' => $song['title'],
                    'artists' => $song['artist'],
                    'artwork' => $song['thumbnail'],
                    'stream_url' => $song['stream_url'],
                    'duration' => (int)$song['duration'],
                    'category' => $song['category']
                ];
            }
            return null;
        } catch (Exception $e) {
            return null;
        }
    }

    // ==================== USER MANAGEMENT ====================

    // Lấy danh sách người dùng
    public function getUsers(): void
    {
        $search = $_GET['search'] ?? '';
        $role = $_GET['role'] ?? '';
        $page = (int)($_GET['page'] ?? 1);
        $limit = (int)($_GET['limit'] ?? 20);
        $offset = ($page - 1) * $limit;

        try {
            $params = [];
            $conditions = [];
            
            if ($search) {
                $conditions[] = "(full_name LIKE ? OR email LIKE ?)";
                $searchTerm = "%$search%";
                $params[] = $searchTerm;
                $params[] = $searchTerm;
            }
            
            if ($role) {
                $conditions[] = "role = ?";
                $params[] = $role;
            }
            
            // Always exclude admin accounts from user management
            $conditions[] = "role != ?";
            $params[] = 'admin';
            
            $whereClause = !empty($conditions) ? " WHERE " . implode(" AND ", $conditions) : "";
            
            // Get total count
            $countQuery = "SELECT COUNT(*) as total FROM users" . $whereClause;
            $totalResult = $this->db->fetchOne($countQuery, $params);
            $total = (int)$totalResult['total'];
            
            // Get users
            $query = "SELECT id, full_name, email, role, avatar, phone, date_of_birth, gender, 
                             is_active, is_verified, last_login, created_at 
                      FROM users" . $whereClause . " 
                      ORDER BY created_at DESC 
                      LIMIT ? OFFSET ?";
            
            $params[] = $limit;
            $params[] = $offset;
            
            $users = $this->db->fetchAll($query, $params);

            $formattedUsers = array_map(function($user) {
                return [
                    'id' => (int)$user['id'],
                    'fullName' => $user['full_name'],
                    'email' => $user['email'],
                    'role' => $user['role'],
                    'avatar' => $user['avatar'],
                    'phone' => $user['phone'],
                    'dateOfBirth' => $user['date_of_birth'],
                    'gender' => $user['gender'],
                    'isActive' => (bool)$user['is_active'],
                    'isVerified' => (bool)$user['is_verified'],
                    'lastLogin' => $user['last_login'],
                    'createdAt' => $user['created_at']
                ];
            }, $users);

            Response::success([
                'users' => $formattedUsers,
                'pagination' => [
                    'total' => $total,
                    'page' => $page,
                    'limit' => $limit,
                    'totalPages' => ceil($total / $limit)
                ]
            ]);
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Tạo người dùng mới
    public function createUser(): void
    {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data || !isset($data['fullName']) || !isset($data['email']) || !isset($data['password'])) {
            Response::error('Thiếu thông tin bắt buộc', 400);
            return;
        }

        try {
            // Check if email exists
            $existingUser = $this->db->fetchOne("SELECT id FROM users WHERE email = ?", [$data['email']]);
            if ($existingUser) {
                Response::error('Email đã được sử dụng', 400);
                return;
            }

            $userData = [
                'full_name' => $data['fullName'],
                'email' => $data['email'],
                'password' => password_hash($data['password'], PASSWORD_DEFAULT),
                'role' => $data['role'] ?? 'user',
                'avatar' => $data['avatar'] ?? null,
                'phone' => $data['phone'] ?? null,
                'date_of_birth' => $data['dateOfBirth'] ?? null,
                'gender' => $data['gender'] ?? null,
                'is_active' => $data['isActive'] ?? true,
                'is_verified' => $data['isVerified'] ?? false
            ];

            $userId = $this->db->insert('users', $userData);

            if ($userId) {
                $user = $this->getUserById($userId);
                Response::success($user);
            } else {
                Response::error('Lỗi tạo người dùng', 500);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Cập nhật người dùng
    public function updateUser(string $id): void
    {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data || !isset($data['fullName']) || !isset($data['email'])) {
            Response::error('Thiếu thông tin người dùng', 400);
            return;
        }

        try {
            // Check if email exists for other users
            $existingUser = $this->db->fetchOne("SELECT id FROM users WHERE email = ? AND id != ?", [$data['email'], $id]);
            if ($existingUser) {
                Response::error('Email đã được sử dụng bởi người khác', 400);
                return;
            }

            $updateData = [
                'full_name' => $data['fullName'],
                'email' => $data['email'],
                'role' => $data['role'] ?? 'user',
                'avatar' => $data['avatar'] ?? null,
                'phone' => $data['phone'] ?? null,
                'date_of_birth' => $data['dateOfBirth'] ?? null,
                'gender' => $data['gender'] ?? null,
                'is_active' => $data['isActive'] ?? true,
                'is_verified' => $data['isVerified'] ?? false
            ];

            // Update password if provided
            if (!empty($data['password'])) {
                $updateData['password'] = password_hash($data['password'], PASSWORD_DEFAULT);
            }

            $affected = $this->db->update('users', $updateData, 'id = :id', ['id' => $id]);

            if ($affected > 0) {
                $user = $this->getUserById($id);
                Response::success($user);
            } else {
                Response::error('Không tìm thấy người dùng', 404);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Xóa người dùng
    public function deleteUser(string $id): void
    {
        try {
            // Check if user exists and is not admin
            $user = $this->db->fetchOne("SELECT role FROM users WHERE id = ?", [$id]);
            if (!$user) {
                Response::error('Không tìm thấy người dùng', 404);
                return;
            }

            // Prevent deleting admin users
            if ($user['role'] === 'admin') {
                Response::error('Không thể xóa tài khoản admin', 403);
                return;
            }

            $affected = $this->db->delete('users', 'id = :id', ['id' => $id]);

            if ($affected > 0) {
                Response::success(['message' => 'Đã xóa người dùng']);
            } else {
                Response::error('Không thể xóa người dùng', 500);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Thay đổi trạng thái người dùng (active/inactive)
    public function toggleUserStatus(string $id): void
    {
        try {
            $user = $this->db->fetchOne("SELECT is_active, role FROM users WHERE id = ?", [$id]);
            if (!$user) {
                Response::error('Không tìm thấy người dùng', 404);
                return;
            }

            // Prevent disabling admin users
            if ($user['role'] === 'admin') {
                Response::error('Không thể khóa tài khoản admin', 403);
                return;
            }

            $newStatus = !$user['is_active'];
            $affected = $this->db->update('users', ['is_active' => $newStatus], 'id = :id', ['id' => $id]);

            if ($affected > 0) {
                $statusText = $newStatus ? 'kích hoạt' : 'khóa';
                Response::success(['message' => "Đã {$statusText} tài khoản", 'isActive' => $newStatus]);
            } else {
                Response::error('Không thể thay đổi trạng thái', 500);
            }
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    // Thống kê người dùng
    public function getUserStats(): void
    {
        try {
            $totalUsers = $this->db->fetchOne("SELECT COUNT(*) as total FROM users")['total'];
            $totalAdmins = $this->db->fetchOne("SELECT COUNT(*) as total FROM users WHERE role = 'admin'")['total'];
            $activeUsers = $this->db->fetchOne("SELECT COUNT(*) as total FROM users WHERE is_active = 1")['total'];
            $verifiedUsers = $this->db->fetchOne("SELECT COUNT(*) as total FROM users WHERE is_verified = 1")['total'];
            
            // Recent registrations (last 30 days)
            $recentUsers = $this->db->fetchOne("
                SELECT COUNT(*) as total FROM users 
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            ")['total'];

            Response::success([
                'totalUsers' => (int)$totalUsers,
                'totalAdmins' => (int)$totalAdmins,
                'activeUsers' => (int)$activeUsers,
                'verifiedUsers' => (int)$verifiedUsers,
                'recentUsers' => (int)$recentUsers
            ]);
        } catch (Exception $e) {
            Response::error('Database error: ' . $e->getMessage(), 500);
        }
    }

    private function getUserById(string $id): ?array
    {
        try {
            $query = "SELECT id, full_name, email, role, avatar, phone, date_of_birth, gender, 
                             is_active, is_verified, last_login, created_at 
                      FROM users WHERE id = :id";
            $user = $this->db->fetchOne($query, ['id' => $id]);
            
            if ($user) {
                return [
                    'id' => (int)$user['id'],
                    'fullName' => $user['full_name'],
                    'email' => $user['email'],
                    'role' => $user['role'],
                    'avatar' => $user['avatar'],
                    'phone' => $user['phone'],
                    'dateOfBirth' => $user['date_of_birth'],
                    'gender' => $user['gender'],
                    'isActive' => (bool)$user['is_active'],
                    'isVerified' => (bool)$user['is_verified'],
                    'lastLogin' => $user['last_login'],
                    'createdAt' => $user['created_at']
                ];
            }
            return null;
        } catch (Exception $e) {
            return null;
        }
    }
}