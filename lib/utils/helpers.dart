import 'package:url_launcher/url_launcher.dart';

Future<void> launchWeb(String url) async {
  // если нет http/https — добавим http
  final normalized = (url.startsWith('http://') || url.startsWith('https://'))
      ? url
      : 'http://$url';

  final uri = Uri.parse(normalized);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $normalized');
  }
}