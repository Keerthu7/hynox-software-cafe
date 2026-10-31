Future<Map<String, String>> launchWhatsAppSignup({
  required String appId,
  required String configId,
  String? signupUrl,
}) => Future.error(
  UnsupportedError(
    'WhatsApp signup is not available in this BillDesk build. Open the deployed BillDesk web app or use a supported mobile app.',
  ),
);
