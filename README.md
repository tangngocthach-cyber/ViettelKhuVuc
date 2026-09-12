Hướng dẫn build App iOS (TestFlight) qua Codemagic — Từ A đến Z

Tài liệu này hướng dẫn các bước thủ công bắt buộc trên Apple Developer và
Codemagic UI — những phần không thể tự động hóa qua code (khác với
Android chỉ cần đúng file codemagic.yaml là chạy được ngay).



Yêu cầu trước khi bắt đầu


Tài khoản Apple Developer Program: 99 USD/năm (không có gói tháng, không có bản dùng thử miễn phí — đây là điều kiện bắt buộc của Apple để phát hành app lên App Store/TestFlight, không phải chi phí của Codemagic). Đăng ký tại: https://developer.apple.com/programs/enroll/

Tài khoản Codemagic đã kết nối với repo GitHub này (đã dùng để build Android từ trước, dùng chung tài khoản đó).



Bước 1 — Đăng ký App ID trên Apple Developer


Vào https://developer.apple.com/account/resources/identifiers/list

Bấm + → chọn App IDs → App

Bundle ID: chọn "Explicit", nhập đúng com.vinhhung.vinhhungApp (PHẢI khớp chính xác với giá trị trong codemagic.yaml, nếu đổi Bundle ID phải sửa cả 2 chỗ đồng bộ)

Description: đặt tên gợi nhớ, ví dụ "Viettel Khu Vuc Vinh Hung"

Ở mục Capabilities, tick các quyền app đang dùng nếu cần: Push Notifications (để dùng Firebase Messaging trên iOS sau này nếu muốn)

Bấm Continue → Register


Bước 2 — Tạo App trên App Store Connect


Vào https://appstoreconnect.apple.com/apps → bấm + → New App

Platform: iOS

Name: tên hiển thị trên App Store (VD "Viettel Khu Vực Vĩnh Hưng")

Primary Language: Vietnamese

Bundle ID: chọn đúng com.vinhhung.vinhhungApp đã tạo ở Bước 1

SKU: tự đặt mã nội bộ bất kỳ, VD vinhhungapp001

Bấm Create


Bước 3 — Tạo API Key cho App Store Connect (để Codemagic tự động ký)


Vào https://appstoreconnect.apple.com/access/api

Chọn tab Keys → bấm + để tạo key mới

Name: đặt tên gợi nhớ, VD "Codemagic CI"

Access: chọn quyền Admin (hoặc tối thiểu App Manager)

Bấm Generate → TẢI FILE .p8 NGAY LẬP TỨC (Apple chỉ cho tải DUY NHẤT 1 LẦN, mất file phải tạo key mới)

Ghi lại 3 giá trị sau (dùng ở Bước 4):
Issuer ID (hiện ở đầu trang Keys)
Key ID (cột "KEY ID" của key vừa tạo)
Nội dung file .p8 vừa tải (mở bằng Notepad, copy toàn bộ)


Bước 4 — Cấu hình App Store Connect integration trên Codemagic


Vào Codemagic → Teams (góc trên bên trái) → Integrations

Tìm mục App Store Connect → bấm Connect

Dán vào đúng 3 giá trị đã lấy ở Bước 3: Issuer ID, Key ID, nội dung file .p8

Đặt tên cho integration này (nhớ tên, dùng lại ở Bước 5), ví dụ: appstore_vinhhung


Bước 5 — Tạo Group Variables chứa thông tin xác thực


Vẫn ở Codemagic → Teams → Environment variables (hoặc Group variables, tùy giao diện)

Tạo 1 group MỚI tên chính xác: appstore_credentials (khớp với dòng groups: trong codemagic.yaml)

Nếu Codemagic yêu cầu thêm biến cụ thể trong group này, dùng lại thông tin đã lấy ở Bước 3 (một số phiên bản Codemagic tự động liên kết qua integration ở Bước 4 mà không cần khai biến tay ở đây — nếu group để trống vẫn build được, đây chỉ là chỗ dự phòng cho các biến môi trường khác sau này nếu cần thêm).


Bước 6 — Kiểm tra lại ios_signing trong codemagic.yaml

File đã có sẵn cấu hình:


ios_signing:
  distribution_type: app_store
  bundle_identifier: com.vinhhung.vinhhungApp

Không cần sửa gì nếu Bundle ID vẫn giữ nguyên như Bước 1.


Bước 7 — Chạy build lần đầu


Đẩy toàn bộ code (kèm codemagic.yaml đã cập nhật) lên GitHub

Vào Codemagic → chọn app này → chọn workflow vinhhung-ios → Start new build

Theo dõi log — lần đầu thường mất 15–25 phút (cài Xcode, CocoaPods, ký, build, đóng gói IPA)


Bước 8 — Xử lý khi build lỗi


Lỗi "No profiles found": Bundle ID ở Bước 1 chưa khớp chính xác với codemagic.yaml, kiểm tra lại đúng từng ký tự.

Lỗi liên quan CocoaPods/Podfile: thường do 1 thư viện chưa hỗ trợ iOS đầy đủ — gửi lại đoạn log lỗi để xử lý tiếp theo đúng lỗi thật (không nên đoán trước, xem ghi chú "bài học" trong codemagic.yaml).

Lỗi liên quan quyền Info.plist: nếu Apple từ chối vì thiếu mô tả quyền, đối chiếu lại danh sách quyền đã khai trong codemagic.yaml (bước "Khai báo quyền truy cập trong Info.plist") xem có thiếu quyền nào mới thêm sau này không.


Bước 9 — Duyệt bản TestFlight


Sau khi build + publish thành công, vào App Store Connect → TestFlight → chọn bản build vừa lên

Điền Export Compliance (thường chọn "No" nếu app không tự mã hóa dữ liệu ngoài HTTPS chuẩn)

Thêm Internal Testers (chính bạn/đồng nghiệp có Apple ID) để cài thử qua app TestFlight trên iPhone — không cần đợi Apple duyệt App Store công khai mới test được.



Giới hạn/ rủi ro đã biết — cần theo dõi qua build thật


Đây là lần đầu thêm iOS cho dự án vốn build ổn định trên Android — một số thư viện có thể chưa tương thích hoàn toàn với iOS (cần xem log lỗi thật nếu có, không đoán trước).

firebase_messaging/firebase_crashlytics cần thêm bước cấu hình APNs (Apple Push Notification) riêng trên Apple Developer nếu muốn thông báo đẩy hoạt động trên iOS — CHƯA làm trong phạm vi này, ưu tiên có bản build/TestFlight chạy được trước.

Quyền Face ID/Touch ID, Camera, Micro, Bluetooth đã khai đủ trong Info.plist, nhưng hành vi thực tế trên máy thật cần tự kiểm thử sau khi cài qua TestFlight.

