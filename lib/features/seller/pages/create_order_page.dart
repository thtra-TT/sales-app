import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../data/order_line.dart';
import '../data/seller_providers.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/customer_picker_sheet.dart';
import '../widgets/product_image.dart';
import '../widgets/qty_stepper.dart';
import 'item_picker_page.dart';
import 'product_picker_page.dart';

/// 1 sản phẩm + các mục đã chọn của nó (để hiển thị thành 1 khối).
class _Group {
  const _Group(this.productId, this.name, this.imageUrl, this.lines);
  final String productId;
  final String name;
  final String? imageUrl;
  final List<OrderLine> lines;

  double get total => lines.fold<double>(0, (s, l) => s + l.total);
}

/// Màn tạo đơn kiểu giỏ hàng Shopee: các khối trắng phẳng trên nền xám.
/// Khách hàng -> các sản phẩm (mỗi sản phẩm 1 khối, có ảnh) -> hóa đơn
/// -> chi tiết thanh toán. Thanh dưới cùng luôn hiện tổng tiền + nút Tạo đơn.
/// Tạo xong sẽ pop và trả về id đơn mới.
class CreateOrderPage extends ConsumerStatefulWidget {
  const CreateOrderPage({super.key});

  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  Customer? _customer;
  final Map<String, OrderLine> _lines = {}; // itemId -> dòng (mọi sản phẩm)
  final List<String> _productOrder = []; // thứ tự các sản phẩm đã thêm
  bool _needInvoice = false;
  bool _submitting = false;

  final _company = TextEditingController();
  final _taxCode = TextEditingController();
  final _invAddress = TextEditingController();
  final _invEmail = TextEditingController();

  @override
  void dispose() {
    _company.dispose();
    _taxCode.dispose();
    _invAddress.dispose();
    _invEmail.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _lines.values.fold<double>(0, (sum, l) => sum + l.total);

  List<_Group> get _groups {
    final result = <_Group>[];
    for (final pid in _productOrder) {
      final ls = _lines.values.where((l) => l.productId == pid).toList();
      if (ls.isNotEmpty) {
        result.add(_Group(pid, ls.first.productName, ls.first.productImageUrl, ls));
      }
    }
    return result;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickCustomer() async {
    final c = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CustomerPickerSheet(),
    );
    if (c != null && mounted) setState(() => _customer = c);
  }

  /// Chọn thêm 1 sản phẩm rồi chọn các mục của nó.
  Future<void> _addProduct() async {
    final p = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => const ProductPickerPage()),
    );
    if (p == null || !mounted) return;
    await _editProduct(p);
  }

  /// Mở màn chọn mục cho 1 sản phẩm (sản phẩm mới hoặc đã có trong đơn).
  Future<void> _editProduct(Product p) async {
    final initial = {
      for (final e in _lines.entries)
        if (e.value.productId == p.id) e.key: e.value,
    };
    final res = await Navigator.of(context).push<Map<String, OrderLine>>(
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(product: p, initial: initial),
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      _lines.removeWhere((_, l) => l.productId == p.id);
      _lines.addAll(res);
      if (res.isNotEmpty && !_productOrder.contains(p.id)) {
        _productOrder.add(p.id);
      }
    });
  }

  void _removeProduct(String productId) {
    setState(() => _lines.removeWhere((_, l) => l.productId == productId));
  }

  void _setQty(OrderLine l, int v) {
    setState(() {
      if (v <= 0) {
        _lines.remove(l.item.id);
      } else {
        _lines[l.item.id] = OrderLine(
          l.item,
          v,
          l.productName,
          productImageUrl: l.productImageUrl,
        );
      }
    });
  }

  Future<void> _submit() async {
    if (_customer == null) {
      _toast('Hãy chọn khách hàng');
      return;
    }
    if (_lines.isEmpty) {
      _toast('Chọn ít nhất 1 mục sản phẩm');
      return;
    }
    Map<String, dynamic>? invoice;
    if (_needInvoice) {
      if (_company.text.trim().isEmpty || _taxCode.text.trim().isEmpty) {
        _toast('Nhập tên công ty và mã số thuế để xuất hóa đơn');
        return;
      }
      invoice = {
        'company': _company.text.trim(),
        'tax_code': _taxCode.text.trim(),
        'address': _invAddress.text.trim(),
        'email': _invEmail.text.trim(),
      };
    }

    setState(() => _submitting = true);
    try {
      final id = await ref.read(sellerRepoProvider).createOrder(
            customerId: _customer!.id,
            needInvoice: _needInvoice,
            invoiceInfo: invoice,
            quantities: {
              for (final l in _lines.values) l.item.id: l.qty,
            },
          );
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      _toast(errorText(e));
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------- Các khối giao diện ----------

  /// Khối trắng phẳng. Dùng Material (không dùng Container có màu) để hiệu ứng
  /// bấm của ListTile / InkWell bên trong hiển thị đúng và không báo lỗi.
  Widget _block(ColorScheme cs, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(color: cs.surface, child: child),
      );

  Widget _customerBlock(ColorScheme cs) {
    final c = _customer;
    final detail = c == null
        ? ''
        : [c.contactChannel, c.address]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · ');
    return _block(cs, InkWell(
        onTap: _pickCustomer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: c == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Chọn hoặc thêm khách hàng',
                          style: TextStyle(fontSize: 15),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (c.phone != null && c.phone!.isNotEmpty)
                                  TextSpan(
                                    text: '   ${c.phone}',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyProducts(ColorScheme cs) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: cs.surface,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 56, color: cs.outline),
            const SizedBox(height: 12),
            const Text('Chưa có sản phẩm nào trong đơn'),
            const SizedBox(height: 4),
            Text(
              'Có thể thêm nhiều sản phẩm, mỗi sản phẩm nhiều mục',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Chọn sản phẩm'),
            ),
          ],
        ),
      );

  Widget _groupBlock(_Group g, ColorScheme cs) => _block(cs, Column(
          children: [
            // Tiêu đề sản phẩm (giống tên shop trong giỏ hàng)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editProduct(
                      Product(id: g.productId, name: g.name, imageUrl: g.imageUrl),
                    ),
                    child: const Text('Sửa'),
                  ),
                  IconButton(
                    tooltip: 'Xóa sản phẩm khỏi đơn',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: cs.outline),
                    onPressed: () => _removeProduct(g.productId),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Các mục đã chọn: ảnh + tên + giá + số lượng
            for (final l in g.lines) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductImage(url: l.imageUrl, size: 84),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatMoney(l.item.price),
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (l.qty > 1)
                                        Text(
                                          '= ${formatMoney(l.total)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                QtyBox(
                                  value: l.qty,
                                  onChanged: (v) => _setQty(l, v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 112),
            ],

            // Tổng của sản phẩm
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tổng (${g.lines.length} mục): ',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  Text(
                    formatMoney(g.total),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _addMoreButton(ColorScheme cs) => _block(cs, InkWell(
          onTap: _addProduct,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Thêm sản phẩm khác',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _invoiceBlock(ColorScheme cs) => _block(cs, Column(
          children: [
            SwitchListTile(
              secondary: Icon(Icons.receipt_long_outlined, color: cs.primary),
              title: const Text('Yêu cầu xuất hóa đơn'),
              value: _needInvoice,
              onChanged: (v) => setState(() => _needInvoice = v),
            ),
            if (_needInvoice)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _company,
                      decoration: const InputDecoration(
                        labelText: 'Tên công ty / cá nhân *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _taxCode,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Mã số thuế *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _invAddress,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ xuất hóa đơn',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _invEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email nhận hóa đơn',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _summaryBlock(
    ColorScheme cs, {
    required double subtotal,
    required double discount,
    required double total,
    required String? rankName,
  }) {
    final saved = subtotal - total;
    Widget row(String label, String value,
            {Color? color, bool bold = false, double size = 14}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: bold ? null : cs.onSurfaceVariant,
                    fontWeight: bold ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: size,
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        );

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          row('Tổng tiền hàng', formatMoney(subtotal)),
          row(
            'Giảm giá hạng ${rankName ?? '-'} (${formatPercent(discount)}%)',
            saved > 0 ? '-${formatMoney(saved)}' : '0 đ',
            color: saved > 0 ? cs.primary : null,
          ),
          const Divider(height: 16),
          row(
            'Tổng thanh toán',
            formatMoney(total),
            color: cs.primary,
            bold: true,
            size: 17,
          ),
          const SizedBox(height: 6),
          Text(
            'Giảm giá theo hạng thành viên hiện tại, được chốt khi tạo đơn.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(profileProvider).value;
    final discount = profile?.discountPercent ?? 0;
    final subtotal = _subtotal;
    final total = (subtotal * (1 - discount / 100)).roundToDouble();
    final groups = _groups;
    final saved = subtotal - total;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo đơn hàng')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _customerBlock(cs),
          if (groups.isEmpty) _emptyProducts(cs),
          for (final g in groups) _groupBlock(g, cs),
          if (groups.isNotEmpty) _addMoreButton(cs),
          _invoiceBlock(cs),
          _summaryBlock(
            cs,
            subtotal: subtotal,
            discount: discount,
            total: total,
            rankName: profile?.rankName,
          ),
        ],
      ),
      bottomNavigationBar: ActionBottomBar(
        caption: 'Tổng thanh toán',
        amount: formatMoney(total),
        note: saved > 0 ? 'Tiết kiệm ${formatMoney(saved)}' : null,
        buttonLabel:
            _lines.isEmpty ? 'Tạo đơn' : 'Tạo đơn (${_lines.length})',
        dimmed: _lines.isEmpty,
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }
}