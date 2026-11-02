import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Map<String, String>> launchWhatsAppSignup({
  required String appId,
  required String configId,
  String? signupUrl,
}) async {
  if (signupUrl == null || signupUrl.isEmpty) {
    throw StateError('The BillDesk server has no public website URL configured. Please contact your BillDesk administrator.');
  }
  final base = Uri.tryParse(signupUrl);
  if (base == null || base.scheme != 'https' || base.host.isEmpty) {
    throw StateError('WhatsApp signup requires the secure HTTPS URL of the deployed BillDesk website.');
  }

  final random = Random.secure();
  final stateBytes = List<int>.generate(32, (_) => random.nextInt(256));
  final state = base64UrlEncode(stateBytes).replaceAll('=', '');
  const returnScheme = 'billdesk';
  final signupUri = base.resolve('/whatsapp-signup.html').replace(
    queryParameters: {
      'appId': appId,
      'configId': configId,
      'state': state,
      'returnScheme': returnScheme,
    },
  );

  final links = AppLinks();
  final result = Completer<Map<String, String>>();
  late final StreamSubscription<Uri> subscription;
  Timer? timeout;

  void cleanUp() {
    timeout?.cancel();
    subscription.cancel();
  }

  subscription = links.uriLinkStream.listen((uri) {
    if (uri.scheme != returnScheme || uri.host != 'whatsapp-connect') return;
    if (uri.queryParameters['state'] != state) return;
    final error = uri.queryParameters['error'];
    if (error != null) {
      if (!result.isCompleted) result.completeError(StateError(error));
    } else {
      final code = uri.queryParameters['code'] ?? '';
      final wabaId = uri.queryParameters['wabaId'] ?? '';
      final phoneNumberId = uri.queryParameters['phoneNumberId'] ?? '';
      if (code.isEmpty || wabaId.isEmpty) {
        if (!result.isCompleted) result.completeError(StateError('Meta did not return the WhatsApp account details. Please try again.'));
      } else if (!result.isCompleted) {
        result.complete({'code': code, 'wabaId': wabaId, 'phoneNumberId': phoneNumberId});
      }
    }
    cleanUp();
  });

  timeout = Timer(const Duration(minutes: 6), () {
    if (!result.isCompleted) result.completeError(StateError('WhatsApp signup timed out. Return to BillDesk and try again.'));
    cleanUp();
  });

  try {
    final opened = await launchUrl(signupUri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('Could not open the device browser for Meta signup.');
  } catch (_) {
    cleanUp();
    rethrow;
  }
  return result.future;
}
