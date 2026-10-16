import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';

String billMessage(CafeOrder order, String business, [int? templateIndex]) {
  final shop = order.businessName.isEmpty ? business : order.businessName;
  final tIdx = templateIndex ?? 0;
  final tName = switch (tIdx) {
    1 => 'Executive Modern (A5)',
    2 => 'Itemized Breakdown (Detailed)',
    _ => 'Thermal Receipt (80mm)',
  };
  return [
    'Hello ${order.customer},',
    order.profile.greeting.isNotEmpty ? order.profile.greeting : 'Thank you for your visit!',
    '',
    shop,
    'Tax Invoice #${order.id}',
    'Format: $tName',
    '${shortDate(order.createdAt)} ${clockTime(order.createdAt)}',
    '--------------------------------',
    for (final line in order.lines)
      '${line.name} × ${line.quantity}: ${money(line.total)}',
    '--------------------------------',
    'Subtotal: ${money(order.subtotal)}',
    if (order.discount > 0) 'Discount: -${money(order.discount)}',
    'Tax: ${money(order.tax)}',
    'Total paid: ${money(order.total)} (${order.paymentMethod ?? 'Paid'})',
    '',
    '📄 PDF Invoice (${order.id}-receipt.pdf) generated with $tName layout.',
    if (order.profile.reviewUrl.isNotEmpty) ...[
      '',
      order.profile.reviewUrl.isEmpty
          ? 'Please share your review with us.'
          : 'Share your review: ${order.profile.reviewUrl}',
    ],
  ].join('\n');
}

Future<bool> openWhatsAppMessage(
  CafeOrder order,
  String business, {
  int? selectedTemplate,
}) async {
  String cleanPhone = order.phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanPhone.length == 10) {
    cleanPhone = '91$cleanPhone';
  }
  final text = Uri.encodeComponent(billMessage(order, business, selectedTemplate));
  final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    return launched;
  } catch (_) {
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}

