import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import '../theme.dart';

/// Đèn pin - bật/tắt đèn flash camera sau. Tự tắt khi thoát màn hình (tránh
/// quên bật làm hao pin).
class DenPinScreen extends StatefulWidget {
  const DenPinScreen({super.key});

  @override
  State<DenPinScreen> createState() => _DenPinScreenState();
}

class _DenPinScreenState extends State<DenPinScreen> {
  bool _dangBat = false;
  bool _khongHoTro = false;
  String? _loi;

  @override
  void dispose() {
    // Tự tắt đèn khi rời màn hình - tránh quên tắt làm hao pin máy
    if (_dangBat) {
      TorchLight.disableTorch().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _batTat() async {
    setState(() => _loi = null);
    try {
      if (_dangBat) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _dangBat = !_dangBat);
    } on Exception {
      setState(() {
        _khongHoTro = true;
        _loi = 'Thiết bị không hỗ trợ đèn flash, hoặc app chưa được cấp quyền Camera.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dangBat ? Colors.white : Colors.black,
      appBar: AppBar(
        title: const Text('Đèn pin'),
        backgroundColor: _dangBat ? AppTheme.viettelRed : null,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _khongHoTro ? null : _batTat,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dangBat ? AppTheme.viettelRed : Colors.grey.shade800,
                  boxShadow: _dangBat ? [BoxShadow(color: AppTheme.viettelRed.withValues(alpha: .5), blurRadius: 40, spreadRadius: 10)] : [],
                ),
                child: Icon(
                  _dangBat ? Icons.flashlight_on : Icons.flashlight_off,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _dangBat ? 'Đang bật' : 'Đã tắt',
              style: TextStyle(fontSize: 16, color: _dangBat ? Colors.black87 : Colors.white70, fontWeight: FontWeight.w600),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(_loi!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
