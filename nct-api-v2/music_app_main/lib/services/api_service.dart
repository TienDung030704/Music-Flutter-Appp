import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:music_app_main/models/song.dart';

class ApiService {
  // Cấu hình IP server - thay đổi IP này khi cần
  static const String _serverIP = '10.0.2.2';
  // Alternative IPs to try if main IP fails:
  // static const String _serverIP = '192.168.1.88';   // Previous IP
  // static const String _serverIP = '127.0.0.1';       // Localhost
  // static const String _serverIP = '10.0.2.2';        // Android emulator host

  static String get baseUrl {
    // Sử dụng IP thật của máy để connect từ emulator/device
    return 'http://$_serverIP/Music-App-Flutter/Music-App-Flutter/backend';
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      // Get songs from NCT API
      final url = '$baseUrl/songs/search?q=${Uri.encodeComponent(query)}';

      final response = await http.get(Uri.parse(url));

      List<Song> nctSongs = [];
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> songsList = jsonResponse['data']['songs'] ?? [];
          nctSongs = songsList.map((item) => Song.fromJson(item)).toList();
        }
      }

      // Get admin uploaded songs
      final adminSongs = await getAdminSongs(query);

      // Combine both lists (admin songs first for priority)
      final result = [...adminSongs, ...nctSongs];
      return result;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<Song>> getAdminSongs([String? query]) async {
    try {
      String url = '$baseUrl/admin/songs';
      if (query != null && query.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(query)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          final List<dynamic> songsList = jsonResponse['data'] ?? [];
          return songsList.map((item) {
            // Convert admin song format to Song model
            return Song(
              id: item['id'].toString(),
              title: item['title'] ?? '',
              artists: item['artist'] ?? '',
              album: item['album'] ?? '',
              artwork: item['thumbnail'],
              streamUrl: item['preview_url'] != null
                  ? '$baseUrl${item['preview_url']}'
                  : null,
              duration: item['duration_ms'] != null
                  ? Duration(milliseconds: item['duration_ms'])
                  : null,
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting admin songs: $e');
      return [];
    }
  }

  Future<Song> getSongDetail(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/songs/$id'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Song.fromJson(jsonResponse['data']['song']);
        } else {
          throw Exception(jsonResponse['error'] ?? 'Error fetching song');
        }
      } else {
        throw Exception('Failed to fetch song: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<String> getLyric(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/songs/$id/lyric'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          final lyric = jsonResponse['data']['lyric']?.toString();
          return lyric?.isNotEmpty == true ? lyric! : 'No lyrics available';
        } else {
          return 'No lyrics available';
        }
      } else {
        return 'Failed to fetch lyrics';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
