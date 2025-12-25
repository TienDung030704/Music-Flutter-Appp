-- KDT Music Database Schema
-- Created: 2025-12-12

CREATE DATABASE IF NOT EXISTS kdt_music 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE kdt_music;

-- Users table
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'user') DEFAULT 'user',
    avatar VARCHAR(255) DEFAULT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    date_of_birth DATE DEFAULT NULL,
    gender ENUM('male', 'female', 'other') DEFAULT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255) DEFAULT NULL,
    reset_token VARCHAR(255) DEFAULT NULL,
    reset_token_expires DATETIME DEFAULT NULL,
    auth_token VARCHAR(255) DEFAULT NULL,
    refresh_token VARCHAR(255) DEFAULT NULL,
    token_expires_at DATETIME DEFAULT NULL,
    last_login DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- User sessions table
CREATE TABLE user_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    device_info TEXT DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    expires_at DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_session_token (session_token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
);

-- User playlists table
CREATE TABLE playlists (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT NULL,
    cover_image VARCHAR(255) DEFAULT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    song_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);

-- Playlist songs table
CREATE TABLE playlist_songs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    playlist_id INT NOT NULL,
    song_id VARCHAR(50) NOT NULL,
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) DEFAULT NULL,
    thumbnail VARCHAR(255) DEFAULT NULL,
    duration INT DEFAULT NULL,
    position INT NOT NULL DEFAULT 0,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
    UNIQUE KEY unique_playlist_song (playlist_id, song_id),
    INDEX idx_playlist_id (playlist_id),
    INDEX idx_song_id (song_id),
    INDEX idx_position (position)
);

-- User favorites table
CREATE TABLE user_favorites (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    song_id VARCHAR(50) NOT NULL,
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) DEFAULT NULL,
    thumbnail VARCHAR(255) DEFAULT NULL,
    duration INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_song (user_id, song_id),
    INDEX idx_user_id (user_id),
    INDEX idx_song_id (song_id)
);



-- Insert default admin user
INSERT INTO users (full_name, email, password, role, is_active, is_verified) 
VALUES (
    'KDT Music Admin',
    'admin@kdtmusic.com',
    '$2y$12$rZ.9V1QN1h0JN0g0R1h0JN0g0R1h0JN0g0R1h0JN0g0R1h0JN0g0R1',  -- password: admin123
    'admin',
    TRUE,
    TRUE
);

-- Insert test user
INSERT INTO users (full_name, email, password, role, is_active, is_verified) 
VALUES (
    'Test User',
    'user@kdtmusic.com',
    '$2y$12$rZ.9V1QN1h0JN0g0R1h0JN0g0R1h0JN0g0R1h0JN0g0R1h0JN0g0R1',  -- password: user123
    'user',
    TRUE,
    TRUE
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);

-- Admin songs table for managing curated music
CREATE TABLE admin_songs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    itunes_id BIGINT UNIQUE,
    title VARCHAR(255) NOT NULL,
    artist VARCHAR(255) NOT NULL,
    thumbnail VARCHAR(500),
    category VARCHAR(100) NOT NULL,
    stream_url VARCHAR(500),
    duration INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_admin_songs_category (category),
    INDEX idx_admin_songs_itunes_id (itunes_id)
);

-- Song lyrics table
CREATE TABLE song_lyrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    song_id VARCHAR(50) NOT NULL,
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) DEFAULT NULL,
    lyrics_content LONGTEXT,
    has_sync_lyrics BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_song_lyrics (song_id),
    INDEX idx_song_id (song_id),
    INDEX idx_has_sync_lyrics (has_sync_lyrics)
);

-- Synchronized lyrics table (for time-synced lyrics)
CREATE TABLE sync_lyrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    song_id VARCHAR(50) NOT NULL,
    start_time INT NOT NULL, -- in milliseconds
    end_time INT NOT NULL,   -- in milliseconds
    text TEXT NOT NULL,
    line_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (song_id) REFERENCES song_lyrics(song_id) ON DELETE CASCADE,
    INDEX idx_song_id (song_id),
    INDEX idx_start_time (start_time),
    INDEX idx_line_order (line_order)
);

-- Insert sample lyrics for testing
INSERT INTO song_lyrics (song_id, song_title, artist_name, lyrics_content, has_sync_lyrics) VALUES
('sample1', 'Chúng Ta Là Gì Đây', 'Khả Hiệp', 
'Gọi chúng ta là gì đây
Là người dưng hay
người yêu đã từng

Để trái tim ngừng tồn
thương', TRUE);

-- Insert sample synchronized lyrics
INSERT INTO sync_lyrics (song_id, start_time, end_time, text, line_order) VALUES
('sample1', 0, 3000, 'Gọi chúng ta là gì đây', 1),
('sample1', 3000, 6000, 'Là người dưng hay', 2),
('sample1', 6000, 9000, 'người yêu đã từng', 3),
('sample1', 12000, 15000, 'Để trái tim ngừng tồn', 4),
('sample1', 15000, 18000, 'thương', 5);

-- Listening history table
CREATE TABLE listening_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    song_type ENUM('admin', 'itunes') NOT NULL,
    song_id VARCHAR(255) NOT NULL, -- For iTunes: trackId, For admin: admin_songs.id
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) NOT NULL,
    thumbnail VARCHAR(500),
    listened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    listen_date DATE NOT NULL, -- For grouping by day
    duration_listened INT DEFAULT 0, -- in seconds
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id_date (user_id, listen_date),
    INDEX idx_listened_at (listened_at),
    INDEX idx_song_type (song_type)
);

-- Comments table for song comments
CREATE TABLE comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    song_type ENUM('admin', 'itunes') NOT NULL,
    song_id VARCHAR(255) NOT NULL, -- For iTunes: trackId, For admin: admin_songs.id
    song_title VARCHAR(255) NOT NULL, -- Store for easy display
    artist_name VARCHAR(255) NOT NULL, -- Store for easy display
    comment_text TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE, -- For soft delete by admin
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_song_type_id (song_type, song_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_is_active (is_active)
);

-- Insert sample comments for testing
INSERT INTO comments (user_id, song_type, song_id, song_title, artist_name, comment_text) VALUES
(1, 'admin', '9', 'Buông Đôi Tay Nhau Ra', 'Sơn Tùng M-TP', 'Bài hát hay quá! Nghe hoài không chán.'),
(1, 'admin', '9', 'Buông Đôi Tay Nhau Ra', 'Sơn Tùng M-TP', 'MV này cảm động quá 😍'),
(1, 'admin', '8', 'NGÁO NGƠ', 'Sơn Tùng M-TP', 'Beat cực chất, lyrics ý nghĩa!'),
(1, 'itunes', '1440929969', 'Test iTunes Song', 'Test Artist', 'Bài này từ iTunes cũng hay nè!');

-- Song plays table for tracking play counts
CREATE TABLE song_plays (
    id INT AUTO_INCREMENT PRIMARY KEY,
    song_type ENUM('admin', 'itunes') NOT NULL,
    song_id VARCHAR(255) NOT NULL, -- For iTunes: trackId, For admin: admin_songs.id
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) NOT NULL,
    play_count INT NOT NULL DEFAULT 0,
    last_played_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_song (song_type, song_id),
    INDEX idx_play_count (play_count DESC),
    INDEX idx_song_type_id (song_type, song_id),
    INDEX idx_last_played_at (last_played_at)
);

-- User play sessions table for tracking individual user listening sessions
CREATE TABLE user_play_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    song_type ENUM('admin', 'itunes') NOT NULL,
    song_id VARCHAR(255) NOT NULL,
    session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_end TIMESTAMP NULL,
    play_duration INT DEFAULT 0, -- in seconds
    counted_as_play BOOLEAN DEFAULT FALSE, -- TRUE if listened >= 10 seconds
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_song_type_id (song_type, song_id),
    INDEX idx_counted_as_play (counted_as_play),
    INDEX idx_session_start (session_start)
);

-- Insert sample play data for testing
INSERT INTO song_plays (song_type, song_id, song_title, artist_name, play_count, last_played_at) VALUES
('admin', '9', 'Buông Đôi Tay Nhau Ra', 'Sơn Tùng M-TP', 1250, NOW()),
('admin', '8', 'NGÁO NGƠ', 'Sơn Tùng M-TP', 890, NOW()),
('admin', '7', 'Có Chắc Yêu Là Đây', 'Sơn Tùng M-TP', 670, NOW()),
('itunes', '1440929969', 'Test iTunes Song', 'Test Artist', 45, NOW());

-- Downloaded songs table
CREATE TABLE downloads (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    song_type VARCHAR(50) NOT NULL, -- 'admin' or 'itunes'
    song_id VARCHAR(255) NOT NULL,
    song_title VARCHAR(255) NOT NULL,
    artist_name VARCHAR(255) NOT NULL,
    artwork_url TEXT DEFAULT NULL,
    download_url TEXT DEFAULT NULL,
    file_size BIGINT DEFAULT NULL, -- in bytes
    duration INT DEFAULT NULL, -- in seconds
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_downloads (user_id),
    INDEX idx_song_lookup (song_type, song_id),
    UNIQUE KEY unique_user_song (user_id, song_type, song_id)
);

-- Notifications table for admin and user notifications
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sender_id INT NULL, -- User who triggered the notification (NULL for system notifications)
    receiver_id INT NOT NULL, -- User who receives the notification
    receiver_type ENUM('admin', 'user', 'all') DEFAULT 'user', -- Who should receive this notification
    notification_type ENUM('comment', 'listening', 'download', 'new_song', 'new_user', 'system') NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    related_data JSON NULL, -- Store related info like song_id, comment_id, etc.
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_receiver_type (receiver_id, receiver_type),
    INDEX idx_notification_type (notification_type),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at DESC)
);

-- Insert sample notifications for testing
INSERT INTO notifications (sender_id, receiver_id, receiver_type, notification_type, title, message, related_data) VALUES
(2, 1, 'admin', 'comment', 'Bình luận mới', 'Test User đã bình luận bài hát "Buông Đôi Tay Nhau Ra"', '{"song_id": "9", "song_title": "Buông Đôi Tay Nhau Ra", "artist": "Sơn Tùng M-TP", "comment_text": "Bài hát hay quá!"}'),
(2, 1, 'admin', 'listening', 'Lượt nghe mới', 'Test User đã nghe bài hát "NGÁO NGƠ"', '{"song_id": "8", "song_title": "NGÁO NGƠ", "artist": "Sơn Tùng M-TP"}'),
(1, 2, 'user', 'new_song', 'Bài hát mới', 'Admin đã thêm bài hát mới: "Chúng Ta Của Hiện Tại"', '{"song_id": "10", "song_title": "Chúng Ta Của Hiện Tại", "artist": "Sơn Tùng M-TP"}');

