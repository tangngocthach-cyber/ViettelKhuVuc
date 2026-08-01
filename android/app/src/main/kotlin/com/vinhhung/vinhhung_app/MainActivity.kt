package com.vinhhung.vinhhung_app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * BẮT BUỘC dùng FlutterFragmentActivity (không phải FlutterActivity mặc định
 * mà `flutter create` tự sinh ra) - vì thư viện local_auth (đăng nhập vân
 * tay/Face ID) cần Activity kiểu FragmentActivity để hiển thị được hộp thoại
 * xác thực sinh trắc học của hệ thống Android.
 *
 * Lỗi thật đã gặp khi thiếu file này: "local_auth plugin requires activity
 * to be a FragmentActivity." - vì file này đặt SẴN trong repo (không phải do
 * `flutter create` tự sinh), bước rsync --ignore-existing trong CI sẽ GIỮ
 * NGUYÊN file này thay vì ghi đè bằng bản mặc định.
 */
class MainActivity : FlutterFragmentActivity()
