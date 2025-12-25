<?php
require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../services/AuthService.php';

class CommentController {
    private $db;
    private $authService;

    public function __construct() {
        try {
            $database = new Database();
            $this->db = $database->getConnection();
            $this->authService = new AuthService();
        } catch (Exception $e) {
            error_log("CommentController initialization error: " . $e->getMessage());
            Response::error('Lỗi kết nối database', 500);
        }
    }

    /**
     * Add comment to a song
     * POST /comments/add
     */
    public function addComment() {
        try {
            // Verify authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Vui lòng đăng nhập để bình luận', 401);
                return;
            }

            // Get input data from global
            $input = $GLOBALS['request_data'] ?? null;
            error_log("DEBUG - addComment input from global: " . json_encode($input));
            
            // Fallback to reading php://input if global is empty
            if ($input === null) {
                $rawInput = file_get_contents('php://input');
                error_log("DEBUG - raw input fallback: " . $rawInput);
                $input = json_decode($rawInput, true);
                error_log("DEBUG - fallback decode: " . json_encode($input));
            }
            
            $songType = trim($input['song_type'] ?? '');
            $songId = trim($input['song_id'] ?? '');
            $songTitle = trim($input['song_title'] ?? '');
            $artistName = trim($input['artist_name'] ?? '');
            $commentText = trim($input['comment_text'] ?? '');

            error_log("DEBUG - parsed fields: songType='$songType', songId='$songId', songTitle='$songTitle', artistName='$artistName', commentText='$commentText'");

            // Validate required fields
            if (empty($songType) || empty($songId) || empty($songTitle) || empty($artistName) || empty($commentText)) {
                error_log("DEBUG - validation failed: songType empty=" . (empty($songType) ? 'yes' : 'no') . 
                         ", songId empty=" . (empty($songId) ? 'yes' : 'no') . 
                         ", songTitle empty=" . (empty($songTitle) ? 'yes' : 'no') . 
                         ", artistName empty=" . (empty($artistName) ? 'yes' : 'no') . 
                         ", commentText empty=" . (empty($commentText) ? 'yes' : 'no'));
                Response::error('Vui lòng điền đầy đủ thông tin', 400);
                return;
            }

            // Validate song_type
            if (!in_array($songType, ['admin', 'itunes'])) {
                Response::error('Loại bài hát không hợp lệ', 400);
                return;
            }

            // Validate comment length
            if (strlen($commentText) > 500) {
                Response::error('Bình luận không được vượt quá 500 ký tự', 400);
                return;
            }

            $sql = "INSERT INTO comments (user_id, song_type, song_id, song_title, artist_name, comment_text) 
                    VALUES (?, ?, ?, ?, ?, ?)";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$userId, $songType, $songId, $songTitle, $artistName, $commentText]);

            $commentId = $this->db->lastInsertId();

            // Get the created comment with user info
            $getCommentSql = "SELECT c.*, u.full_name, u.avatar 
                             FROM comments c 
                             JOIN users u ON c.user_id = u.id 
                             WHERE c.id = ?";
            $getStmt = $this->db->prepare($getCommentSql);
            $getStmt->execute([$commentId]);
            $comment = $getStmt->fetch(PDO::FETCH_ASSOC);

            // Create notification for admins
            require_once __DIR__ . '/NotificationController.php';
            NotificationController::notifyAdmins(
                $userId,
                'comment',
                'Bình luận mới',
                $comment['full_name'] . ' đã bình luận bài hát "' . $songTitle . '"',
                [
                    'song_id' => $songId,
                    'song_title' => $songTitle,
                    'artist_name' => $artistName,
                    'comment_text' => $commentText,
                    'commenter_name' => $comment['full_name']
                ]
            );

            Response::success([
                'message' => 'Đã thêm bình luận thành công',
                'comment' => $comment
            ]);

        } catch (Exception $e) {
            error_log("Error adding comment: " . $e->getMessage());
            Response::error('Không thể thêm bình luận', 500);
        }
    }

    /**
     * Get comments for a song
     * GET /comments/song?song_type=admin&song_id=123&page=1&limit=10
     */
    public function getCommentsBySong() {
        try {
            $songType = trim($_GET['song_type'] ?? '');
            $songId = trim($_GET['song_id'] ?? '');
            $page = intval($_GET['page'] ?? 1);
            $limit = intval($_GET['limit'] ?? 10);

            if (empty($songType) || empty($songId)) {
                Response::error('Thiếu thông tin bài hát', 400);
                return;
            }

            if (!in_array($songType, ['admin', 'itunes'])) {
                Response::error('Loại bài hát không hợp lệ', 400);
                return;
            }

            $offset = ($page - 1) * $limit;

            // Get total count
            $countSql = "SELECT COUNT(*) as total 
                        FROM comments c 
                        WHERE c.song_type = ? AND c.song_id = ? AND c.is_active = TRUE";
            $countStmt = $this->db->prepare($countSql);
            $countStmt->execute([$songType, $songId]);
            $totalComments = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];

            // Get comments with user info
            $sql = "SELECT c.*, u.full_name, u.avatar 
                   FROM comments c 
                   JOIN users u ON c.user_id = u.id 
                   WHERE c.song_type = ? AND c.song_id = ? AND c.is_active = TRUE
                   ORDER BY c.created_at DESC 
                   LIMIT ? OFFSET ?";

            $stmt = $this->db->prepare($sql);
            $stmt->execute([$songType, $songId, $limit, $offset]);
            $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'comments' => $comments,
                'pagination' => [
                    'current_page' => $page,
                    'total_pages' => ceil($totalComments / $limit),
                    'total_comments' => $totalComments,
                    'per_page' => $limit
                ]
            ]);

        } catch (Exception $e) {
            error_log("Error getting comments: " . $e->getMessage());
            Response::error('Không thể lấy danh sách bình luận', 500);
        }
    }

    /**
     * Update user's own comment
     * PUT /comments/update/{id}
     */
    public function updateComment($commentId) {
        try {
            // Verify authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Vui lòng đăng nhập để chỉnh sửa bình luận', 401);
                return;
            }

            $input = json_decode(file_get_contents('php://input'), true);
            $commentText = trim($input['comment_text'] ?? '');

            if (empty($commentText)) {
                Response::error('Nội dung bình luận không được để trống', 400);
                return;
            }

            if (strlen($commentText) > 500) {
                Response::error('Bình luận không được vượt quá 500 ký tự', 400);
                return;
            }

            // Check if comment exists and belongs to user
            $checkSql = "SELECT id FROM comments WHERE id = ? AND user_id = ? AND is_active = TRUE";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([$commentId, $userId]);
            
            if (!$checkStmt->fetch()) {
                Response::error('Bình luận không tồn tại hoặc bạn không có quyền chỉnh sửa', 404);
                return;
            }

            $sql = "UPDATE comments SET comment_text = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$commentText, $commentId]);

            // Get updated comment details
            $updatedSql = "SELECT c.*, u.full_name as username FROM comments c 
                          LEFT JOIN users u ON c.user_id = u.id 
                          WHERE c.id = ?";
            $updatedStmt = $this->db->prepare($updatedSql);
            $updatedStmt->execute([$commentId]);
            $updatedComment = $updatedStmt->fetch(PDO::FETCH_ASSOC);

            if (!$updatedComment) {
                Response::error('Không thể lấy thông tin bình luận đã cập nhật', 500);
                return;
            }

            Response::success([
                'message' => 'Đã cập nhật bình luận thành công',
                'comment' => $updatedComment
            ]);

        } catch (Exception $e) {
            error_log("Error updating comment: " . $e->getMessage());
            Response::error('Không thể cập nhật bình luận', 500);
        }
    }

    /**
     * Delete user's own comment
     * DELETE /comments/delete/{id}
     */
    public function deleteComment($commentId) {
        try {
            // Verify authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Vui lòng đăng nhập để xóa bình luận', 401);
                return;
            }

            // Check if comment exists and belongs to user
            $checkSql = "SELECT id FROM comments WHERE id = ? AND user_id = ? AND is_active = TRUE";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([$commentId, $userId]);
            
            if (!$checkStmt->fetch()) {
                Response::error('Bình luận không tồn tại hoặc bạn không có quyền xóa', 404);
                return;
            }

            // Soft delete
            $sql = "UPDATE comments SET is_active = FALSE WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$commentId]);

            Response::success(['message' => 'Đã xóa bình luận thành công']);

        } catch (Exception $e) {
            error_log("Error deleting comment: " . $e->getMessage());
            Response::error('Không thể xóa bình luận', 500);
        }
    }

    /**
     * Admin: Get all comments with pagination and filters
     * GET /comments/admin/list?page=1&limit=20&song_type=admin&search=keyword
     */
    public function getCommentsForAdmin() {
        try {
            // Verify admin authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId || !$this->authService->isAdmin($userId)) {
                Response::error('Bạn không có quyền truy cập', 403);
                return;
            }

            $page = intval($_GET['page'] ?? 1);
            $limit = intval($_GET['limit'] ?? 20);
            $songType = $_GET['song_type'] ?? '';
            $search = trim($_GET['search'] ?? '');
            $isActive = $_GET['is_active'] ?? '';

            $offset = ($page - 1) * $limit;

            // Build WHERE conditions
            $whereConditions = [];
            $params = [];

            if (!empty($songType) && in_array($songType, ['admin', 'itunes'])) {
                $whereConditions[] = "c.song_type = ?";
                $params[] = $songType;
            }

            if (!empty($search)) {
                $whereConditions[] = "(c.comment_text LIKE ? OR c.song_title LIKE ? OR u.full_name LIKE ?)";
                $searchParam = "%$search%";
                $params[] = $searchParam;
                $params[] = $searchParam;
                $params[] = $searchParam;
            }

            if ($isActive !== '') {
                $whereConditions[] = "c.is_active = ?";
                $params[] = $isActive === '1' ? 1 : 0;
            }

            $whereClause = !empty($whereConditions) ? "WHERE " . implode(" AND ", $whereConditions) : "";

            // Get total count
            $countSql = "SELECT COUNT(*) as total 
                        FROM comments c 
                        JOIN users u ON c.user_id = u.id 
                        $whereClause";
            $countStmt = $this->db->prepare($countSql);
            $countStmt->execute($params);
            $totalComments = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];

            // Get comments
            $sql = "SELECT c.*, u.full_name, u.avatar, u.email 
                   FROM comments c 
                   JOIN users u ON c.user_id = u.id 
                   $whereClause
                   ORDER BY c.created_at DESC 
                   LIMIT ? OFFSET ?";

            $params[] = $limit;
            $params[] = $offset;
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute($params);
            $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

            Response::success([
                'comments' => $comments,
                'pagination' => [
                    'current_page' => $page,
                    'total_pages' => ceil($totalComments / $limit),
                    'total_comments' => $totalComments,
                    'per_page' => $limit
                ]
            ]);

        } catch (Exception $e) {
            error_log("Error getting admin comments: " . $e->getMessage());
            Response::error('Không thể lấy danh sách bình luận', 500);
        }
    }

    /**
     * Admin: Delete comment (soft delete)
     * DELETE /comments/admin/delete/{id}
     */
    public function adminDeleteComment($commentId) {
        try {
            // Verify admin authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId || !$this->authService->isAdmin($userId)) {
                Response::error('Bạn không có quyền truy cập', 403);
                return;
            }

            // Check if comment exists
            $checkSql = "SELECT id FROM comments WHERE id = ?";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([$commentId]);
            
            if (!$checkStmt->fetch()) {
                Response::error('Bình luận không tồn tại', 404);
                return;
            }

            // Soft delete
            $sql = "UPDATE comments SET is_active = FALSE WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$commentId]);

            Response::success(['message' => 'Đã xóa bình luận thành công']);

        } catch (Exception $e) {
            error_log("Error admin deleting comment: " . $e->getMessage());
            Response::error('Không thể xóa bình luận', 500);
        }
    }

    /**
     * Admin: Restore comment
     * PUT /comments/admin/restore/{id}
     */
    public function adminRestoreComment($commentId) {
        try {
            // Verify admin authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId || !$this->authService->isAdmin($userId)) {
                Response::error('Bạn không có quyền truy cập', 403);
                return;
            }

            // Check if comment exists
            $checkSql = "SELECT id FROM comments WHERE id = ?";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([$commentId]);
            
            if (!$checkStmt->fetch()) {
                Response::error('Bình luận không tồn tại', 404);
                return;
            }

            // Restore comment
            $sql = "UPDATE comments SET is_active = TRUE WHERE id = ?";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$commentId]);

            Response::success(['message' => 'Đã khôi phục bình luận thành công']);

        } catch (Exception $e) {
            error_log("Error admin restoring comment: " . $e->getMessage());
            Response::error('Không thể khôi phục bình luận', 500);
        }
    }

    /**
     * Get comment statistics for admin dashboard
     * GET /comments/admin/stats
     */
    public function getCommentStats() {
        try {
            // Verify admin authentication
            $userId = $this->authService->getCurrentUserId();
            if (!$userId || !$this->authService->isAdmin($userId)) {
                Response::error('Bạn không có quyền truy cập', 403);
                return;
            }

            // Get various statistics
            $stats = [];

            // Total comments (active + inactive)
            $totalSql = "SELECT COUNT(*) as total FROM comments";
            $totalStmt = $this->db->prepare($totalSql);
            $totalStmt->execute();
            $stats['total_comments'] = $totalStmt->fetch(PDO::FETCH_ASSOC)['total'];

            // Active comments
            $activeSql = "SELECT COUNT(*) as active FROM comments WHERE is_active = TRUE";
            $activeStmt = $this->db->prepare($activeSql);
            $activeStmt->execute();
            $stats['active_comments'] = $activeStmt->fetch(PDO::FETCH_ASSOC)['active'];

            // Inactive comments  
            $inactiveSql = "SELECT COUNT(*) as inactive FROM comments WHERE is_active = FALSE";
            $inactiveStmt = $this->db->prepare($inactiveSql);
            $inactiveStmt->execute();
            $stats['inactive_comments'] = $inactiveStmt->fetch(PDO::FETCH_ASSOC)['inactive'];

            // Total unique users who commented
            $usersSql = "SELECT COUNT(DISTINCT user_id) as users FROM comments";
            $usersStmt = $this->db->prepare($usersSql);
            $usersStmt->execute();
            $stats['total_users'] = $usersStmt->fetch(PDO::FETCH_ASSOC)['users'];

            Response::success($stats);

        } catch (Exception $e) {
            error_log("Error getting comment stats: " . $e->getMessage());
            Response::error('Không thể lấy thống kê bình luận', 500);
        }
    }
}
?>