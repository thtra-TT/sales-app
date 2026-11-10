import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, StorageException, FunctionException;

import '../../core/providers.dart';

final _moneyFmt = NumberFormat.decimalPattern('vi_VN');
final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');
final _dateFmt = DateFormat('dd/MM/yyyy');

String money(num v) => '${_moneyFmt.format(v)} đ';
String fmtDateTime(DateTime? d) => d == null ? '-' : _dateTimeFmt.format(d);
String fmtDate(DateTime d) => _dateFmt.format(d);

/// Lấy thông báo lỗi dễ đọc (kể cả message từ trigger của Postgres).
String errorText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return d?.toString() ?? 'Lỗi máy chủ (${e.status}). Đã deploy Edge Function chưa?';
  }
  return e.toString();
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          error ? Theme.of(context).colorScheme.errorContainer : null,
    ));
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: 'Đăng xuất',
        icon: const Icon(Icons.logout),
        onPressed: () => ref.read(supabaseProvider).auth.signOut(),
      );
}

/// Hiện loading / lỗi (có nút thử lại) / dữ liệu.
class FutureBody<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  const FutureBody({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorText(snap.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: onRetry, child: const Text('Thử lại')),
                  ],
                ),
              ),
            );
          }
          return builder(snap.data as T);
        },
      );
}

/// Số tiền nhập tay: chấp nhận "1.500.000" hoặc "1500000" hoặc "1500,5".
double? parseMoney(String text) =>
    double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));