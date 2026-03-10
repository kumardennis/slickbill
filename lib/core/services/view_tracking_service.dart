import 'package:shared_preferences/shared_preferences.dart';

class ViewTrackingService {
  /// Check if invoice was viewed in last 30 days
  Future<bool> shouldTrackView(String invoiceToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewKey = 'viewed_invoice_$invoiceToken';
      final viewDate = prefs.getString(viewKey);
      
      if (viewDate != null) {
        final lastView = DateTime.parse(viewDate);
        final daysSinceView = DateTime.now().difference(lastView).inDays;
        
        if (daysSinceView < 30) {
          print('✅ Already viewed in last 30 days');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('❌ Error checking view tracking: $e');
      return true; // Track on error to be safe
    }
  }
  
  /// Mark invoice as viewed
  Future<void> markAsViewed(String invoiceToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewKey = 'viewed_invoice_$invoiceToken';
      await prefs.setString(viewKey, DateTime.now().toIso8601String());
      
      // Cleanup old views
      await _cleanupOldViews(prefs);
    } catch (e) {
      print('❌ Error marking as viewed: $e');
    }
  }
  
  /// Clean up views older than 30 days
  Future<void> _cleanupOldViews(SharedPreferences prefs) async {
    final keys = prefs.getKeys();
    final now = DateTime.now();
    
    for (final key in keys) {
      if (key.startsWith('viewed_invoice_')) {
        final dateStr = prefs.getString(key);
        if (dateStr != null) {
          final viewDate = DateTime.parse(dateStr);
          if (now.difference(viewDate).inDays > 30) {
            await prefs.remove(key);
          }
        }
      }
    }
  }
}