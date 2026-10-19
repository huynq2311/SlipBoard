<div align="center">

<img src="docs/images/logo.png" alt="SlipBoard" width="128" height="128">

# SlipBoard

**Trình quản lý clipboard nhanh, riêng tư, nằm gọn trên thanh menu macOS**

Nhấn phím tắt, chọn thứ bạn vừa sao chép, dán.

![Version](https://img.shields.io/badge/version-1.0-2ea44f)
![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Offline](https://img.shields.io/badge/m%E1%BA%A1ng-ch%E1%BB%89%20ki%E1%BB%83m%20tra%20c%E1%BA%ADp%20nh%E1%BA%ADt-2ea44f)
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

- **Riêng tư:** không analytics, không telemetry, không cần tài khoản. Kết nối
  mạng duy nhất là kiểm tra cập nhật.
- **Nhanh và gọn:** ứng dụng SwiftUI thuần, sống trên thanh menu, mở bằng một
  phím tắt.
- **Dán đúng cách bạn muốn:** dán nguyên bản, hoặc chuyển đổi ngay lúc dán
  (plain text, Markdown, bỏ dấu, chữ hoa, chữ thường).
- **Kiểm soát được:** loại trừ ứng dụng nhạy cảm, tạm dừng ghi, giới hạn thời
  gian lưu, khóa bằng Touch ID.

---

## Điểm nổi bật

### Tất cả trên một hàng

Ô tìm kiếm, menu **Nguồn** và các bộ lọc theo loại nằm chung một hàng phía trên
hai hàng thẻ **Đã ghim** và **Gần đây**. Mỗi thẻ cho biết loại nội dung, ứng dụng
nguồn (kèm logo thật), thời gian sao chép và kích thước.

### Lọc theo ứng dụng nguồn

Mở menu **Nguồn** để chỉ xem các mục đến từ một ứng dụng. Menu liệt kê các ứng
dụng bạn sao chép nhiều nhất kèm số lượng; ứng dụng đang chọn được tô nổi và
đưa lên ngay dưới **Tất cả**.

<p align="center">
  <img src="docs/images/source-menu-vi.png" alt="Menu Nguồn liệt kê các ứng dụng kèm logo và số lượng" width="560">
  <img src="docs/images/source-filter-vi.png" alt="Popup chỉ còn các mục từ Safari" width="660">
</p>

### Menu thao tác ngay trên thẻ

Chuột phải (hoặc `⌃` + click) vào một thẻ để dán, dán dưới dạng khác, sao chép,
ghim, thêm ghi chú hoặc xóa. Giữ `⌘` và click để dán ngay.

<p align="center">
  <img src="docs/images/card-menu-vi.png" alt="Menu thao tác của một thẻ" width="560">
</p>

### Dán dưới dạng khác

Nhấn `⌘↩` để xem trước và chọn cách dán: văn bản thuần, Markdown, bỏ dấu, CHỮ
HOA hoặc chữ thường.

<p align="center">
  <img src="docs/images/paste-as-vi.png" alt="Menu Dán dưới dạng với bản xem trước" width="820">
</p>

### Tự quyết định lưu bao lâu

Giới hạn số mục, chọn thời gian lưu (1 tuần đến mãi mãi, hoặc tùy chọn theo giờ,
ngày, tuần, tháng) và xóa lịch sử khi thoát. Mục đã ghim không bao giờ bị dọn.

<p align="center">
  <img src="docs/images/settings-retention-vi.png" alt="Cài đặt Lưu giữ" width="720">
</p>

### Cài đặt gọn trong một nơi

Mở cùng máy, đổi ngôn ngữ (Tiếng Việt / English), chọn phím giữ để dán nhanh,
loại trừ ứng dụng, phím tắt, snippet và App Lock.

<p align="center">
  <img src="docs/images/settings-general-vi.png" alt="Cài đặt Tổ chức: khởi động, ngôn ngữ, dán nhanh" width="720">
</p>

> Ảnh chụp dùng dữ liệu mẫu.

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

Nếu mục có **ghi chú**, chân thẻ hiện ghi chú thay cho số liệu trên.

- Sao chép lại thứ đã có sẽ đưa nó lên đầu thay vì tạo bản trùng.
- Nội dung đến từ iPhone, iPad hoặc máy Mac khác qua Universal Clipboard
  (Handoff) được gắn nhãn riêng.

### 2. Tìm, lọc và sắp xếp

Popup chia làm hai hàng thẻ: **Đã ghim** (ở trên) và **Gần đây**. Phía trên là
thanh lọc và ô tìm kiếm; ba thứ này dùng được **cùng lúc**: bộ lọc theo loại,
bộ lọc theo nguồn và từ khóa tìm kiếm.

#### Bộ lọc theo loại

Mỗi nút lọc hiện kèm **số lượng** mục tương ứng.

| Bộ lọc | Gồm những gì |
| --- | --- |
| Tất cả | Toàn bộ lịch sử |
| Văn bản | Văn bản thuần |
| Hình ảnh | Ảnh chụp màn hình, ảnh sao chép từ trình duyệt hoặc ứng dụng |
| Rich Text | Văn bản có định dạng (RTF, HTML); chỉ hiện khi lịch sử có mục loại này |
| Code | Đoạn code, được nhận diện tự động |
| File | Một hoặc nhiều file |
| URL | Liên kết |
| Màu | Mã màu như `#ff8800`; chỉ hiện khi lịch sử có mục loại này |

#### Lọc theo nguồn

Mỗi thẻ cho biết nó đến từ **ứng dụng nào**: logo thật của ứng dụng cùng tên
và thời gian sao chép. Để chỉ xem những gì đến từ một ứng dụng:

- Mở menu **Nguồn** trên thanh lọc. Menu liệt kê các ứng dụng đã sao chép nhiều
  nhất (tối đa 8), kèm số mục của từng ứng dụng. Chọn một ứng dụng để popup chỉ
  còn các mục từ ứng dụng đó, chọn **Tất cả** để bỏ lọc.
- Bộ lọc nguồn dùng được **cùng lúc** với bộ lọc loại và tìm kiếm,
  ví dụ lọc **Hình ảnh** rồi chọn nguồn **Safari**. Nếu mọi mục của ứng dụng đó
  bị xóa hoặc bị dọn, bộ lọc tự quay về **Tất cả**.
- Ứng dụng không nằm trong 8 mục đầu vẫn tìm được: gõ tên ứng dụng (ví dụ
  `Slack`) vào ô tìm kiếm, vì tên ứng dụng nguồn nằm trong chỉ mục tìm kiếm.
- Khi App Lock đang khóa, menu Nguồn bị ẩn để không lộ tên ứng dụng.
- Nội dung đến từ iPhone, iPad hoặc máy Mac khác qua **Universal Clipboard**
  (Handoff) được gắn nhãn riêng để phân biệt với thứ bạn copy trên máy này.
- Muốn **không bao giờ ghi** nội dung từ một ứng dụng, thêm nó vào
  **Cài đặt → Loại trừ** (xem mục 4). Tùy chọn kèm theo có thể ẩn luôn popup
  khi bạn đang ở trong ứng dụng đó.

#### Tìm kiếm toàn văn

- Chỉ cần **gõ bất kỳ ký tự nào** khi popup đang mở, hoặc nhấn `⌘/`.
- **Không phân biệt hoa thường và dấu**: gõ `viet` vẫn thấy `Việt`.
- Tìm trong: nội dung clip, thông tin kèm theo (tên file, kích thước…), tên
  ứng dụng nguồn và **ghi chú** của mục.
- Với văn bản rất dài, chỉ phần đầu được đưa vào chỉ mục để việc khóa, mở khóa
  và sao chép luôn nhanh.
- Khi App Lock đang khóa, tìm kiếm bị tắt cho đến khi bạn mở khóa.

#### Ghim và ghi chú

- **Ghim** một mục để nó luôn nằm ở hàng **Đã ghim** và không bao giờ bị dọn
  theo giới hạn số lượng hay thời gian. Nút **Ẩn/Hiện đã ghim** thu gọn hàng
  này để hàng Gần đây có thêm chỗ.
- Gắn **ghi chú** cho một mục để nhớ vì sao bạn giữ nó; ghi chú cũng tìm được.
  **Bấm vào chân thẻ** để sửa ghi chú ngay tại chỗ, kể cả khi mục chưa có ghi
  chú. `↩` đóng ô sửa và lưu nếu có thay đổi; bấm ra ngoài ô thì bỏ thay đổi.
  Ghi chú dài tối đa **28 ký tự** để nằm gọn trên một dòng của chân thẻ.

#### Thao tác trên thẻ

| Thao tác | Kết quả |
| --- | --- |
| Click | Chọn thẻ |
| Click đúp | Dán thẻ vào ứng dụng đang dùng |
| `⌘` + click | **Dán nhanh**: chọn và dán ngay. Đổi sang `⌥` hoặc `⇧`, hoặc tắt, tại **Cài đặt → Tổ chức → Dán nhanh** |
| Click chân thẻ | Sửa ghi chú của thẻ ngay tại chỗ |
| Chuột phải, hoặc `⌃` + click | Mở menu thao tác của thẻ: Dán, Dán dưới dạng, Sao chép, Ghim/Bỏ ghim, Ghi chú, Xóa |

### 3. Dán theo ý bạn

| Cách dán | Kết quả |
| --- | --- |
| Nguyên bản | Dán đúng như đã sao chép |
| Plain text | Bỏ định dạng |
| Markdown | Đưa văn bản về dạng phù hợp với Markdown |
| Bỏ dấu Unicode | Bỏ dấu, chuẩn hóa ký tự đặc biệt |
| CHỮ HOA / chữ thường | Đổi kiểu chữ |

- Dán và đóng popup, hoặc dán và **giữ popup mở** để dán nhiều mục liên tiếp.
- **Snippet:** đoạn văn bản dùng lại, tạo và sửa trong **Cài đặt → Đoạn mã**. Gán cho mỗi snippet một phím tắt toàn cục; nhấn phím đó trong bất kỳ ứng dụng nào để dán nội dung snippet vào đó.

### 4. Kiểm soát những gì được ghi

- **Loại trừ ứng dụng** (ví dụ trình quản lý mật khẩu).
- **Tạm dừng ghi** trong 15 phút, 1 giờ, hoặc đến khi bạn bật lại.
- **Lưu giữ:** tối đa 2.000 mục (chỉnh bằng thanh trượt), giữ 1 tuần, 2 tuần,
  1 tháng, 3 tháng, mãi mãi, hoặc **thời gian tùy chọn** (1-999 giờ, ngày,
  tuần hoặc tháng). Mục đã ghim không bao giờ bị dọn. Có thể xóa lịch sử khi
  thoát app.
- **Dán xong đưa lên đầu:** tùy chọn chuyển mục vừa dán lên đầu hàng Gần đây.

### 5. Khóa ứng dụng (App Lock)

- Chỉ khóa trong phiên dùng: SlipBoard mở sẵn sau khi khởi động hoặc cài lại,
  rồi khóa khi bạn bấm Khóa hoặc khi hết thời gian tự khóa.
- Mở khóa bằng **Touch ID** hoặc mật khẩu hệ thống.
- Tự khóa sau 1 phút, 5 phút, 15 phút hoặc 1 giờ không hoạt động.
- Khi khóa, nội dung bị ẩn trong popup, kể cả độ dài và kích thước của từng
  thẻ; icon ứng dụng được thay bằng biểu tượng khóa.
- Tùy chọn ẩn bản xem trước trong Mission Control / Exposé.

### 6. Giao diện cho Mac

- Sáng, tối hoặc theo hệ thống; hiệu ứng **Liquid Glass** trên macOS 26, giao
  diện chuẩn trên các phiên bản trước.
- Giao diện **tiếng Việt** và **English**.
- Biểu tượng riêng trên thanh menu. Bấm vào để xem trạng thái ghi, tạm dừng
  ghi, đổi nhanh thời gian lưu giữ, mở popup hoặc Cài đặt.
- Tùy chọn **mở khi đăng nhập**, phím tắt toàn cục tùy chỉnh.
- **Cài đặt → Giới thiệu** hiện phiên bản và kiểm tra cập nhật. SlipBoard tự
  tải, xác minh và cài bản mới (Sparkle).

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
| `⌘/` hoặc *bất kỳ ký tự nào* | Bắt đầu tìm kiếm |
| `esc` | Đóng popup |

---

## Quyền riêng tư và bảo mật

- **Offline, trừ kiểm tra cập nhật.** SlipBoard chỉ kết nối GitHub để kiểm tra
  cập nhật: khi bạn bấm **Kiểm tra cập nhật**, hoặc mỗi ngày nếu bạn cho phép tự
  kiểm tra khi app hỏi ở lần mở thứ hai (đổi lại trong Cài đặt → Giới thiệu). Không gửi thông tin gì về máy hay
  clipboard của bạn. Không analytics, không telemetry, không dịch vụ báo lỗi,
  không cần tài khoản.
- **Bản phát hành tắt library validation; SlipBoard tự kiểm Sparkle.** Không có
  Apple Team ID thì macOS chỉ nạp `Sparkle.framework` vào app khi tắt library
  validation. Vì vậy Sparkle nằm trong một plug-in riêng
  (`Contents/PlugIns/SlipBoardUpdater.bundle`), SlipBoard chỉ nạp khi cần kiểm
  tra cập nhật, và chỉ sau khi xác nhận, ngay trước lúc nạp, rằng plug-in,
  Sparkle và mọi thành phần bên trong Sparkle được ký bằng đúng chứng chỉ của app
  đang chạy. Kiểm tra thất bại thì không nạp gì và tắt cập nhật. Bản phát hành
  còn được ký kèm library load constraint liệt kê đúng bản build của plug-in và
  Sparkle, nên chính macOS từ chối file bị đổi giữa lúc kiểm và lúc nạp.
  Hardened runtime vẫn chặn chèn thư viện qua `DYLD_*`, và macOS bảo vệ app
  trong `/Applications` khỏi bị app khác sửa, nên hãy cài SlipBoard vào đó.
- **Chỉ lưu trên máy.** Lịch sử, ghi chú, snippet và cài đặt nằm trong
  `~/Library/Application Support/SlipBoard/`.
- **App Lock khóa cửa sổ, không mã hóa ổ đĩa.** Nó ẩn lịch sử cho tới khi bạn
  mở khóa bằng Touch ID hoặc mật khẩu hệ thống. Nội dung clip, file văn bản dài
  và ảnh đã copy vẫn lưu không mã hóa trong thư mục trên, nên hãy bật FileVault
  để bảo vệ dữ liệu khi máy tắt.
- **Ghi chú được mã hóa, nhưng ở bản phát hành khóa nằm ngay cạnh.** Khi bật
  App Lock, ghi chú và một bản sao nội dung clip được mã hóa. Bản phát hành (ký
  bằng chứng chỉ riêng của SlipBoard, hoặc ad-hoc) giữ khóa đó trong
  `PayloadKey.json` ở cùng thư mục, chỉ tài khoản của
  bạn đọc được, nên ai đọc được file của bạn cũng đọc được khóa: việc mã hóa
  này chỉ giúp ghi chú không bị xem lướt qua. Bản ký bằng team giữ khóa trong
  keychain.
- **Mọi thứ bạn copy đều được ghi lại,** kể cả mật khẩu copy từ trình quản lý
  mật khẩu. Hãy loại trừ ứng dụng đó trong Cài đặt, hoặc tạm dừng ghi, nếu
  không muốn chúng nằm trong lịch sử.
- **Chỉ cần một quyền: Accessibility.** Dùng duy nhất để gửi phím ⌘V khi bạn
  chọn một mục. SlipBoard không ghi lại hay gửi đi các phím bạn gõ.

Chi tiết xem [PRIVACY.md](PRIVACY.md).

---

## Cài đặt

### Yêu cầu hệ thống

- **macOS 15** trở lên để chạy.
- **Xcode 26** để build. Dự án dùng API của SDK macOS 26 (Liquid Glass) sau các
  kiểm tra availability, dù vẫn chạy được từ macOS 15.

### Cài bằng Homebrew

```bash
brew install --cask huynq2311/tap/slipboard
```

Bản cài bằng Homebrew cũng chưa được notarize, nên macOS có thể chặn lần mở
đầu tiên: làm theo các bước trong phần dưới.

### Cài từ Release

Tải `SlipBoard.dmg` ở trang [Releases](../../releases), mở file và kéo
**SlipBoard** vào thư mục **Applications**.

Bản Release được ký bằng chứng chỉ tự tạo của SlipBoard và chưa notarize, nên
macOS chặn lần mở đầu tiên:

1. Mở SlipBoard. macOS báo không xác minh được ứng dụng; bấm **Xong**.
2. Mở **Cài đặt hệ thống → Quyền riêng tư & Bảo mật**, cuộn tới mục **Bảo mật**
   và bấm **Vẫn mở** cạnh SlipBoard, rồi xác nhận.

Hoặc bỏ cờ chặn của app bằng một dòng lệnh, không cần vào Cài đặt hệ thống:

```bash
xattr -dr com.apple.quarantine /Applications/SlipBoard.app
```

Sau đó cấp quyền **Accessibility** khi được hỏi để SlipBoard dán được vào ứng
dụng khác.

Cập nhật không làm mất quyền Accessibility: mọi bản phát hành từ
v1.0-20261016.2 được ký bằng cùng một chứng chỉ, nên macOS coi bản cập nhật là
cùng một app. App Lock cũng không hỏi quyền keychain sau khi cập nhật: bản phát
hành giữ khóa của nó trong một file (xem
[Quyền riêng tư và bảo mật](#quyền-riêng-tư-và-bảo-mật)).

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

Bản không ký chạy được. Muốn dùng App Lock, chạy `./build_release.sh` để có bản
ký ad-hoc (cũng không cần tài khoản); kết quả nằm trong `Release/`.

**Build ký bằng team**

Bản ký bằng team giữ khóa App Lock trong Data Protection keychain, được bọc bởi
một khóa Secure Enclave nếu máy có. Bản ký ad-hoc không mang được entitlement
keychain nên giữ khóa trong một file chỉ tài khoản của bạn đọc được, cạnh dữ
liệu đã mã hóa.

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
bật App Lock, một bản sao nội dung và ghi chú của từng mục còn được ghi vào một
kho mã hóa. Khóa của kho được Secure Enclave bọc ở bản ký bằng team (nếu máy
có), và nằm trong một file chỉ tài khoản của bạn đọc được ở bản phát hành và
bản ký ad-hoc. Bản thân kho Core Data không được mã hóa.

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
```

## Giới hạn đã biết

- Danh sách luôn xếp mới nhất trước; chưa có tùy chọn sắp xếp khác.
- Ghi chú tối đa 28 ký tự. Ghi chú đã lưu từ bản cũ dài hơn vẫn giữ nguyên cho
  đến khi bạn sửa và lưu lại; chân thẻ cắt bằng `…` nếu không đủ chỗ.
- Định dạng văn bản có định dạng chỉ được giữ khi ứng dụng đang chạy. Sau khi
  khởi động lại, mục đó vẫn còn trong lịch sử nhưng ở dạng văn bản thuần.
- Dung lượng file và kích thước ảnh được đọc khi hiển thị thẻ: nếu file đã bị
  di chuyển hoặc xóa thì chân thẻ để trống.

## Giấy phép

Phát hành theo giấy phép [MIT](LICENSE).

## Thông báo bên thứ ba

SlipBoard đóng gói một thư viện của bên thứ ba:

- **[Sparkle](https://sparkle-project.org)** 2, framework cập nhật trong ứng
  dụng (giấy phép MIT; © 2006-2013 Andy Matuschak, © 2009-2013 Elgato Systems
  GmbH, © 2011-2014 Kornel Lesiński, © 2015-2017 Mayur Pawashe, © 2014 C.W.
  Betts, © 2014 Petroules Corporation, © 2014 Big Nerd Ranch). Sparkle có chứa
  code từ bsdiff, sais-lite, ed25519 và SUSignatureVerifier theo giấy phép
  riêng của từng thành phần. Toàn văn:
  [LICENSE của Sparkle](https://github.com/sparkle-project/Sparkle/blob/2.10.0/LICENSE).

Ngoài Sparkle, SlipBoard không đóng gói code, font hay hình ảnh nào của bên thứ
ba. Ứng dụng dựa vào các thành phần sau:

- **SF Symbols** (© Apple Inc.). Giao diện dùng biểu tượng từ bộ SF Symbols có
  sẵn trong macOS, theo giấy phép SF Symbols của Apple cho ứng dụng chạy trên
  nền tảng Apple. Không biểu tượng nào được dùng làm icon ứng dụng hay logo.
- **San Francisco** (© Apple Inc.). Chữ trong ứng dụng, kể cả ảnh nền DMG, dùng
  font hệ thống của macOS, không được đóng gói kèm.
- **Icon ứng dụng và icon thanh menu.** Được tạo riêng cho SlipBoard bằng công
  cụ tạo ảnh AI; không chứa hình ảnh của bên thứ ba.
- **Tên và icon của ứng dụng khác.** Thẻ hiển thị tên và icon của ứng dụng nguồn
  của clip, lấy từ máy của bạn lúc chạy. Ảnh chụp màn hình trong README có hiện
  một số icon này chỉ để minh họa. Chúng là nhãn hiệu của chủ sở hữu tương ứng.
