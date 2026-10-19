import '../../../../core/api/api_client.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_preview_repository.dart';
import 'remote_profile_repository.dart';

/// Set PROFILE_PREVIEW=true at build/run time to preview profile UI without
/// profile API calls. The default remains the real backend repository.
const bool profilePreviewMode =
    bool.fromEnvironment('PROFILE_PREVIEW', defaultValue: false);

ProfileRepository createProfileRepository(
  ApiClient apiClient, {
  bool previewMode = profilePreviewMode,
}) {
  // To restore live profile API calls, run without --dart-define=PROFILE_PREVIEW=true.
  return previewMode
      ? ProfilePreviewRepository()
      : RemoteProfileRepository(apiClient);
}
