<?php
error_reporting(E_ALL & ~E_DEPRECATED & ~E_WARNING);
ini_set('display_errors', '0');

// Enable CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/sdk.php';
require_once __DIR__ . '/controllers/SongController.php';
require_once __DIR__ . '/controllers/AuthController.php';
require_once __DIR__ . '/controllers/PlaylistController.php';
require_once __DIR__ . '/controllers/FavoritesController.php';
require_once __DIR__ . '/controllers/AdminController.php';
require_once __DIR__ . '/controllers/LyricsController.php';
require_once __DIR__ . '/controllers/ListeningHistoryController.php';
require_once __DIR__ . '/controllers/HistoryController.php';
require_once __DIR__ . '/controllers/CommentController.php';
require_once __DIR__ . '/controllers/PlayController.php';
require_once __DIR__ . '/controllers/DownloadController.php';
require_once __DIR__ . '/controllers/NotificationController.php';


require_once __DIR__ . '/helpers/Response.php';

// Store raw input globally so it can be reused
$GLOBALS['raw_input'] = file_get_contents('php://input');
$GLOBALS['request_data'] = json_decode($GLOBALS['raw_input'], true);

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$segments = array_values(array_filter(explode('/', trim($uri, '/'))));

try {
    // Find auth segment index
    $authIndex = array_search('auth', $segments);
    
    // Authentication routes
    if ($method === 'POST' && $authIndex !== false) {
        $authController = new AuthController();
        
        switch ($segments[$authIndex + 1] ?? '') {
            case 'register':
                $authController->register();
                break;
            case 'login':
                $authController->login();
                break;
            case 'logout':
                $authController->logout();
                break;
            case 'refresh-token':
                $authController->refreshToken();
                break;
            case 'forgot-password':
                $authController->forgotPassword();
                break;
            case 'reset-password':
                $authController->resetPassword();
                break;
            case 'change-password':
                $authController->changePassword();
                break;
            default:
                Response::error('Route không tồn tại', 404);
        }
    }
    
    // Profile routes
    $profileIndex = array_search('profile', $segments);
    if ($profileIndex !== false) {
        $authController = new AuthController();
        
        if ($method === 'GET') {
            $authController->getProfile();
        } elseif ($method === 'PUT') {
            $authController->updateProfile();
        } else {
            Response::error('Method không được hỗ trợ', 405);
        }
    }

    // Playlist routes
    $playlistIndex = array_search('playlists', $segments);
    if ($playlistIndex !== false) {
        $playlistController = new PlaylistController();
        
        if ($method === 'GET') {
            if (isset($segments[$playlistIndex + 1]) && $segments[$playlistIndex + 1] === 'test') {
                // Test endpoint: GET /playlists/test
                $playlistController->test();
            } elseif (isset($segments[$playlistIndex + 1]) && $segments[$playlistIndex + 1] === 'test-auth') {
                // Test auth endpoint: GET /playlists/test-auth
                $playlistController->testAuth();
            } elseif (isset($segments[$playlistIndex + 1])) {
                // Get playlist details: GET /playlists/{id}
                $playlistController->getPlaylist($segments[$playlistIndex + 1]);
            } else {
                // Get user playlists: GET /playlists
                $playlistController->getUserPlaylists();
            }
        } elseif ($method === 'POST') {
            if (isset($segments[$playlistIndex + 1]) && isset($segments[$playlistIndex + 2]) && $segments[$playlistIndex + 2] === 'songs') {
                // Add song to playlist: POST /playlists/{id}/songs
                $playlistController->addSong($segments[$playlistIndex + 1]);
            } else {
                // Create playlist: POST /playlists
                $playlistController->create();
            }
        } elseif ($method === 'DELETE') {
            if (isset($segments[$playlistIndex + 1]) && isset($segments[$playlistIndex + 2]) && $segments[$playlistIndex + 2] === 'songs' && isset($segments[$playlistIndex + 3])) {
                // Remove song from playlist: DELETE /playlists/{id}/songs/{songId}
                $playlistController->removeSong($segments[$playlistIndex + 1], $segments[$playlistIndex + 3]);
            } elseif (isset($segments[$playlistIndex + 1])) {
                // Delete playlist: DELETE /playlists/{id}
                $playlistController->delete($segments[$playlistIndex + 1]);
            } else {
                Response::error('Method không được hỗ trợ', 405);
            }
        } else {
            Response::error('Method không được hỗ trợ', 405);
        }
    }
    
    // Favorites routes
    $favoritesIndex = array_search('favorites', $segments);
    if ($favoritesIndex !== false) {
        $favoritesController = new FavoritesController();
        
        if ($method === 'GET') {
            if (isset($segments[$favoritesIndex + 1])) {
                // Check favorite status: GET /favorites/{songId}
                $favoritesController->checkFavoriteStatus($segments[$favoritesIndex + 1]);
            } else {
                // Get user favorites: GET /favorites
                $favoritesController->getUserFavorites();
            }
        } elseif ($method === 'POST') {
            // Add to favorites: POST /favorites
            $favoritesController->addToFavorites();
        } elseif ($method === 'DELETE' && isset($segments[$favoritesIndex + 1])) {
            // Remove from favorites: DELETE /favorites/{songId}
            $favoritesController->removeFromFavorites($segments[$favoritesIndex + 1]);
        } else {
            Response::error('Method không được hỗ trợ', 405);
        }
    }
    
    // Admin routes (but not /comments/admin/...)
    $adminIndex = array_search('admin', $segments);
    if ($adminIndex !== false && ($adminIndex === 0 || $segments[$adminIndex - 1] !== 'comments')) {
        $adminController = new AdminController();
        
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'songs') {
            if ($method === 'POST') {
                $adminController->createSong();
                return;
            } elseif ($method === 'GET') {
                $adminController->getSongsByCategory();
                return;
            } elseif ($method === 'PUT' && isset($segments[$adminIndex + 2])) {
                $adminController->updateSong($segments[$adminIndex + 2]);
                return;
            } elseif ($method === 'DELETE' && isset($segments[$adminIndex + 2])) {
                $adminController->deleteSong($segments[$adminIndex + 2]);
                return;
            }
        }
        
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'stats' && $method === 'GET') {
            $adminController->getStats();
            return;
        }
        
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'sync' && $method === 'POST') {
            $adminController->syncFromItunes();
            return;
        }
        
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'upload' && $method === 'POST') {
            $adminController->uploadSong();
            return;
        }
        
        // User management routes
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'users') {
            if ($method === 'GET') {
                $adminController->getUsers();
                return;
            } elseif ($method === 'POST') {
                $adminController->createUser();
                return;
            } elseif ($method === 'PUT' && isset($segments[$adminIndex + 2])) {
                if (isset($segments[$adminIndex + 3]) && $segments[$adminIndex + 3] === 'toggle-status') {
                    $adminController->toggleUserStatus($segments[$adminIndex + 2]);
                    return;
                }
                $adminController->updateUser($segments[$adminIndex + 2]);
                return;
            } elseif ($method === 'DELETE' && isset($segments[$adminIndex + 2])) {
                $adminController->deleteUser($segments[$adminIndex + 2]);
                return;
            }
        }
        
        if (isset($segments[$adminIndex + 1]) && $segments[$adminIndex + 1] === 'user-stats' && $method === 'GET') {
            $adminController->getUserStats();
            return;
        }
    }

    // Lyrics routes
    $lyricsIndex = array_search('lyrics', $segments);
    if ($lyricsIndex !== false) {
        $lyricsController = new LyricsController();
        
        if ($method === 'GET') {
            if (isset($segments[$lyricsIndex + 1]) && $segments[$lyricsIndex + 1] === 'admin') {
                // Admin: Get all lyrics - GET /lyrics/admin
                $lyricsController->getAllLyrics();
            } else {
                // Get lyrics for a song - GET /lyrics/{songId}
                $lyricsController->getLyrics();
            }
        } elseif ($method === 'POST') {
            // Admin: Save lyrics - POST /lyrics
            $lyricsController->saveLyrics();
        } elseif ($method === 'DELETE') {
            // Admin: Delete lyrics - DELETE /lyrics/{songId}
            $lyricsController->deleteLyrics();
        } else {
            Response::error('Method not supported', 405);
        }
        return;
    }

    // Listening history routes: /listening-history/*
    if (isset($segments[3]) && $segments[3] === 'listening-history') {
        $historyController = new ListeningHistoryController();
        
        if ($method === 'POST' && isset($segments[4]) && $segments[4] === 'add') {
            // Add listening history: POST /listening-history/add
            $historyController->addListeningHistory();
        } elseif ($method === 'GET' && isset($segments[4]) && $segments[4] === 'by-date') {
            // Get history by date: GET /listening-history/by-date?date=YYYY-MM-DD
            $historyController->getListeningHistoryByDate();
        } elseif ($method === 'GET' && isset($segments[4]) && $segments[4] === 'recent') {
            // Get recent history: GET /listening-history/recent
            $historyController->getRecentListeningHistory();
        } elseif ($method === 'GET' && isset($segments[4]) && $segments[4] === 'stats') {
            // Get listening stats: GET /listening-history/stats
            $historyController->getListeningStats();
        } elseif ($method === 'DELETE' && isset($segments[4]) && $segments[4] === 'clear') {
            // Clear history: DELETE /listening-history/clear
            $historyController->clearListeningHistory();
        } 
        // Test routes (no authentication required)
        elseif ($method === 'GET' && isset($segments[4]) && $segments[4] === 'test-recent') {
            // Test recent history: GET /listening-history/test-recent?user_id=1
            $historyController->testGetRecentHistory();
        } elseif ($method === 'GET' && isset($segments[4]) && $segments[4] === 'test-by-date') {
            // Test history by date: GET /listening-history/test-by-date?date=YYYY-MM-DD&user_id=1
            $historyController->testGetHistoryByDate();
        } elseif ($method === 'POST' && isset($segments[4]) && $segments[4] === 'test-add') {
            // Test add history: POST /listening-history/test-add
            $historyController->testAddHistory();
        } else {
            Response::error('Route không tồn tại', 404);
        }
        return;
    }

    // Comments routes
    $commentIndex = array_search('comments', $segments);
    if ($commentIndex !== false) {
        error_log("DEBUG: Found comments route, index=$commentIndex, segments=" . json_encode($segments));
        $commentController = new CommentController();
        
        if ($method === 'POST' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'add') {
            // Add comment: POST /comments/add
            $commentController->addComment();
        } elseif ($method === 'GET' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'song') {
            // Get comments by song: GET /comments/song?song_type=admin&song_id=123
            $commentController->getCommentsBySong();
        } elseif ($method === 'PUT' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'update' && isset($segments[$commentIndex + 2])) {
            // Update comment: PUT /comments/update/{id}
            $commentController->updateComment($segments[$commentIndex + 2]);
        } elseif ($method === 'DELETE' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'delete' && isset($segments[$commentIndex + 2])) {
            // Delete comment: DELETE /comments/delete/{id}
            $commentController->deleteComment($segments[$commentIndex + 2]);
        } 
        // Admin routes
        elseif ($method === 'GET' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'admin' && isset($segments[$commentIndex + 2])) {
            if ($segments[$commentIndex + 2] === 'list') {
                // Admin: Get all comments: GET /comments/admin/list
                $commentController->getCommentsForAdmin();
            } elseif ($segments[$commentIndex + 2] === 'stats') {
                // Admin: Get comment stats: GET /comments/admin/stats
                error_log("DEBUG: Calling getCommentStats()");
                $commentController->getCommentStats();
            } else {
                Response::error('Route không tồn tại', 404);
            }
        } elseif ($method === 'DELETE' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'admin' && isset($segments[$commentIndex + 2]) && $segments[$commentIndex + 2] === 'delete' && isset($segments[$commentIndex + 3])) {
            // Admin delete comment: DELETE /comments/admin/delete/{id}
            $commentController->adminDeleteComment($segments[$commentIndex + 3]);
        } elseif ($method === 'PUT' && isset($segments[$commentIndex + 1]) && $segments[$commentIndex + 1] === 'admin' && isset($segments[$commentIndex + 2]) && $segments[$commentIndex + 2] === 'restore' && isset($segments[$commentIndex + 3])) {
            // Admin restore comment: PUT /comments/admin/restore/{id}
            $commentController->adminRestoreComment($segments[$commentIndex + 3]);
        } else {
            Response::error('Route không tồn tại', 404);
        }
        return;
    }

    // Play tracking routes
    $playIndex = array_search('play', $segments);
    if ($playIndex !== false) {
        $playController = new PlayController();
        
        if ($method === 'POST' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'start-session') {
            // Start play session: POST /play/start-session
            $playController->startPlaySession();
        } elseif ($method === 'POST' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'end-session') {
            // End play session: POST /play/end-session
            $playController->endPlaySession();
        } elseif ($method === 'GET' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'count' 
                  && isset($segments[$playIndex + 2]) && isset($segments[$playIndex + 3])) {
            // Get single play count: GET /play/count/{song_type}/{song_id}
            $playController->getPlayCount($segments[$playIndex + 2], $segments[$playIndex + 3]);
        } elseif ($method === 'POST' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'counts') {
            // Get multiple play counts: POST /play/counts
            $playController->getPlayCounts();
        } elseif ($method === 'GET' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'top-songs') {
            // Get top played songs (Admin): GET /play/top-songs
            $playController->getTopPlayedSongs();
        } elseif ($method === 'GET' && isset($segments[$playIndex + 1]) && $segments[$playIndex + 1] === 'statistics') {
            // Get play statistics (Admin): GET /play/statistics
            $playController->getPlayStatistics();
        } else {
            Response::error('Route không tồn tại', 404);
        }
        return;
    }



    // Music routes (existing)
    if ($method === 'GET' && isset($segments[3]) && $segments[3] === 'songs') {
        $sdk = new NCT();
        $controller = new SongController($sdk);
        
        if (isset($segments[4]) && $segments[4] === 'search') {
            $controller->search($_GET['q'] ?? null);
            return;
        }
        
        if (isset($segments[4]) && $segments[4] === 'top') {
            $controller->getTop();
            return;
        }

        $songId = $segments[4] ?? null;
        if ($songId) {
            if (isset($segments[5]) && $segments[5] === 'lyric') {
                $controller->lyric($songId);
                return;
            }

            $controller->show($songId);
            return;
        }
    }

    
    // API routes: /api/*
    if (isset($segments[3]) && $segments[3] === 'api') {
        // Test route
        if (isset($segments[4]) && $segments[4] === 'test') {
            Response::success(['message' => 'API routing works!']);
            return;
        }
        
        // Notification routes: /api/notifications/*
        if (isset($segments[4]) && $segments[4] === 'notifications') {
            $controller = new NotificationController();
            
            if ($method === 'POST') {
                if (isset($segments[5]) && $segments[5] === 'mark-read') {
                    // POST /api/notifications/mark-read - Mark notification as read
                    $controller->markAsRead();
                    return;
                }
                
                if (isset($segments[5]) && $segments[5] === 'mark-all-read') {
                    // POST /api/notifications/mark-all-read - Mark all notifications as read
                    $controller->markAllAsRead();
                    return;
                }
                
                // POST /api/notifications - Get notifications (with pagination)
                $controller->getNotifications();
                return;
            }
            
            if ($method === 'GET') {
                if (isset($segments[5]) && $segments[5] === 'unread-count') {
                    // GET /api/notifications/unread-count - Get unread notifications count
                    $controller->getUnreadCount();
                    return;
                }
                
                // GET /api/notifications - Get notifications
                $controller->getNotifications();
                return;
            }
        }

        // Download routes: /api/downloads/*
        if (isset($segments[4]) && $segments[4] === 'downloads') {
            $controller = new DownloadController();
            
            if ($method === 'POST') {
                // POST /api/downloads - Add a download
                $controller->addDownload();
                return;
            }
            
            if ($method === 'GET') {
                if (isset($segments[5]) && $segments[5] === 'check') {
                    // GET /api/downloads/check?song_type=nct&song_id=123 - Check if downloaded
                    $controller->checkDownload();
                    return;
                }
                
                // GET /api/downloads - Get user's downloads
                $controller->getDownloads();
                return;
            }
            
            if ($method === 'DELETE' && isset($segments[5])) {
                // DELETE /api/downloads/{id} - Remove a download
                $controller->removeDownload($segments[5]);
                return;
            }
        }
    }
} catch (Throwable $e) {
    Response::error('Unexpected server error', 500, ['message' => $e->getMessage()]);
}

Response::error('Route not found', 404);
