import '../config/constants.dart';

class PhotoUrlHelper {
  /// Returns the full URL for a user photo.
  /// Server-stored paths like `/uploads/abc.jpg` get the API base prepended.
  /// External URLs (already starting with http) pass through unchanged.
  static String fullUrl(String photoUrl) {
    if (photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    return '${AppConstants.apiBaseUrl}$photoUrl';
  }
}
