<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../services/AuthService.php';
require_once __DIR__ . '/../helpers/Response.php';

class NotificationController {
    private $db;
    private $authService;
    
    public function __construct() {
        $this->db = new Database();
        $this->authService = new AuthService();
    }
    
    // Get notifications for current user
    public function getNotifications() {
        try {
            $userId = $this->authService->getCurrentUserId();
            
            if (!$userId) {
                Response::error('Unauthorized', 401);
                return;
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $page = $input['page'] ?? 1;
            $limit = $input['limit'] ?? 20;
            $offset = ($page - 1) * $limit;
            
            // Get user info to check if admin
            $user = $this->db->fetchOne(
                'SELECT role FROM users WHERE id = ?',
                [$userId]
            );
            
            $isAdmin = $user['role'] === 'admin';
            
            // Build query based on user role
            if ($isAdmin) {
                // Admin receives notifications meant for admin or all
                $sql = "SELECT n.*, 
                           COALESCE(u.full_name, 'System') as sender_name,
                           u.avatar as sender_avatar
                        FROM notifications n 
                        LEFT JOIN users u ON n.sender_id = u.id 
                        WHERE (n.receiver_type = 'admin' OR n.receiver_type = 'all' OR n.receiver_id = ?) 
                        ORDER BY n.created_at DESC 
                        LIMIT ? OFFSET ?";
                $params = [$userId, $limit, $offset];
            } else {
                // Regular user receives notifications meant for them or all users
                $sql = "SELECT n.*, 
                           COALESCE(u.full_name, 'System') as sender_name,
                           u.avatar as sender_avatar
                        FROM notifications n 
                        LEFT JOIN users u ON n.sender_id = u.id 
                        WHERE (n.receiver_id = ? OR n.receiver_type = 'all') 
                        ORDER BY n.created_at DESC 
                        LIMIT ? OFFSET ?";
                $params = [$userId, $limit, $offset];
            }
            
            $notifications = $this->db->fetchAll($sql, $params);
            
            // Get total count for pagination
            if ($isAdmin) {
                $totalSql = "SELECT COUNT(*) as total FROM notifications 
                            WHERE (receiver_type = 'admin' OR receiver_type = 'all' OR receiver_id = ?)";
                $totalParams = [$userId];
            } else {
                $totalSql = "SELECT COUNT(*) as total FROM notifications 
                            WHERE (receiver_id = ? OR receiver_type = 'all')";
                $totalParams = [$userId];
            }
            
            $totalResult = $this->db->fetchOne($totalSql, $totalParams);
            $total = $totalResult['total'];
            
            // Parse JSON data
            foreach ($notifications as &$notification) {
                if ($notification['related_data']) {
                    $notification['related_data'] = json_decode($notification['related_data'], true);
                }
            }
            
            Response::success([
                'notifications' => $notifications,
                'pagination' => [
                    'current_page' => $page,
                    'total_pages' => ceil($total / $limit),
                    'total_items' => $total,
                    'per_page' => $limit
                ]
            ]);
            
        } catch (Exception $e) {
            error_log("Error getting notifications: " . $e->getMessage());
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }
    
    // Mark notification as read
    public function markAsRead() {
        try {
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Unauthorized', 401);
                return;
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $notificationId = $input['notification_id'] ?? null;
            
            if (!$notificationId) {
                Response::error('Notification ID is required', 400);
                return;
            }
            
            // Update notification as read
            $result = $this->db->update(
                'notifications',
                ['is_read' => true],
                'id = ? AND (receiver_id = ? OR receiver_type IN ("admin", "all"))',
                [$notificationId, $userId]
            );
            
            if ($result) {
                Response::success(['message' => 'Notification marked as read']);
            } else {
                Response::error('Notification not found or access denied', 404);
            }
            
        } catch (Exception $e) {
            error_log("Error marking notification as read: " . $e->getMessage());
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }
    
    // Mark all notifications as read
    public function markAllAsRead() {
        try {
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Unauthorized', 401);
                return;
            }
            
            // Get user info to check if admin
            $user = $this->db->fetchOne(
                'SELECT role FROM users WHERE id = ?',
                [$userId]
            );
            
            $isAdmin = $user['role'] === 'admin';
            
            if ($isAdmin) {
                // Mark all admin notifications as read
                $this->db->query(
                    'UPDATE notifications SET is_read = true 
                     WHERE (receiver_type = "admin" OR receiver_type = "all" OR receiver_id = ?)',
                    [$userId]
                );
            } else {
                // Mark all user notifications as read
                $this->db->query(
                    'UPDATE notifications SET is_read = true 
                     WHERE (receiver_id = ? OR receiver_type = "all")',
                    [$userId]
                );
            }
            
            Response::success(['message' => 'All notifications marked as read']);
            
        } catch (Exception $e) {
            error_log("Error marking all notifications as read: " . $e->getMessage());
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }
    
    // Get unread notifications count
    public function getUnreadCount() {
        try {
            $userId = $this->authService->getCurrentUserId();
            if (!$userId) {
                Response::error('Unauthorized', 401);
                return;
            }
            
            // Get user info to check if admin
            $user = $this->db->fetchOne(
                'SELECT role FROM users WHERE id = ?',
                [$userId]
            );
            
            $isAdmin = $user['role'] === 'admin';
            
            if ($isAdmin) {
                $result = $this->db->fetchOne(
                    'SELECT COUNT(*) as count FROM notifications 
                     WHERE is_read = false AND (receiver_type = "admin" OR receiver_type = "all" OR receiver_id = ?)',
                    [$userId]
                );
            } else {
                $result = $this->db->fetchOne(
                    'SELECT COUNT(*) as count FROM notifications 
                     WHERE is_read = false AND (receiver_id = ? OR receiver_type = "all")',
                    [$userId]
                );
            }
            
            Response::success(['unread_count' => (int)$result['count']]);
            
        } catch (Exception $e) {
            error_log("Error getting unread count: " . $e->getMessage());
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }
    
    // Create notification (used internally by other controllers)
    public static function createNotification($senderId, $receiverId, $receiverType, $type, $title, $message, $relatedData = null) {
        try {
            $db = new Database();
            
            $notificationData = [
                'sender_id' => $senderId,
                'receiver_id' => $receiverId,
                'receiver_type' => $receiverType,
                'notification_type' => $type,
                'title' => $title,
                'message' => $message,
                'related_data' => $relatedData ? json_encode($relatedData) : null
            ];
            
            return $db->insert('notifications', $notificationData);
            
        } catch (Exception $e) {
            error_log("Error creating notification: " . $e->getMessage());
            return false;
        }
    }
    
    // Send notification to all admins
    public static function notifyAdmins($senderId, $type, $title, $message, $relatedData = null) {
        try {
            $db = new Database();
            
            // Get all admin users
            $admins = $db->fetchAll(
                'SELECT id FROM users WHERE role = "admin" AND is_active = true'
            );
            
            $results = [];
            foreach ($admins as $admin) {
                $result = self::createNotification(
                    $senderId,
                    $admin['id'],
                    'admin',
                    $type,
                    $title,
                    $message,
                    $relatedData
                );
                $results[] = $result;
            }
            
            return !in_array(false, $results); // Return true if all notifications created successfully
            
        } catch (Exception $e) {
            error_log("Error notifying admins: " . $e->getMessage());
            return false;
        }
    }
    
    // Send notification to all users
    public static function notifyAllUsers($senderId, $type, $title, $message, $relatedData = null) {
        try {
            $db = new Database();
            
            // Create a single notification with receiver_type = 'all'
            return self::createNotification(
                $senderId,
                1, // dummy receiver_id (will be ignored due to receiver_type = 'all')
                'all',
                $type,
                $title,
                $message,
                $relatedData
            );
            
        } catch (Exception $e) {
            error_log("Error notifying all users: " . $e->getMessage());
            return false;
        }
    }
}