import 'package:flutter/material.dart';
import '../theme.dart';

/// Máy tính bỏ túi - 4 phép tính cơ bản (+, -, ×, ÷), phần trăm, đổi dấu.
/// Hoạt động kiểu máy tính điện thoại quen thuộc: bấm số -> bấm phép tính ->
/// bấm số tiếp -> bấm "=" ra kết quả. Không cần thư viện ngoài, tự viết logic
/// đơn giản, không có rủi ro phụ thuộc.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _hienThi = '0';
  double? _soDauTien;
  String? _phepTinhDangCho;
  bool _batDauSoMoi = false;

  void _bamSo(String so) {
    setState(() {
      if (_hienThi == '0' || _batDauSoMoi) {
        _hienThi = so;
        _batDauSoMoi = false;
      } else {
        if (_hienThi.length >= 14) return; // tránh tràn màn hình
        _hienThi += so;
      }
    });
  }

  void _bamDauPhay() {
    setState(() {
      if (_batDauSoMoi) {
        _hienThi = '0,';
        _batDauSoMoi = false;
        return;
      }
      if (!_hienThi.contains(',')) _hienThi += ',';
    });
  }

  double _giaTriHienTai() => double.parse(_hienThi.replaceAll(',', '.'));

  String _dinhDangKetQua(double so) {
    // Bỏ .0 thừa nếu là số nguyên, giới hạn tối đa 10 chữ số thập phân
    if (so == so.roundToDouble() && so.abs() < 1e12) {
      return so.toStringAsFixed(0);
    }
    String s = so.toStringAsFixed(10);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s.replaceAll('.', ',');
  }

  void _bamPhepTinh(String phepTinh) {
    setState(() {
      if (_soDauTien != null && _phepTinhDangCho != null && !_batDauSoMoi) {
        _tinhKetQua();
      }
      _soDauTien = _giaTriHienTai();
      _phepTinhDangCho = phepTinh;
      _batDauSoMoi = true;
    });
  }

  void _tinhKetQua() {
    if (_soDauTien == null || _phepTinhDangCho == null) return;
    final b = _giaTriHienTai();
    double ketQua;
    switch (_phepTinhDangCho) {
      case '+':
        ketQua = _soDauTien! + b;
        break;
      case '-':
        ketQua = _soDauTien! - b;
        break;
      case '×':
        ketQua = _soDauTien! * b;
        break;
      case '÷':
        if (b == 0) {
          setState(() {
            _hienThi = 'Không chia được cho 0';
            _soDauTien = null;
            _phepTinhDangCho = null;
            _batDauSoMoi = true;
          });
          return;
        }
        ketQua = _soDauTien! / b;
        break;
      default:
        return;
    }
    setState(() {
      _hienThi = _dinhDangKetQua(ketQua);
      _soDauTien = null;
      _phepTinhDangCho = null;
      _batDauSoMoi = true;
    });
  }

  void _xoaHet() {
    setState(() {
      _hienThi = '0';
      _soDauTien = null;
      _phepTinhDangCho = null;
      _batDauSoMoi = false;
    });
  }

  void _doiDau() {
    setState(() {
      final gt = _giaTriHienTai();
      _hienThi = _dinhDangKetQua(-gt);
    });
  }

  void _phanTram() {
    setState(() {
      final gt = _giaTriHienTai();
      _hienThi = _dinhDangKetQua(gt / 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Máy tính'), backgroundColor: AppTheme.viettelRed),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomRight,
                  child: Text(_hienThi, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w300)),
                ),
              ),
            ),
            _hangNut([
              _NutMayTinh('C', mau: Colors.grey.shade600, onTap: _xoaHet),
              _NutMayTinh('±', mau: Colors.grey.shade600, onTap: _doiDau),
              _NutMayTinh('%', mau: Colors.grey.shade600, onTap: _phanTram),
              _NutMayTinh('÷', mau: AppTheme.viettelRed, onTap: () => _bamPhepTinh('÷')),
            ]),
            _hangNut([
              _NutMayTinh('7', onTap: () => _bamSo('7')),
              _NutMayTinh('8', onTap: () => _bamSo('8')),
              _NutMayTinh('9', onTap: () => _bamSo('9')),
              _NutMayTinh('×', mau: AppTheme.viettelRed, onTap: () => _bamPhepTinh('×')),
            ]),
            _hangNut([
              _NutMayTinh('4', onTap: () => _bamSo('4')),
              _NutMayTinh('5', onTap: () => _bamSo('5')),
              _NutMayTinh('6', onTap: () => _bamSo('6')),
              _NutMayTinh('-', mau: AppTheme.viettelRed, onTap: () => _bamPhepTinh('-')),
            ]),
            _hangNut([
              _NutMayTinh('1', onTap: () => _bamSo('1')),
              _NutMayTinh('2', onTap: () => _bamSo('2')),
              _NutMayTinh('3', onTap: () => _bamSo('3')),
              _NutMayTinh('+', mau: AppTheme.viettelRed, onTap: () => _bamPhepTinh('+')),
            ]),
            _hangNut([
              _NutMayTinh('0', rong: true, onTap: () => _bamSo('0')),
              _NutMayTinh(',', onTap: _bamDauPhay),
              _NutMayTinh('=', mau: AppTheme.viettelRed, onTap: _tinhKetQua),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _hangNut(List<_NutMayTinh> nuts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: nuts.map((n) => n.rong ? Expanded(flex: 2, child: n) : Expanded(child: n)).toList()),
    );
  }
}

class _NutMayTinh extends StatelessWidget {
  final String nhan;
  final Color? mau;
  final bool rong;
  final VoidCallback onTap;
  const _NutMayTinh(this.nhan, {this.mau, this.rong = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AspectRatio(
        aspectRatio: rong ? 2 : 1,
        child: Material(
          color: mau ?? Colors.grey.shade900,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(nhan, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}
