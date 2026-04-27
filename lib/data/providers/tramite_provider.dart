import 'package:sp1_mobile/core/constants/api_constants.dart';
import 'package:http/http.dart' as http;

class TramiteProvider {

// GET /api/tramites/ticket/{ticketNumber} (Obtener estado inicial)
  Future<http.Response> getTramiteByTicket(String ticketNumber) async {
    final url = Uri.parse("${ApiConstants.baseUrl}/tramites/ticket/$ticketNumber");
    return await http.get(url);
  }

  // GET /api/policies/public (Catálogo de trámites)
  Future<http.Response> getPublicPolicies() async {
    final url = Uri.parse("${ApiConstants.baseUrl}/policies/public");
    return await http.get(url);
  }
}
