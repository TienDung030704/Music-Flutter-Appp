<?php

require_once __DIR__ . '/../database/Database.php';
require_once __DIR__ . '/../helpers/Response.php';

class LyricsController {
    private $db;
    
    public function __construct() {
        $this->db = new Database();
    }

    // Get lyrics for a song
    public function getLyrics() {
        try {
            $segments = explode('/', trim($_SERVER['REQUEST_URI'], '/'));
            $songId = end($segments);
            
            if (empty($songId)) {
                Response::error('Song ID is required', 400);
                return;
            }

            // Get lyrics from database
            $lyrics = $this->db->fetchOne(
                'SELECT * FROM song_lyrics WHERE song_id = :song_id',
                ['song_id' => $songId]
            );

            if ($lyrics) {
                Response::success([
                    'songId' => $songId,
                    'lyrics' => $lyrics,
                    'syncLyrics' => [],
                    'hasSync' => false,
                    'startTime' => $lyrics['lyrics_start_time'] ?? 15
                ]);
            } else {
                Response::success([
                    'songId' => $songId,
                    'lyrics' => null,
                    'syncLyrics' => [],
                    'hasSync' => false,
                    'message' => 'Lyrics not available'
                ]);
            }

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    // Admin: Add/Update lyrics for a song
    public function saveLyrics() {
        try {
            if (!$this->isAdmin()) {
                Response::error('Access denied', 403);
                return;
            }

            $input = json_decode(file_get_contents('php://input'), true);
            
            if (empty($input['songId']) || empty($input['songTitle'])) {
                Response::error('Song ID and title are required', 400);
                return;
            }

            $songId = $input['songId'];
            $songTitle = $input['songTitle'];
            $artistName = $input['artistName'] ?? '';
            $lyricsContent = $input['lyricsContent'] ?? '';
            $startTime = $input['startTime'] ?? 0;
            $syncLyrics = $input['syncLyrics'] ?? [];

            // Check if lyrics exist
            $existingLyrics = $this->db->fetchOne(
                'SELECT id FROM song_lyrics WHERE song_id = :song_id',
                ['song_id' => $songId]
            );

            if ($existingLyrics) {
                // Update existing lyrics
                $this->db->update(
                    'song_lyrics',
                    [
                        'song_title' => $songTitle,
                        'artist_name' => $artistName,
                        'lyrics_content' => $lyricsContent,
                        'lyrics_start_time' => $startTime,
                        'has_sync_lyrics' => false,
                        'updated_at' => date('Y-m-d H:i:s')
                    ],
                    'song_id = :song_id',
                    ['song_id' => $songId]
                );
            } else {
                // Insert new lyrics
                $this->db->insert('song_lyrics', [
                    'song_id' => $songId,
                    'song_title' => $songTitle,
                    'artist_name' => $artistName,
                    'lyrics_content' => $lyricsContent,
                    'lyrics_start_time' => $startTime,
                    'has_sync_lyrics' => false
                ]);
            }

            // No sync lyrics handling - removed

            Response::success([
                'message' => 'Lyrics saved successfully',
                'songId' => $songId
            ]);

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    // Admin: Delete lyrics for a song
    public function deleteLyrics() {
        try {
            if (!$this->isAdmin()) {
                Response::error('Access denied', 403);
                return;
            }

            $segments = explode('/', trim($_SERVER['REQUEST_URI'], '/'));
            $songId = end($segments);
            
            if (empty($songId)) {
                Response::error('Song ID is required', 400);
                return;
            }

            // Delete main lyrics
            $deleted = $this->db->delete('song_lyrics', 'song_id = :song_id', ['song_id' => $songId]);

            if ($deleted > 0) {
                Response::success(['message' => 'Lyrics deleted successfully']);
            } else {
                Response::error('Lyrics not found', 404);
            }

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    // Admin: Get all songs with lyrics for management
    public function getAllLyrics() {
        try {
            if (!$this->isAdmin()) {
                Response::error('Access denied', 403);
                return;
            }

            $page = $_GET['page'] ?? 1;
            $limit = $_GET['limit'] ?? 20;
            $offset = ($page - 1) * $limit;

            // Get all songs with lyrics status from admin_songs
            $songs = $this->db->fetchAll(
                'SELECT 
                    s.id as song_id, 
                    s.title as song_title, 
                    s.artist as artist_name, 
                    s.thumbnail as image_url,
                    s.stream_url as audio_url,
                    s.category,
                    sl.has_sync_lyrics, 
                    sl.created_at as lyrics_created_at, 
                    sl.updated_at as lyrics_updated_at,
                    CASE WHEN sl.song_id IS NOT NULL THEN 1 ELSE 0 END as has_lyrics
                 FROM admin_songs s
                 LEFT JOIN song_lyrics sl ON s.id = sl.song_id
                 ORDER BY s.title ASC 
                 LIMIT :limit OFFSET :offset',
                ['limit' => $limit, 'offset' => $offset]
            );

            $total = $this->db->fetchOne(
                'SELECT COUNT(*) as total FROM admin_songs'
            )['total'];

            Response::success([
                'lyrics' => $songs,
                'pagination' => [
                    'page' => (int)$page,
                    'limit' => (int)$limit,
                    'total' => (int)$total,
                    'totalPages' => ceil($total / $limit)
                ]
            ]);

        } catch (Exception $e) {
            Response::error('Server error: ' . $e->getMessage(), 500);
        }
    }

    private function isAdmin() {
        $user = $this->getCurrentUser();
        return $user && $user['role'] === 'admin';
    }

    private function getCurrentUser() {
        $token = $this->getBearerToken();
        if (!$token) return null;

        // Try session first
        $session = $this->db->fetchOne(
            'SELECT user_id FROM user_sessions WHERE session_token = :token AND expires_at > :current_time',
            ['token' => $token, 'current_time' => date('Y-m-d H:i:s')]
        );

        if ($session) {
            return $this->db->fetchOne(
                'SELECT * FROM users WHERE id = :id',
                ['id' => $session['user_id']]
            );
        }

        // Try auth token
        return $this->db->fetchOne(
            'SELECT * FROM users WHERE auth_token = :token AND token_expires_at > :current_time',
            ['token' => $token, 'current_time' => date('Y-m-d H:i:s')]
        );
    }

    private function getBearerToken() {
        $authHeader = '';
        
        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }
        
        if (empty($authHeader)) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        }
        
        if (empty($authHeader)) {
            $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        }
        
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
        
        return null;
    }


}