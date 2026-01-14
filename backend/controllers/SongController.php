<?php

require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../sdk.php';

class SongController
{
    private NCT $sdk;

    public function __construct(NCT $sdk)
    {
        $this->sdk = $sdk;
    }

    public function search(?string $query): void
    {
        if ($query === null || trim($query) === '') {
            Response::error('Query parameter q is required', 422);
            return;
        }

        error_log("DEBUG SongController: Searching for: $query");

        $results = $this->sdk->getSongSearch($query, 1, 20);

        error_log(
            'DEBUG SongController: iTunes API returned ' .
            (is_array($results) ? count($results) : 'null') .
            ' results'
        );

        if (!is_array($results)) {
            error_log('DEBUG SongController: iTunes API failed, results not array');
            Response::error('Unable to search songs right now', 502);
            return;
        }

        $songs = $this->normalizeSearchResults($results);

        error_log(
            'DEBUG SongController: Normalized to ' .
            count($songs) .
            ' songs'
        );

        if (count($songs) > 0) {
            error_log(
                'DEBUG SongController: First song: ' .
                ($songs[0]['title'] ?? 'unknown')
            );
        }

        Response::success([
            'query' => $query,
            'total' => count($songs),
            'songs' => $songs,
        ]);
    }

    public function show(?string $id): void
    {
        if ($id === null || trim($id) === '') {
            Response::error('Song id is required', 422);
            return;
        }

        $detail = $this->sdk->getSongDetail($id);

        if (!$detail) {
            Response::error('Song not found', 404);
            return;
        }

        Response::success([
            'song' => $this->normalizeSongDetail($detail),
        ]);
    }

    public function lyric(?string $id): void
    {
        if ($id === null || trim($id) === '') {
            Response::error('Song id is required', 422);
            return;
        }

        $lyric = $this->sdk->getLyric($id);

        Response::success([
            'songId'  => $id,
            'lyric'   => $lyric['Lyric'] ?? 'Lyrics not available.',
            'creator' => $lyric['Creator'] ?? null,
        ]);
    }

    public function getTop(): void
    {
        $popularArtists = [
            'Sơn Tùng MTP',
            'Đen Vâu',
            'Hoàng Thuỳ Linh',
            'Chi Pu',
            'Erik',
        ];

        $topSongs = [];

        foreach ($popularArtists as $artist) {
            $results = $this->sdk->getSongSearch($artist, 1, 5);

            if (is_array($results)) {
                $songs    = $this->normalizeSearchResults($results);
                $topSongs = array_merge(
                    $topSongs,
                    array_slice($songs, 0, 2)
                );
            }

            if (count($topSongs) >= 20) {
                break;
            }
        }

        Response::success([
            'total' => count($topSongs),
            'songs' => array_slice($topSongs, 0, 20),
        ]);
    }

    private function normalizeSearchResults(array $items): array
    {
        $results = [];

        foreach ($items as $item) {
            $id    = $item['trackId'] ?? $item['collectionId'] ?? null;
            $title = $item['trackName'] ?? $item['collectionName'] ?? null;

            if (
                !$id ||
                !$title ||
                empty($item['previewUrl'])
            ) {
                continue;
            }

            $results[] = [
                'id'              => $id,
                'title'           => $title,
                'artists'         => $item['artistName'] ?? '',
                'album'           => $item['collectionName'] ?? '',
                'thumbnail'       => $this->formatArtwork(
                    $item['artworkUrl100']
                    ?? $item['artworkUrl60']
                    ?? null
                ),
                'durationMillis'  => $item['trackTimeMillis'] ?? null,
                'streamUrl'       => $item['previewUrl'] ?? null,
            ];
        }

        return $results;
    }

    private function normalizeSongDetail(array $detail): array
    {
        return [
            'id'             => $detail['trackId'] ?? null,
            'title'          => $detail['trackName']
                                ?? $detail['collectionName']
                                ?? null,
            'artists'        => $detail['artistName'] ?? null,
            'album'          => $detail['collectionName'] ?? null,
            'thumbnail'      => $this->formatArtwork(
                $detail['artworkUrl100']
                ?? $detail['artworkUrl60']
                ?? null
            ),
            'durationMillis' => $detail['trackTimeMillis'] ?? null,
            'streamUrl'      => $detail['previewUrl'] ?? null,
            'releaseDate'    => $detail['releaseDate'] ?? null,
            'genre'          => $detail['primaryGenreName'] ?? null,
        ];
    }

    private function formatArtwork(?string $url): ?string
    {
        if (!$url) {
            return null;
        }

        return preg_replace(
            '/(\d+)x(\d+)(bb)?\.([a-zA-Z]+)/',
            '512x512bb.$4',
            $url
        );
    }
}
