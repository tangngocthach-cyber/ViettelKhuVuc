# ============================================================================
# BẮT BUỘC phải có file này - nếu không, bản build RELEASE (bản build thật để
# cài lên máy, khác với bản debug lúc code thử) sẽ bị lỗi:
#   "TypeToken must be created with a type argument... When using code
#   shrinkers (ProGuard, R8, ...) make sure that generic signatures are
#   preserved."
#
# NGUYÊN NHÂN: Android tự động RÚT GỌN code (R8) khi build bản release để file
# nhỏ hơn, chạy nhanh hơn - nhưng nó lỡ xóa mất thông tin "kiểu dữ liệu chi
# tiết" (generic type signature) mà thư viện flutter_local_notifications cần
# dùng để đọc/ghi danh sách lịch nhắc hẹn đã lưu. Thiếu file này, MỌI lần đặt
# lịch nhắc hẹn (Sổ ghi chú, Nhắc hẹn trong Chat) đều crash âm thầm.
# ============================================================================

# Giữ nguyên toàn bộ code của thư viện flutter_local_notifications
-keep class com.dexterous.** { *; }

# Giữ nguyên thông tin "kiểu dữ liệu chi tiết" (generic) - PHẦN QUAN TRỌNG
# NHẤT, chính là thứ bị thiếu gây ra lỗi TypeToken ở trên
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Thư viện Gson (được flutter_local_notifications dùng bên trong để lưu lịch
# nhắc hẹn dạng JSON) - giữ nguyên để không bị lỗi tương tự
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**
