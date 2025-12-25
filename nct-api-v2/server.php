<?php

/**
 * Simple API Server Adapter for Music App
 * Wraps sdk.php to provide JSON endpoints for the Flutter App
 * Run with: php -S localhost:8000 server.php
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Disable error reporting to output to prevent HTML warnings breaking JSON
error_reporting(0);
ini_set('display_errors', 0);

require_once 'sdk.php';

$nct = new NCT();
$uri = $_SERVER['REQUEST_URI'];
$method = $_SERVER['REQUEST_METHOD'];

// Helper to parse duration string "mm:ss" to millis
function parseDurationToMillis($str)
{
    if (!$str) return 0;
    $parts = explode(':', $str);
    if (count($parts) == 2) {
        return ((int)$parts[0] * 60 + (int)$parts[1]) * 1000;
    }
    return 0;
}

// ROUTE: GET /songs/search?q={query}
if (strpos($uri, '/songs/search') === 0 && $method === 'GET') {
    $q = $_GET['q'] ?? '';
    if (empty($q)) {
        echo json_encode(['success' => false, 'error' => 'Missing query param q']);
        exit;
    }

    // getSongSearch returns raw JSON string from NCT API
    $rawResponse = $nct->getSongSearch($q);
    $json = json_decode($rawResponse, true);

    $songs = [];
    if (isset($json['Data']) && is_array($json['Data'])) {
        foreach ($json['Data'] as $item) {
            // Map NCT Search fields to App fields
            $songs[] = [
                'id' => $item['SongID'] ?? '',
                'title' => $item['SongTitle'] ?? '',
                'artists' => $item['Singer'] ?? '', // Note: NCT V1 usually uses 'Singer' or 'Artist'
                'album' => '',
                'thumbnail' => $item['SongImage'] ?? '',
                'durationMillis' => 0, // Search API might not return duration
                'streamUrl' => '' // Search API doesn't return stream link
            ];
        }
    }

    if (empty($songs)) {
        // Fallback: Try iTunes Search API
        $itunesUrl = "https://itunes.apple.com/search?term=" . urlencode($q) . "&entity=song&limit=20";
        $itunesRaw = @file_get_contents($itunesUrl);
        if ($itunesRaw) {
            $itunesJson = json_decode($itunesRaw, true);
            if (isset($itunesJson['results']) && is_array($itunesJson['results'])) {
                foreach ($itunesJson['results'] as $item) {
                    $songs[] = [
                        'id' => $item['trackId'] ?? '',
                        'title' => $item['trackName'] ?? '',
                        'artists' => $item['artistName'] ?? '',
                        'album' => $item['collectionName'] ?? '',
                        // Use larger 600x600 image
                        'thumbnail' => str_replace('100x100bb', '600x600bb', $item['artworkUrl100'] ?? ''),
                        'durationMillis' => $item['trackTimeMillis'] ?? 0,
                        'streamUrl' => $item['previewUrl'] ?? ''
                    ];
                }
            }
        }
    }

    // If still empty, use mock data
    if (empty($songs)) {
        // Choose appropriate mock file
        $mockFile = '';
        if (stripos($q, 'bolero') !== false) {
            $mockFile = __DIR__ . '/bolero_result.json';
        } elseif (stripos($q, 'remix') !== false) {
            $mockFile = __DIR__ . '/remix_result.json';
        } else {
            // Default to Son Tung data for V-Pop or others
            $mockFile = __DIR__ . '/../search_result.json';
        }

        if ($mockFile && file_exists($mockFile)) {
            $mockJson = json_decode(file_get_contents($mockFile), true);
            if (isset($mockJson['data']['songs'])) {
                $songs = $mockJson['data']['songs'];
            }
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'songs' => $songs
        ]
    ]);
    exit;
}

// ROUTE: GET /songs/{id}/lyric
if (preg_match('#^/songs/([^/]+)/lyric$#', $uri, $matches) && $method === 'GET') {
    $id = $matches[1];
    $lyricData = $nct->getLyric($id); // Returns array ["Lyric" => ..., "LyricWithTime" => ...]

    if ($lyricData && isset($lyricData['Lyric'])) {
        echo json_encode([
            'success' => true,
            'data' => [
                'lyric' => $lyricData['Lyric']
            ]
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Lyric not found']);
    }
    exit;
}

// ROUTE: GET /songs/{id}
if (preg_match('#^/songs/([^/]+)$#', $uri, $matches) && $method === 'GET') {
    $id = $matches[1];
    $data = $nct->getSongDetail($id); // Returns mapped array from sdk.php

    if (is_array($data) && isset($data['SongID'])) {
        $song = [
            'id' => $data['SongID'],
            'title' => $data['SongName'],
            'artists' => $data['SongSinger'],
            'album' => '',
            'thumbnail' => $data['SongThumbnail'],
            // Prioritize Download link (usually full song) over Stream link (often 30s preview for guests)
            'streamUrl' => !empty($data['SongDownload128']) ? $data['SongDownload128'] : $data['SongStreamLink'],
            // SDK getSongDetail maps "SongDuration" => $a[10]. Format is usually "03:45"
            'durationMillis' => parseDurationToMillis($data['SongDuration'] ?? '00:00')
        ];

        echo json_encode([
            'success' => true,
            'data' => [
                'song' => $song
            ]
        ]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Song not found or API error']);
    }
    exit;
}

// 404
echo json_encode(['success' => false, 'error' => 'Route not found']);
