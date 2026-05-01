import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin HTTP REST client for the Python aiohttp server.
class ApiService {
  final String host; // e.g. "192.168.1.100:8765"

  const ApiService(this.host);

  /// GET /devices — returns list of known device IDs.
  Future<List<String>> fetchDevices() async {
    final uri = Uri.parse('http://$host/devices');
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) return [];
    final list = jsonDecode(resp.body) as List;
    return list.cast<String>();
  }
}
