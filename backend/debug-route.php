<?php
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$segments = array_values(array_filter(explode('/', trim($uri, '/'))));

echo "Method: $method\n";
echo "URI: $uri\n";
echo "Segments: " . json_encode($segments) . "\n";

$commentIndex = array_search('comments', $segments);
echo "Comment index: $commentIndex\n";

if ($commentIndex !== false) {
    echo "Found comments at index $commentIndex\n";
    echo "Next segment: " . ($segments[$commentIndex + 1] ?? 'none') . "\n";
    echo "Third segment: " . ($segments[$commentIndex + 2] ?? 'none') . "\n";
} else {
    echo "Comments not found in segments\n";
}
?>