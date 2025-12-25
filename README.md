# Music App (VinaTune) - Flutter & PHP Backend

Dự án ứng dụng nghe nhạc VinaTune bao gồm Backend (PHP API Adapter) và Frontend (Flutter App). Ứng dụng hỗ trợ tìm kiếm, phát nhạc, hiển thị lời bài hát và các danh mục nhạc thịnh hành.

## 📸 Minh Họa (Screenshots)

| **Màn hình chính (Home)** | **Trình phát nhạc (Player)** |
|:---:|:---:|
| <img src="/screenshots/home_nov_2025.png" width="300"> | <img src="/screenshots/player_nov_2025.png" width="300"> |

---

## 🛠 Yêu cầu hệ thống (Prerequisites)

Để chạy được dự án, bạn cần cài đặt các công cụ sau:

1.  **Flutter SDK**: [Hướng dẫn cài đặt](https://docs.flutter.dev/get-started/install) (Phiên bản 3.0 trở lên).
2.  **PHP**: Phiên bản 7.4 hoặc 8.x (Đã có sẵn trên macOS/Linux, Windows cần cài XAMPP hoặc PHP binary).
3.  **Git**: Để quản lý mã nguồn.
4.  **IDE**: VS Code (khuyên dùng) hoặc Android Studio.

---

## 🚀 Hướng dẫn cài đặt và chạy (Installation & Running)

Bạn cần chạy song song cả **Backend** và **Frontend** để ứng dụng hoạt động đầy đủ.

### Phần 1: Chạy Backend (API Server)

Backend đóng vai trò cầu nối (wrapper) lấy dữ liệu nhạc và cung cấp API RESTful cho ứng dụng.

**Bước 1:** Mở Terminal và đi vào thư mục gốc `nct-api-v2`:
```bash
cd /path/to/Music-App-Flutter/nct-api-v2
```

**Bước 2:** Khởi chạy server PHP (Lắng nghe mọi IP `0.0.0.0` tại cổng `8000`):
```bash
php -S 0.0.0.0:8000 server.php
```
> **Lưu ý:** Giữ cửa sổ terminal này chạy, không tắt nó trong quá trình sử dụng App.

### Phần 2: Chạy Frontend (Flutter App)

**Bước 1:** Mở một cửa sổ Terminal **mới**.

**Bước 2:** Đi vào thư mục ứng dụng Flutter:
```bash
cd /path/to/Music-App-Flutter/nct-api-v2/music_app_main
```

**Bước 3:** Cài đặt các thư viện phụ thuộc:
```bash
flutter pub get
```

**Bước 4:** Chạy ứng dụng trên Máy ảo (Simulator) hoặc Thiết bị thật:
```bash
flutter run
```
*   **iOS Simulator / Android Emulator**: Nên hoạt động ngay lập tức vì Backend đang chạy ở `0.0.0.0`.
*   **Thiết bị thật**: Đảm bảo điện thoại và máy tính cùng mạng Wifi.

---

## 📂 Cấu trúc thư mục (Project Structure)

```
nct-api-v2/                     # Thư mục gốc dự án
├── server.php                  # [Backend] Server chính, xử lý API request và Mock data fallback
├── sdk.php                     # [Backend] Thư viện lõi xử lý kết nối và lấy link nhạc
├── bolero_result.json          # [Data] Dữ liệu mẫu cho nhạc Bolero
├── remix_result.json           # [Data] Dữ liệu mẫu cho nhạc Remix
├── search_result.json          # [Data] Dữ liệu mẫu mặc định (Sơn Tùng M-TP)
├── screenshots/                # Chứa ảnh minh họa dự án
├── README.md                   # File hướng dẫn này
│
└── music_app_main/             # [Frontend] Source code Flutter
    ├── lib/
    │   ├── main.dart           # Điểm khởi chạy ứng dụng (Entry point)
    │   ├── theme/              # Cấu hình giao diện (Light/Dark mode, Colors)
    │   ├── models/             # Data Models (Song object)
    │   ├── services/           # Xử lý gọi API (ApiService) - Kết nối tới localhost:8000
    │   ├── screens/            # Các màn hình chính
    │   │   ├── home_screen.dart    # Màn hình trang chủ, tìm kiếm, danh mục
    │   │   └── player_screen.dart  # Màn hình phát nhạc full, điều khiển, lời bài hát
    │   └── widgets/            # Các widget tái sử dụng
    │       ├── mini_player.dart    # Thanh phát nhạc nhỏ ở dưới cùng
    │       └── song_tile.dart      # Item bài hát trong danh sách
    │
    ├── pubspec.yaml            # Quản lý thư viện Flutter (audioplayers, http...)
    ├── android/                # Code native Android
    └── ios/                    # Code native iOS
```

## 📝 Lưu ý quan trọng

*   **Dữ liệu**: Dự án sử dụng cơ chế **Fallback**. Nếu API gốc không trả về dữ liệu (do vấn đề bản quyền hoặc thay đổi từ nguồn thứ 3), hệ thống sẽ tự động chuyển sang sử dụng dữ liệu mẫu (JSON) chất lượng cao trong server để đảm bảo trải nghiệm người dùng không bị gián đoạn.
*   **Hình ảnh**: Sử dụng nguồn ảnh từ Unsplash để đảm bảo tính thẩm mỹ và không lỗi link.
*   **Âm thanh**: Link nhạc livestream có thể hết hạn, code có cơ chế tự động lấy link mới nhất khi phát.
