<?php

// 1. Load valid streams from Son Tung data
$sourceData = json_decode(file_get_contents(__DIR__ . '/../search_result.json'), true);
$validStreams = [];
foreach ($sourceData['data']['songs'] as $song) {
    if (!empty($song['streamUrl'])) {
        $validStreams[] = $song['streamUrl'];
    }
}

// Helper to update a file
function updateFile($filename, $streams)
{
    if (!file_exists($filename)) return;
    $data = json_decode(file_get_contents($filename), true);
    if (!isset($data['data']['songs'])) return;

    foreach ($data['data']['songs'] as $k => &$song) {
        // Assign a valid stream URL (round robin)
        $streamIndex = $k % count($streams);
        $song['streamUrl'] = $streams[$streamIndex];

        // Ensure thumbnail is valid (Unsplash)
        if (strpos($song['thumbnail'], 'unsplash') === false) {
            $song['thumbnail'] = 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?auto=format&fit=crop&w=300&q=80';
        }
    }
    file_put_contents($filename, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
}

// 2. Update Bolero and Remix
updateFile('bolero_result.json', array_slice($validStreams, 0, 10));
updateFile('remix_result.json', array_slice($validStreams, 10, 10)); // Use different set if possible

echo "Fixed data files with valid streams.\n";
