import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/sync/connectivity_service.dart';

/// Banner que aparece en la parte superior cuando no hay conexión.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (_, connectivity, __) {
        if (connectivity.isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: Colors.red.shade700,
          child: const SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Sin conexión — cambios se guardan localmente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
