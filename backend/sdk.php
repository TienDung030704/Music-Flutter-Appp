<?php

class NCT
{
    private const ITUNES_BASE = 'https://itunes.apple.com';
    private const LYRICS_BASE = 'https://api.lyrics.ovh/v1/';

    public function getSongSearch(string $keyword, int $page = 1, int $size = 20): array
    {
        if (trim($keyword) === '') {
            return [];
        }

        $offset = max(0, ($page - 1) * $size);
        $params = http_build_query([
            'term' => $keyword,
            'media' => 'music',
            'entity' => 'song',
            'country' => 'us',
            'limit' => $size,
            'offset' => $offset,
        ]);

        $response = $this->request(self::ITUNES_BASE . '/search?' . $params);

        return $response['results'] ?? [];
    }

    public function getSongDetail(string $id): ?array
    {
        if (trim($id) === '') {
            return null;
        }

        $params = http_build_query(['id' => $id, 'entity' => 'song']);
        $response = $this->request(self::ITUNES_BASE . '/lookup?' . $params);
        $results = $response['results'] ?? [];

        return $results[0] ?? null;
    }

    public function getLyric(string $id): ?array
    {
        $detail = $this->getSongDetail($id);
        if (!$detail) {
            return null;
        }

        $artist = $detail['artistName'] ?? '';
        $title = $detail['trackName'] ?? '';
        if (!$artist || !$title) {
            return null;
        }

        $url = self::LYRICS_BASE . rawurlencode($artist) . '/' . rawurlencode($title);
        $response = $this->request($url, false);

        if (!$response || !isset($response['lyrics'])) {
            return null;
        }

        return [
            'Lyric' => $response['lyrics'],
            'Creator' => $artist,
        ];
    }

    private function request(string $url, bool $decodeJson = true): array|string|null
    {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 15);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);

        $raw = curl_exec($ch);

        if ($raw === false || $raw === null) {
            return null;
        }

        if (!$decodeJson) {
            return $raw;
        }

        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : null;
    }
}
