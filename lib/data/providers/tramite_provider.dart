import 'package:sp1_mobile/core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TramiteProvider {

  final http.Client _httpClient = http.Client();

// GET /api/tramites/ticket/{ticketNumber} (Obtener estado inicial)
  Future<http.Response> getTramiteByTicket(String ticketNumber) async {
    final url = Uri.parse("${ApiConstants.baseUrl}/tramites/ticket/$ticketNumber");
    return await _httpClient.get(url);
  }

  // POST /api/tramites/ticket/{ticketNumber}/fcm-token (Registrar Push)
  Future<http.Response> postFcmToken(String ticketNumber, String fcmToken) async {
    final url = Uri.parse("${ApiConstants.baseUrl}/tramites/ticket/$ticketNumber/fcm-token");
    return await _httpClient.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"fcmToken": fcmToken}),
    );
  }

  // GET /api/policies/public (Catálogo de trámites)
  Future<http.Response> getPublicPolicies() async {
    final url = Uri.parse("${ApiConstants.baseUrl}/policies/public");
    return await _httpClient.get(url);
  }
}