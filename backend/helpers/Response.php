<?php

class Response
{
    public static function json(array $payload, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE);
        exit;
    }

    public static function success(array $data = [], array $meta = [], int $status = 200): void
    {
        self::json(
            [
                'success' => true,
                'data' => $data,
                'meta' => $meta,
            ],
            $status
        );
    }

    public static function error(string $message, int $status = 400, array $meta = []): void
    {
        self::json(
            [
                'success' => false,
                'error' => $message,
                'meta' => $meta,
            ],
            $status
        );
    }
}
