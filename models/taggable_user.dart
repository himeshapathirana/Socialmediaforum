class TaggableUser {
  final String id;
  final String displayName;
  final String? profilePicUrl;

  TaggableUser({
    required this.id,
    required this.displayName,
    this.profilePicUrl,
  });

  factory TaggableUser.fromJson(Map<String, dynamic> json) {
    // Determine best display name based on available fields
    String displayName = 'Anonymous';
    if (json['profileName'] != null &&
        json['profileName'].toString().isNotEmpty) {
      displayName = json['profileName'].toString();
    } else if (json['firstName'] != null &&
        json['firstName'].toString().isNotEmpty) {
      String firstName = json['firstName'].toString();
      String lastName =
          json['lastName'] != null ? json['lastName'].toString() : '';
      displayName = (firstName + ' ' + lastName).trim();
    }

    // Get profile pic if available
    String? profilePicUrl;
    if (json['profilePic'] != null &&
        json['profilePic'] is List &&
        (json['profilePic'] as List).isNotEmpty) {
      profilePicUrl = (json['profilePic'] as List).first.toString();
    }

    return TaggableUser(
      id: json['_id'].toString(),
      displayName: displayName,
      profilePicUrl: profilePicUrl,
    );
  }
}
