abstract interface class ProfileAvatarPreferences {
  Future<String?> read(String userId);
  Future<void> write(String userId, String assetPath);
}
