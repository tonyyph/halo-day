# Halo Day v2 — Living Sky redesign

> Ngày 2026-10-06 · Trạng thái: chờ chủ sản phẩm duyệt · Nhánh: `redesign/v2`
> Thay thế phần IA, màn hình và hệ thị giác của `docs/SPEC.md`. Các ràng buộc nền tảng iOS (SPEC §1.4), quyền riêng tư, StoreKit và nguyên tắc "trung thực" vẫn giữ nguyên.

## 1. Mục tiêu & bối cảnh

**Chủ sản phẩm nói:** giao diện v1 "đại trà", không có cảm giác mới; cần làm lại toàn bộ UI/UX (được thêm tính năng); kết quả phải đạt chuẩn release và thật đẹp — thị giác là ưu tiên số một. Đã chọn: làm lại như sản phẩm mới, chỉ giữ lõi (lịch, thói quen, tập trung, widget); hướng "vật thể của ngày" dạng **Orbit** kết hợp một phần **dòng ánh sáng**; không khí **Living Sky**. Các quyết định còn lại được giao cho người thiết kế (tài liệu này).

**Chẩn đoán v1:** mọi màn là cùng một khuôn (tiêu đề serif + thẻ bo góc xếp chồng + segmented control + tab bar nổi); 8 theme chỉ là đổi màu; không có hình ảnh nhận diện riêng.

**Định vị v2:** *Halo Day là chiếc đồng hồ của một ngày.* Cả ngày của bạn hiển thị như một vòng halo sống dưới một bầu trời đổi màu theo giờ thật. Liếc là hiểu; chạm là hành động.

**Tiêu chí thành công**
1. Không màn hình nào dùng lại khuôn "tiêu đề + thẻ xếp chồng" của v1. Orbit hoặc bầu trời là yếu tố thị giác chủ đạo của mọi màn chính.
2. Mở app ở 4 thời điểm (6h, 10h, 18h, 22h) cho ra 4 không khí khác nhau rõ rệt, chữ luôn đạt WCAG AA.
3. Thói quen và tập trung thao tác được ngay trên Orbit, không cần mở tab khác.
4. Đạt chuẩn release: build/test xanh, en + vi đầy đủ, Dynamic Type đến AX3, VoiceOver, Reduce Motion/Transparency, icon và ảnh App Store mới, StoreKit hoạt động trên bản ký.

## 2. Ngôn ngữ thị giác

### 2.1 Living Sky
Nền toàn màn hình (full-bleed, kể cả dưới tab bar) là bầu trời tính từ **vị trí mặt trời** thật:

| Pha | Mô tả | Mực chữ |
|---|---|---|
| Đêm | mực xanh-tím rất sâu, hạt sao mảnh, ánh trăng lạnh (= không khí Celestial) | sáng |
| Giờ xanh (bình minh sớm) | chàm → tím hồng ở chân trời | sáng |
| Bình minh | tím nhạt → cam đào | tối |
| Sáng | xanh trời trong → kem ấm | tối |
| Trưa | xanh sáng, gần trắng ở dưới | tối |
| Chiều | xanh ấm → vàng nhạt | tối |
| Giờ vàng | hổ phách → hồng san hô | tối |
| Hoàng hôn | tím mận → cam cháy | sáng |

- Mỗi pha là một **keyframe**: 3 điểm màu gradient (đỉnh/giữa/chân), màu quầng (glow), mức hạt sao, `inkScheme` (light/dark), màu nhấn. Giữa hai keyframe thì **nội suy liên tục** theo độ cao mặt trời, không nhảy cóc. `inkScheme` đổi ở điểm giữa vùng chuyển, có crossfade 600ms.
- Độ cao mặt trời được tính bằng thuật toán NOAA (`SolarCalculator`, hàm thuần). Vị trí: hỏi **vị trí gần đúng** (reduced accuracy, when-in-use) một lần trong onboarding với lý do "Khớp bầu trời với nơi bạn ở". Nếu từ chối thì suy ra từ múi giờ (bảng tọa độ đại diện cho các múi giờ IANA phổ biến), không khớp thì dùng mặc định 6:00/18:00. Tọa độ chỉ lưu trên máy, làm tròn 1 chữ số thập phân.
- Sky cập nhật mỗi phút (`TimelineView(.everyMinute)`), không chạy vòng lặp từng giây.
- Bề mặt nổi dùng **kính mỏng nhuộm theo trời** (`.glassEffect` trên iOS 26, material + tint trên iOS 18). Không dùng thẻ đặc màu, không dùng hairline xám.

### 2.2 Orbit (vật thể của ngày)
Một vòng 24 giờ được định hướng như bầu trời: **trưa ở đỉnh, nửa đêm ở đáy, bình minh bên trái, hoàng hôn bên phải**. Mặt trời đi đúng như ngoài trời.

Các lớp, tính từ ngoài vào:
1. **Quầng (halo):** glow mềm, màu lấy từ sky hiện tại.
2. **Vòng thời gian:** track mảnh. Phần ban đêm (từ hoàng hôn đến bình minh) phủ tối hơn. Có vạch giờ 0/6/12/18.
3. **Cung sự kiện:** mỗi sự kiện là một cung bo tròn, màu theo lịch (được điều chỉnh độ sáng để hài hòa với sky). Sự kiện chồng giờ được tách làn ra phía ngoài, tối đa 3 làn, phần dư gộp thành "+n".
4. **Cung tập trung:** cung mảnh ở vòng trong cho các phiên tập trung đã làm hôm nay.
5. **Hạt nghi thức (ritual beads):** chấm trên vòng trong, đặt theo `timeOfDay` của thói quen. Đã làm thì đặc và phát sáng, chưa làm thì là vòng rỗng.
6. **Thiên thể "bây giờ":** ban ngày là mặt trời, ban đêm là mặt trăng (theo pha trăng thật, tính được từ ngày). Có glow, thở nhẹ 4 giây một chu kỳ.
7. **Tâm:** giờ hiện tại (SF Pro Display Ultralight, số monospaced), bên dưới là **tên khoảnh khắc** ("Sáng trong", "Giờ vàng", "Đêm yên"…). Khi chạm thì tâm hiện thông tin ngữ cảnh.

Orbit chỉ có **một renderer** (`OrbitCanvas`, dùng SwiftUI `Canvas`), được dùng chung cho app, widget, Live Activity, ảnh chia sẻ và wallpaper. Mọi phép tính hình học nằm trong `OrbitGeometry` (thuần, có unit test).

### 2.3 Dòng ánh sáng (Light Column)
Dưới Orbit là timeline dọc. Đường trục mảnh, **quả cầu "bây giờ"** phát sáng nằm đúng vị trí giờ hiện tại. Sự kiện đã qua mờ dần (opacity giảm theo khoảng cách thời gian), sự kiện kế tiếp được mở rộng thành một khối kính. **Khoảng trống** từ 20 phút trở lên hiển thị thành dòng "Khoảng trống 25′ · Tập trung?".

### 2.4 Typography
- **Display:** Fraunces (variable, OFL, có subset tiếng Việt; trục `opsz`/`SOFT`, dùng SOFT 50–100 cho chất mềm, sang). Dùng cho tiêu đề, tên sự kiện nổi bật, tên khoảnh khắc. Font được nhúng vào app và widget extension.
- **UI/Body:** SF Pro theo Dynamic Type.
- **Số/đồng hồ:** SF Pro Display Ultralight/Thin, monospaced digits.
- Cổng kiểm tra ở Phase 1: render đủ dấu tiếng Việt (ẳ, ộ, ữ, ợ…) ở mọi cỡ. Nếu lỗi thì dùng New York làm phương án thay thế.
- Bỏ kiểu chữ hoa giãn chữ (uppercase tracking) đang dùng tràn lan ở v1. Chỉ giữ cho tối đa một nhãn nhỏ mỗi màn.

### 2.5 Chuyển động & phản hồi
- Chuyển động mặc định dùng spring mềm (`response 0.5, damping 0.85`). Orbit morph (ngày ↔ tuần ↔ tháng ↔ tập trung) bằng `matchedGeometryEffect` và nội suy hình học.
- Khoảnh khắc ký tên (signature moments):
  - đánh dấu nghi thức: hạt bật sáng và gợn sóng chạy quanh vòng, haptic `.soft`;
  - hoàn thành mọi nghi thức: halo khép thành vòng tròn trọn vẹn;
  - hoàn thành tập trung: bloom ánh sáng và haptic success;
  - mở app: sky fade-in, Orbit vẽ các cung trong 700ms.
- Reduce Motion: thay bằng crossfade, tắt hiệu ứng thở và gợn sóng. Reduce Transparency: kính thành nền đặc nhuộm sky.

### 2.6 Bầu trời (thay cho 8 theme)
Theme v1 bị bỏ. Mỗi **Sky** là một bộ keyframe, kiểu Orbit (glow / khắc / nét mực) và cặp font.

| Sky | Mô tả | Gói |
|---|---|---|
| **Living Sky** | bầu trời thật theo giờ (mặc định) | Free |
| **Celestial** | luôn là đêm sao, Orbit phát sáng | Free |
| **Instrument** | giấy ấm, mực đen, Orbit khắc vạch như astrolabe, không phụ thuộc giờ | Premium |
| **Aurora** | đêm cực quang xanh-tím chuyển động chậm | Premium |
| **Golden Hour** | giờ vàng vĩnh cửu (kế thừa Midnight Gold / Champagne) | Premium |
| **Mist** | sương xám bạc, gần đơn sắc, rất tĩnh | Premium |

## 3. Kiến trúc thông tin

`TabView` hệ thống với 3 tab (dùng Liquid Glass trên iOS 26), icon SF Symbols được tinh chỉnh:

```
Halo Day
├── Ngày (Day)        — mặc định
│   ├── Orbit + Light Column
│   ├── Thu phóng: Ngày ↔ Tuần ↔ Tháng (pinch / kéo xuống)
│   ├── Sự kiện → sheet chi tiết (đếm ngược Live Activity)
│   ├── Hạt nghi thức → đánh dấu tại chỗ
│   └── Khoảng trống / giữ thiên thể → Chế độ Tập trung (toàn màn)
├── Studio
│   ├── Bộ màn khóa (Setups): xem trước toàn màn, sửa ô widget
│   ├── Bầu trời (Skies)
│   ├── Hình nền bầu trời → lưu vào Ảnh
│   └── Hướng dẫn thêm widget
└── Bạn (You)
    ├── Tuần của bạn (recap)
    ├── Nghi thức: quản lý + lịch sử
    ├── Tập trung: lịch sử
    ├── Đếm ngược ngày
    ├── Premium
    └── Cài đặt
```

Deep link `haloday://` được ánh xạ lại: `day`, `day?date=yyyy-MM-dd`, `focus`, `studio`, `you`, `rituals`, `paywall`, `event/<id>`. Các link v1 (`calendar`, `rituals`, `focus`) vẫn điều hướng đúng.

## 4. Màn hình

### 4.1 Ngày (Day)
- Sky full-bleed. Phía trên: ngày tháng (Fraunces, cỡ vừa) và nút chia sẻ nhỏ bằng kính. Không có lời chào kiểu "Chào buổi sáng, Alex" lớn chiếm chỗ; tên người dùng chỉ xuất hiện trong tên khoảnh khắc khi phù hợp.
- Orbit chiếm khoảng 46% chiều cao, căn giữa. Bên dưới là Light Column, cuộn được. Khi cuộn, Orbit thu nhỏ và dính lên đầu thành thanh "mini orbit" cạnh giờ.
- Tương tác:
  - vuốt ngang trên Orbit để đổi ngày (sky tính theo đúng giờ đó của ngày đích; Orbit quay 15° kèm crossfade);
  - chạm cung sự kiện mở sheet chi tiết; chạm hạt thì đánh dấu nghi thức;
  - nhấn giữ thiên thể hoặc chạm dòng khoảng trống thì vào Tập trung;
  - kéo xuống hoặc pinch-in để chuyển sang Tuần.
- **Trạng thái rỗng:** chưa có quyền lịch thì Orbit dùng dữ liệu mẫu, hiển thị nhãn kính "Dữ liệu mẫu · Kết nối lịch" thành một nút thật. Ngày không có sự kiện thì hiện "Ngày thoáng." cùng gợi ý tập trung.
- Lỗi (EventKit/ghi lưu trữ) được báo bằng toast kính ở đáy, không dùng alert.

### 4.2 Thu phóng lịch (Orbit Zoom) — *mới*
- **Tuần:** 7 mini-orbit xếp thành chuỗi hạt cong theo cung tròn. Ngày hôm nay lớn hơn và sáng hơn. Mỗi mini-orbit có cung sự kiện và hạt nghi thức. Chạm vào một ngày thì phóng về màn Ngày.
- **Tháng:** lưới 7 cột gồm các vòng nhỏ. Độ dày vòng thể hiện mật độ lịch, vòng trong khép kín khi đã hoàn thành mọi nghi thức. Ngày đang chọn có quầng. Bên dưới lưới là agenda của ngày chọn, dạng Light Column rút gọn.
- Cử chỉ: pinch-out/in, hoặc kéo xuống/lên. Có thanh tỷ lệ "Ngày · Tuần · Tháng" bằng kính để truy cập không cần cử chỉ (accessibility).

### 4.3 Chế độ Tập trung
- Vào từ màn Ngày. Sky dịu xuống thành "dusk tập trung" (giảm 30% độ sáng, tăng độ bão hòa của quầng). Orbit morph: vòng 24h co lại, cung còn lại của phiên tập trung trở thành vòng chính, thiên thể chạy ngược chiều kim đồng hồ.
- Chọn thời lượng bằng cách xoay núm trực tiếp trên vòng (snap 5′, tối đa 4h), đặt tên tùy chọn.
- Các nút Tạm dừng / Kết thúc dạng kính ở đáy. Hoàn thành thì có bloom, cung tập trung mới được thêm vào Orbit ngày, và hiện "+25′ hôm nay".
- Free: tập trung trong app kèm thông báo kết thúc. Premium: Live Activity.

### 4.4 Chi tiết sự kiện (sheet)
Sheet kính với detent `.medium`/`.large`. Phía trên là một cung Orbit phóng to chỉ vị trí sự kiện trong ngày. Bên dưới là tiêu đề Fraunces, giờ, địa điểm, lịch nguồn và các hành động "Đếm ngược trên màn khóa" (Premium, chỉ trong vòng 60′ trước giờ bắt đầu) và "Mở trong Lịch".

### 4.5 Studio
- **Setups:** carousel ngang các bộ màn khóa, mỗi bộ hiển thị như một màn khóa thật toàn chiều cao (wallpaper bầu trời + đồng hồ + các ô widget). Chạm một ô để chọn loại widget cho ô đó (sheet lưới). Mô phỏng chế độ vibrant của iOS một cách trung thực, có toggle "Xem như iOS hiển thị". Ghi chú giới hạn nền tảng được giữ nhưng viết ngắn, đặt trong nút (i).
- **Bố cục ô:** 1 inline cùng hàng dưới đồng hồ (4 circular / 2 rectangular / 1 rect + 2 circular), đúng quy tắc của iOS.
- **Giới hạn:** Free 1 Setup và chỉ dùng sky Free. Premium không giới hạn Setup và mở mọi sky.
- **Bầu trời:** danh sách skies. Mỗi sky là một ô cao có Orbit sống bên trong. Premium có khóa nhỏ; xem trước đầy đủ trước khi mua.
- **Hình nền bầu trời — mới:** render wallpaper ở độ phân giải đúng của thiết bị từ sky đã chọn và một thời điểm (hoặc "theo giờ hiện tại"). Tùy chọn hiện Orbit mờ ở nửa dưới. Lưu bằng quyền add-only `NSPhotoLibraryAddUsageDescription`. Free có 2 wallpaper (Living Sky lúc bình minh và Celestial), Premium không giới hạn.
- **Hướng dẫn:** 4 bước minh họa động, có nút "Sao chép các bước".

### 4.6 Bạn (You)
- **Tuần của bạn:** 7 mini-orbit đan thành một vòng lớn. Chỉ số: phút tập trung, % nghi thức, giờ bận nhiều nhất. Một câu tổng kết viết tay theo mẫu (không dùng AI, không gửi dữ liệu ra ngoài).
- **Nghi thức:** danh sách hạt lớn, mỗi hàng có glyph, `timeOfDay` và streak. Trình chỉnh sửa gồm tên, glyph (bộ SF Symbols được chọn lọc), màu (6 màu hài hòa với sky) và thời điểm trong ngày. Lịch sử là lưới 12 tuần dạng chấm sáng. Free tối đa 3 nghi thức.
- **Tập trung:** biểu đồ cột 7 ngày bằng thanh ánh sáng, danh sách phiên.
- **Đếm ngược:** các ngày quan trọng, mỗi ngày là một vòng đếm (Free 1, Premium không giới hạn).
- **Cài đặt:** form nhóm, nền sky dịu, kính. Gồm tên, lịch được dùng, sự kiện cả ngày, nhắc trước sự kiện, haptics, Live Activities, vị trí cho bầu trời, khôi phục mua hàng, quyền riêng tư, liên hệ, phiên bản.

### 4.7 Onboarding (4 bước)
1. **Bình minh:** sky chạy cả một ngày trong khoảng 6 giây trong khi Orbit tự vẽ. Câu chính: "Ngày của bạn, như một vòng sáng." Nút Bắt đầu.
2. **Lịch:** lý do cần quyền, bấm cho phép thì Orbit đổ đầy sự kiện thật ngay trước mắt. Có nút "Dùng dữ liệu mẫu".
3. **Nghi thức:** chọn 1–3 gợi ý (Uống nước, Thiền, Đọc sách, Vận động, Chăm da, Viết nhật ký). Các hạt rơi xuống đúng vị trí trên vòng.
4. **Bầu trời của bạn:** quyền vị trí gần đúng (tùy chọn) và thông báo (tùy chọn). Xong thì vào màn Ngày với sky thật.

Paywall không chen vào giữa onboarding. Gợi ý Premium chỉ xuất hiện sau lần đầu lưu Setup hoặc khi chạm vào tính năng Premium.

### 4.8 Paywall
Toàn màn: nền chạy qua lần lượt các sky Premium (mỗi sky 3 giây, vuốt để đổi), Orbit ở giữa đổi theo kiểu của từng sky. Bên dưới là 3–4 dòng lợi ích có glyph sáng, chọn gói (năm / tháng / trọn đời) bằng kính, và một CTA. Giá, kỳ hạn và dùng thử lấy từ StoreKit; không có sản phẩm thì giữ hành vi của v1 (hiện placeholder, vô hiệu nút mua). Có Khôi phục, Điều khoản, Quyền riêng tư.

## 5. Widget & Live Activity

Thu gọn từ 8 xuống 6 loại widget, tất cả dùng `OrbitCanvas` và token sky chung:

| Widget | Họ (family) | Ghi chú |
|---|---|---|
| **Orbit** — *mới* | circular, small, large, StandBy | vòng ngày kèm thiên thể; small/large có nền sky theo timeline entry |
| **Tiếp theo** | rectangular, inline, small | sự kiện kế tiếp, `Text(date, style: .relative)` |
| **Nhịp ngày** (agenda) | rectangular, medium, large | tối đa 3 dòng (accessory), 5 dòng (large) |
| **Nghi thức** | circular, small, medium | nút `AppIntent` để đánh dấu tại chỗ |
| **Đếm ngược** | circular, rectangular, small | |
| **Tháng** | inline, rectangular, medium | lưới vòng nhỏ / tiến độ tháng |

- Timeline: giữ chiến lược ranh giới sự kiện của v1. Thêm các entry tại ranh giới pha sky (tối đa 1 entry/giờ cho widget có nền sky). Gọi `reloadTimelines` chỉ khi dữ liệu đổi.
- Lock Screen: thể hiện theme bằng hình học và typography, không bằng màu (vibrant mode).
- **Live Activity (Tập trung và Đếm ngược sự kiện):** Lock Screen có nền sky và một vòng đếm. Dynamic Island compact gồm vòng mini và số phút; expanded gồm vòng, tiêu đề và nút Tạm dừng/Kết thúc (AppIntent). Vẫn hiển thị tốt trên máy không có Island.

## 6. Tính năng mới (tổng hợp)
1. Living Sky + Solar engine.
2. Orbit Zoom (Tuần/Tháng bằng mini-orbit).
3. Tập trung tại chỗ với núm xoay trên Orbit.
4. Nghi thức có `timeOfDay`, đặt vị trí trên vòng.
5. Hình nền bầu trời (lưu vào Ảnh).
6. Thẻ chia sẻ "Halo hôm nay": ảnh 1080×1920 gồm sky, Orbit và chỉ số trong ngày, chia sẻ qua `ShareLink`. Tên sự kiện ẩn theo mặc định (tôn trọng quyền riêng tư), có toggle để hiện.
7. Widget Orbit, kể cả StandBy.
8. Tuần của bạn (recap).

**Không làm (YAGNI):** tài khoản/đồng bộ, AI, tạo/sửa sự kiện, tóm tắt buổi sáng bằng thông báo, iPad UI riêng, Apple Watch.

## 7. Kiến trúc kỹ thuật

- Giữ: SwiftUI, iOS 18.0+, `HaloModel` (@Observable), services (EventKit, Notifications, StoreKit 2, ActivityKit), App Group storage, mô hình mã dùng chung giữa app và widget qua `Shared/`.
- Module mới trong `Shared/` (biên dịch cho cả app và widget):
  - `Sky/SolarCalculator.swift`: thuần; `(date, coordinate) → sunAltitude, sunrise, sunset, moonPhase`.
  - `Sky/SkyKeyframes.swift`, `Sky/SkyEngine.swift`: `(skyId, date, coordinate) → SkyState { gradient stops, glow, starDensity, inkScheme, accent, momentName }`.
  - `Sky/SkyBackground.swift`: view nền (stars bằng Canvas, đặt seed để ổn định).
  - `Orbit/OrbitGeometry.swift`: thuần; time ↔ angle, cung sự kiện, xếp làn khi chồng giờ, vị trí hạt, hit-testing.
  - `Orbit/OrbitCanvas.swift`: renderer với các tham số style (glow/engraved/ink), kích cỡ và các lớp bật/tắt được.
  - `Design/Tokens.swift`: spacing, radius, type scale (Fraunces + SF), motion, haptics. Thay `HaloTokens`, `HaloFont` và `ThemePalettes`.
- App: `Screens/Day`, `Screens/Zoom`, `Screens/Focus`, `Screens/Studio`, `Screens/You`, `Screens/Onboarding`, `Screens/Paywall`. Các thư mục màn hình và component v1 sẽ bị xóa khi màn thay thế tương ứng đã xong (không để code chết).
- Service mới: `LocationService` (một lần, reduced accuracy), `WallpaperRenderer` và `ShareCardRenderer` (`ImageRenderer` của `OrbitCanvas` + `SkyBackground`), `PhotoSaver` (add-only).
- **Thay đổi dữ liệu, có migration:**
  - `Habit.timeOfDay: TimeOfDay` (`morning/afternoon/evening/anytime`). Decode thiếu khóa thì mặc định `.anytime`.
  - `UserSettings.skyId` thay `selectedThemeId`. Ánh xạ: `graphiteFocus, midnightGold → celestial`; `champagneDay → goldenHour`; `ivoryMinimal → instrument`; còn lại `→ livingSky`. Thêm `approxCoordinate: Coordinate?`.
  - `WidgetPreset` → `LockSetup { id, name, skyId, inline: WidgetKind?, slots: [Slot], wallpaper: WallpaperConfig? }`. Preset v1 được chuyển thành một Setup với một ô.
  - Khóa lưu trữ mới có hậu tố `.v2`; khóa cũ được đọc một lần để migrate và giữ lại (không xóa) cho đến bản sau.
  - `WidgetType` v1 → `WidgetKind` v2: `agenda→rhythm`, `week/mini/month→month`, `habit/ritual→rituals`, `focus→orbit`, `countdown→countdown`.
- Quy tắc kế thừa từ SPEC v1: không hard-code hex trong view (chỉ trong `SkyKeyframes`); mọi chuỗi nằm trong `Localizable.xcstrings` (en + vi); file mới phải chạy `scripts/generate_project.rb`.
- Bản quyền: Fraunces theo OFL (kèm file license trong bundle và ghi trong màn Cài đặt › Giấy phép).

## 8. Lỗi & trường hợp biên
- Không có quyền lịch: dữ liệu mẫu được dán nhãn rõ ở mọi nơi có sự kiện (app, widget, ảnh chia sẻ).
- Từ chối vị trí: dùng múi giờ, lúc cần thì báo nhẹ "Bầu trời ước tính theo múi giờ".
- Vùng cực (mặt trời không lặn/không mọc): `SolarCalculator` trả về trạng thái `.polarDay/.polarNight`; sky giữ pha tương ứng; Orbit bỏ vùng đêm hoặc phủ tối toàn vòng.
- Ngày có hơn 12 sự kiện: làn thứ 3 gộp thành "+n"; Light Column vẫn liệt kê đủ.
- Sự kiện qua nửa đêm: được cắt theo ngày đang xem, đầu cung có mũi tiếp diễn.
- Từ chối quyền Ảnh: toast giải thích và nút mở Cài đặt.
- StoreKit trống hoặc lỗi: như v1 (placeholder trung thực, không hứa hẹn dùng thử).
- Đổi múi giờ hoặc giờ hệ thống: đăng ký `NSSystemClockDidChange`/`significantTimeChange` để tính lại sky và timeline widget.

## 9. Kiểm thử & xác minh
- **Unit:**
  - `SolarCalculator` so với giá trị NOAA cho 4 điểm (Hà Nội, TP.HCM, London, Tromsø) × 2 mùa, sai số 2 phút trở xuống;
  - `OrbitGeometry` (góc, cung, xếp làn, hit-test, qua nửa đêm);
  - `SkyEngine` gồm nội suy liên tục và **độ tương phản mực/nền ≥ 4.5:1** tại mỗi phút trong 24h cho mọi sky;
  - migration decode v1 → v2;
  - logic giới hạn Free/Premium.
- **UI tests:** onboarding (cả hai nhánh quyền); đánh dấu nghi thức từ Orbit; vào/ra Tập trung; thu phóng Ngày → Tuần → Tháng → Ngày; tạo Setup; lưu wallpaper (quyền giả lập); paywall khi StoreKit trống.
- **Ma trận ảnh chụp mới:** 4 thời điểm (6:10, 10:05, 18:20, 22:30) × {Living Sky, Celestial, Instrument} × {en, vi} × các màn chính, tạo bằng `scripts/screenshots.sh` (mở rộng bằng launch arg giờ cố định). Kèm video chuyển động: mở app, đánh dấu nghi thức, tập trung, zoom.
- **Accessibility:** VoiceOver cho Orbit (mỗi cung/hạt là một phần tử truy cập, kèm custom rotor "Sự kiện"/"Nghi thức"), Dynamic Type AX3 không vỡ bố cục, Reduce Motion/Transparency, kích thước vùng chạm tối thiểu 44pt (vùng hit của hạt được mở rộng).
- **Hiệu năng:** Orbit render dưới 4ms trên iPhone SE 3 (đo bằng signpost); không có timer 1 giây; widget tuân thủ ngân sách reload.

## 10. Thứ tự xây dựng (mỗi phase có plan riêng)

| Phase | Nội dung | Kết thúc khi |
|---|---|---|
| 1. Nền tảng | Solar, SkyEngine, OrbitGeometry, OrbitCanvas, Tokens, Fraunces, màn debug "Sky Lab" (thanh trượt thời gian) | unit test xanh, Sky Lab đẹp ở mọi giờ, cổng tiếng Việt cho font đạt |
| 2. Ngày | màn Day, Light Column, tương tác hạt, sheet sự kiện, Tập trung | UI test các luồng; v1 Today/Focus/Rituals bị xóa |
| 3. Orbit Zoom | Tuần, Tháng | v1 Calendar bị xóa |
| 4. Bạn | recap, nghi thức, tập trung, đếm ngược, cài đặt, migration dữ liệu | v1 Settings bị xóa |
| 5. Studio | Setups, skies, wallpaper, thẻ chia sẻ, hướng dẫn | v1 Studio/Themes bị xóa |
| 6. Widget & Live Activity | 6 widget kinds, LA mới | build extension, ảnh chụp widget gallery |
| 7. Phát hành | onboarding, paywall, icon mới (vòng sáng trên sky, có layer cho Icon Composer), a11y pass, l10n, ma trận ảnh, ảnh App Store, cập nhật README/SPEC | checklist release (mục 11) |

## 11. Checklist release
- [ ] `xcodebuild … test` xanh trên iPhone 17 Pro (iOS 26) và build trên iPhone SE 3 (iOS 18).
- [ ] Ma trận ảnh chụp và video đã được người duyệt xem.
- [ ] Không còn chuỗi chưa dịch (en/vi).
- [ ] Icon cuối cùng, Launch screen dùng sky.
- [ ] Privacy manifest được cập nhật (vị trí gần đúng, Ảnh add-only).
- [ ] Sản phẩm StoreKit trên App Store Connect; đã thử mua và khôi phục trên bản ký.
- [ ] App Group, widget và Live Activity đã kiểm trên máy thật có Dynamic Island và máy không có.
- [ ] Đo Instruments (Hitches/SwiftUI) trên máy thật cho các thao tác cuộn Day, zoom và đổi sky.
