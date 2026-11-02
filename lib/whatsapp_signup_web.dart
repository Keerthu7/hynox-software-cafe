import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<Map<String, String>> launchWhatsAppSignup({
  required String appId,
  required String configId,
  String? signupUrl,
}) async {
  final origin = html.window.location.origin;
  final signupOrigin = signupUrl == null || signupUrl.isEmpty ? origin : Uri.parse(signupUrl).origin;
  final popup = html.window.open(
    'about:blank',
    'billdesk-whatsapp-signup',
    'popup=yes,width=680,height=760,scrollbars=yes,resizable=yes',
  );
  if (popup == null) {
    throw StateError('Your browser blocked the Meta signup popup. Allow popups for BillDesk and try again.');
  }

  final completer = Completer<Map<String, String>>();
  late StreamSubscription<html.MessageEvent> subscription;
  Timer? timeout;
  Timer? closePoll;
  void finishError(Object error) {
    if (completer.isCompleted) return;
    completer.completeError(error);
    popup.close();
    subscription.cancel();
    timeout?.cancel();
    closePoll?.cancel();
  }

  subscription = html.window.onMessage.listen((event) {
    if (event.origin != signupOrigin || event.data is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(event.data as String);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    if (data['source'] != 'billdesk-whatsapp-signup') return;
    if (data['error'] != null) {
      finishError(StateError(data['error'].toString()));
      return;
    }
    final code = data['code']?.toString() ?? '';
    final wabaId = data['wabaId']?.toString() ?? '';
    final phoneNumberId = data['phoneNumberId']?.toString() ?? '';
    if (code.isEmpty || wabaId.isEmpty) {
      finishError(StateError('Meta signup did not return the required account details. Please try again.'));
      return;
    }
    if (!completer.isCompleted) {
      completer.complete({'code': code, 'wabaId': wabaId, 'phoneNumberId': phoneNumberId});
    }
    popup.close();
    subscription.cancel();
    timeout?.cancel();
    closePoll?.cancel();
  });

  final signupUri = Uri.parse('$signupOrigin/whatsapp-signup.html').replace(
    queryParameters: {'appId': appId, 'configId': configId, 'parentOrigin': origin},
  );
  popup.location.href = signupUri.toString();
  // The signup page has its own five-minute timer that returns a detailed
  // Meta/session diagnostic. Keep this parent timeout later so it cannot
  // replace that message with a generic timeout.
  timeout = Timer(const Duration(minutes: 6), () {
    finishError(StateError('Meta signup timed out. Please start the connection again.'));
  });
  closePoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
    if (popup.closed == true) finishError(StateError('Meta signup was closed before it finished.'));
  });
  return completer.future;
}
