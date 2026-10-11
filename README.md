<div align="center">

<img src="docs/images/logo.png" alt="SlipBoard" width="128" height="128">

# SlipBoard

**Trình quản lý clipboard nhanh, riêng tư, nằm gọn trên thanh menu macOS**

Nhấn phím tắt, chọn thứ bạn vừa sao chép, dán.

![Version](https://img.shields.io/badge/version-1.0-2ea44f)
![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Offline](https://img.shields.io/badge/m%E1%BA%A1ng-kh%C3%B4ng%20d%C3%B9ng-2ea44f)
[![License](https://img.shields.io/badge/license-MIT-2ea44f)](LICENSE)

[![Tiếng Việt](https://img.shields.io/badge/Language-Ti%E1%BA%BFng_Vi%E1%BB%87t-red)](README.md)
[![English](https://img.shields.io/badge/Language-English-green)](README.en.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/popup-vi-dark.png">
  <img src="docs/images/popup-vi-light.png" alt="Popup lịch sử clipboard của SlipBoard" width="900">
</picture>

</div>

---

## Giới thiệu

SlipBoard theo dõi clipboard của hệ thống và lưu lại một lịch sử có thể tìm
kiếm của mọi thứ bạn sao chép: văn bản, code, liên kết, màu sắc, hình ảnh, file
và văn bản có định dạng. Một phím tắt toàn cục mở popup với các mục **Đã ghim**
và **Gần đây**. Chọn một mục bằng bàn phím, SlipBoard sẽ dán nó vào ứng dụng bạn
vừa dùng.

### Vì sao chọn SlipBoard?

- **Riêng tư tuyệt đối:** không có code kết nối mạng, không analytics, không
  telemetry, không cần tài khoản.
- **Nhanh và gọn:** ứng dụng SwiftUI thuần, sống trên thanh menu, mở bằng một
  phím tắt.
- **Dán đúng cách bạn muốn:** dán nguyên bản, hoặc chuyển đổi ngay lúc dán
  (plain text, Markdown, bỏ dấu, chữ hoa, chữ thường).
- **Kiểm soát được:** loại trừ ứng dụng nhạy cảm, tạm dừng ghi, giới hạn thời
  gian lưu, khóa bằng Touch ID.

---

## Tính năng chính

### 1. Ghi lại mọi thứ bạn sao chép

- Nhận diện tự động **văn bản, văn bản có định dạng, code, URL, màu, hình ảnh
  và file**.
- Mỗi thẻ hiển thị **logo thật của ứng dụng nguồn** cùng tên và thời gian.
- Chân thẻ cho biết nhanh kích thước của nội dung:

| Loại | Chân thẻ hiển thị | Ví dụ |
| --- | --- | --- |
| Văn bản, code, URL, văn bản có định dạng | Số ký tự | `1.250 ký tự` |
| Hình ảnh | Kích thước điểm ảnh | `512x246` |
| File | Dung lượng (cộng dồn nếu nhiều file) | `2.5 MB` |

- Sao chép lại thứ đã có sẽ đưa nó lên đầu thay vì tạo bản trùng.
- Nội dung đến từ iPhone, iPad hoặc máy Mac khác qua Universal Clipboard
  (Handoff) được gắn nhãn riêng.

### 2. Tìm và sắp xếp

- Hai nhóm **Đã ghim** và **Gần đây**, kèm bộ lọc theo loại.
- Tìm kiếm toàn văn trên toàn bộ lịch sử: chỉ cần gõ khi popup đang mở.
- Gắn **ghi chú** cho từng mục và xếp vào các **bộ sưu tập** tùy chọn.

### 3. Dán theo ý bạn

| Cách dán | Kết quả |
| --- | --- |
| Nguyên bản | Dán đúng như đã sao chép |
| Plain text | Bỏ định dạng |
| Markdown | Đưa văn bản về dạng phù hợp với Markdown |
| Bỏ dấu Unicode | Bỏ dấu, chuẩn hóa ký tự đặc biệt |
| CHỮ HOA / chữ thường | Đổi kiểu chữ |

- Dán và đóng popup, hoặc dán và **giữ popup mở** để dán nhiều mục liên tiếp.
- **Snippet:** đoạn văn bản dùng lại, mỗi đoạn có phím tắt toàn cục riêng.

### 4. Kiểm soát những gì được ghi

- **Loại trừ ứng dụng** (ví dụ trình quản lý mật khẩu).
- **Tạm dừng ghi** trong 15 phút, 1 giờ, hoặc đến khi bạn bật lại.
- **Lưu giữ:** tối đa 2.000 mục, giữ 1 tuần, 2 tuần, 1 tháng, 3 tháng hoặc
  mãi mãi. Mục đã ghim không bao giờ bị dọn. Có thể xóa lịch sử khi thoát app.

### 5. Khóa ứng dụng (App Lock)

- Mở khóa bằng **Touch ID** hoặc mật khẩu hệ thống.
- Tự khóa sau 1 phút, 5 phút, 15 phút hoặc 1 giờ không hoạt động.
- Khi khóa, nội dung bị ẩn trong popup, kể cả độ dài và kích thước của từng
  thẻ; icon ứng dụng được thay bằng biểu tượng khóa.
- Tùy chọn ẩn bản xem trước trong Mission Control / Exposé.

### 6. Giao diện cho Mac

- Sáng, tối hoặc theo hệ thống; hiệu ứng **Liquid Glass** trên macOS 26, giao
  diện chuẩn trên các phiên bản trước.
- Giao diện **tiếng Việt** và **English**.
- Tùy chọn khởi động cùng máy, phím tắt toàn cục tùy chỉnh.

---

## Phím tắt

Phím tắt toàn cục mở popup từ bất kỳ đâu (mặc định **⌘⇧V**, đổi trong
Cài đặt → Phím tắt). Trong popup:

| Phím | Chức năng |
| --- | --- |
| `←` `→` / `↑` `↓` | Di chuyển giữa các mục |
| `Tab` / `⇧Tab` | Mục kế tiếp / trước đó |
| `↩` | Dán mục đang chọn và đóng popup |
| `⌥↩` | Dán và giữ popup mở |
| `⌘↩` | Mở menu **Dán dưới dạng** (plain text, Markdown, …) |
| `⌫` | Xóa mục đang chọn |
| *bất kỳ ký tự nào* | Bắt đầu tìm kiếm |
| `esc` | Đóng popup |

---

## Quyền riêng tư và bảo mật

- **Hoàn toàn offline.** SlipBoard không chứa code kết nối mạng, không analytics,
  không telemetry, không dịch vụ báo lỗi, không cần tài khoản.
- **Chỉ lưu trên máy.** Lịch sử, ghi chú, snippet và cài đặt nằm trong
  `~/Library/Application Support/SlipBoard/`.
- **App Lock mã hóa nội dung trên đĩa.** Khi bật, nội dung và ghi chú của từng
  mục được lưu mã hóa bằng khóa do Secure Enclave bảo vệ (Keychain là phương án
  dự phòng), mở khóa bằng Touch ID hoặc mật khẩu hệ thống.
- **Chỉ cần một quyền: Accessibility.** Dùng duy nhất để gửi phím ⌘V khi bạn
  chọn một mục. SlipBoard không ghi lại hay gửi đi các phím bạn gõ.

Chi tiết xem [PRIVACY.md](PRIVACY.md).

---

## Cài đặt

### Yêu cầu hệ thống

- **macOS 15** trở lên để chạy.
- **Xcode 26** để build. Dự án dùng API của SDK macOS 26 (Liquid Glass) sau các
  kiểm tra availability, dù vẫn chạy được từ macOS 15.

### Cài từ Release

Tải `SlipBoard.dmg` ở trang [Releases](../../releases), mở file và kéo
**SlipBoard** vào thư mục **Applications**. Lần đầu mở, cấp quyền
**Accessibility** khi được hỏi để SlipBoard dán được vào ứng dụng khác.

> [!NOTE]
> Các bản dựng hiện tại được ký bằng chứng chỉ phát triển (Apple Development),
> chưa notarize, và chỉ chạy trên những máy có trong provisioning profile của
> bản dựng đó. Nếu bản Release không mở được trên máy bạn, hãy build từ mã nguồn
> bên dưới.

### Build từ mã nguồn

**Build nhanh (không cần tài khoản Apple Developer)**: đây là lệnh CI đang chạy.

```bash
xcodebuild \
  -project SlipBoard.xcodeproj \
  -target SlipBoard \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Bản không ký chạy được, nhưng **không bật được App Lock**: lưu khóa bảo vệ cần
entitlement keychain mà chỉ bản có ký mới có.

**Build có ký (cần cho App Lock)**

1. Mở `SlipBoard.xcodeproj` trong Xcode, chọn target **SlipBoard**, vào
   **Signing & Capabilities** và chọn team của bạn. Đổi bundle identifier thành
   một giá trị bạn sở hữu.
2. Build, để Xcode tự tạo provisioning profile:

   ```bash
   xcodebuild \
     -project SlipBoard.xcodeproj \
     -scheme SlipBoard \
     -configuration Release \
     -allowProvisioningUpdates \
     build
   ```

   Cần profile vì `keychain-access-groups`
   ([`SlipBoard.entitlements`](SlipBoard.entitlements)) là entitlement bị hạn
   chế. Thiếu profile, build báo `No profiles for '<bundle id>' were found`.

### Đóng gói bản phát hành

Script `build_release.sh` build bản Release và đóng gói thành DMG:

```bash
./build_release.sh              # bản có ký (cần cho App Lock)
./build_release.sh --no-sign    # bản không ký, như CI
```

Kết quả nằm trong `Release/`: `SlipBoard.app`, `SlipBoard.dmg` và
`SlipBoard.dmg.sha256`. Có thể đặt `DEVELOPMENT_TEAM` và `NOTARY_PROFILE` trong
file `.env` (xem [`.env.example`](.env.example)). Notarize chỉ chạy khi app được
ký bằng chứng chỉ **Developer ID**.

Quy ước đặt tên khi phát hành: tag `v<phiên bản>-<yyyymmdd>`, tiêu đề
`SlipBoard v<phiên bản> (Build <yyyymmdd>)`, phần mô tả là mục **What's New**.

---

## Cách hoạt động

```mermaid
flowchart LR
    A[Pasteboard hệ thống] -->|quét mỗi 0,75 giây| B[Theo dõi pasteboard]
    B --> C[Phân loại nội dung]
    C --> D{Chính sách ghi<br/>app bị loại trừ hoặc đang tạm dừng?}
    D -->|cho phép| E[Kho lịch sử]
    D -->|bỏ qua| X[Loại bỏ]
    E --> F[(Core Data<br/>lịch sử và cài đặt)]
    E --> G[(SQLite FTS<br/>chỉ mục tìm kiếm)]
    E -.->|App Lock bật| K[(Kho mã hóa<br/>nội dung và ghi chú)]
    J[Khóa Secure Enclave] -.-> K
    E --> H[Projector]
    H --> I[Popup SwiftUI và thanh menu]
```

Ứng dụng là app SwiftUI trên thanh menu, với một panel AppKit cho popup. Kho
lịch sử là nguồn dữ liệu duy nhất; projector biến nó thành trạng thái view cho
popup, còn lưu trữ Core Data và chỉ mục toàn văn SQLite được đồng bộ từ đó. Khi
bật App Lock, nội dung và ghi chú của từng mục còn được ghi vào một kho mã hóa
với khóa do Secure Enclave giữ.

## Cấu trúc dự án

```text
SlipBoard/
├── Core/         Logic ứng dụng, mỗi mảng một thư mục
│   ├── ClipboardHistory/         theo dõi pasteboard, phân loại, kho, projector
│   ├── SearchNotesOrganization/  chỉ mục tìm kiếm, ghi chú, bộ sưu tập
│   ├── SecurityAppLock/          khóa Secure Enclave, kho mã hóa, trạng thái khóa
│   ├── RetentionSettings/        lưu trữ Core Data và dọn dẹp
│   ├── PasteActions/             dán và các kiểu chuyển đổi
│   ├── SnippetsHotkeys/          snippet và phím tắt toàn cục
│   ├── ExclusionsPause/          app bị loại trừ và hẹn giờ tạm dừng
│   └── Localization/             danh mục chuỗi English / Tiếng Việt
├── Models/       Kiểu dữ liệu dùng chung
├── UI/           View SwiftUI: popup, thanh menu, cài đặt, giao diện
└── SlipBoardApp.swift            điểm vào ứng dụng và kết nối runtime
Tools/
└── LocalizationHarness/          chương trình kiểm tra danh mục chuỗi
build_release.sh                  build và đóng gói DMG
design/                           tài liệu thiết kế
```

## Giới hạn đã biết

- Định dạng văn bản có định dạng chỉ được giữ khi ứng dụng đang chạy. Sau khi
  khởi động lại, mục đó vẫn còn trong lịch sử nhưng ở dạng văn bản thuần.
- Dung lượng file và kích thước ảnh được đọc khi hiển thị thẻ: nếu file đã bị
  di chuyển hoặc xóa thì chân thẻ để trống.

## Giấy phép

Phát hành theo giấy phép [MIT](LICENSE).
