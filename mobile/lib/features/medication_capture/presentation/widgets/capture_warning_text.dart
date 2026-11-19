import '../../domain/capture_models.dart';

/// Short, specific advice for a photo quality warning (G4), shared by the
/// review screen and the scan screen.
String captureWarningMessage(CaptureWarning value) => switch (value) {
      CaptureWarning.dark => 'Ảnh quá tối. Hãy chụp lại ở nơi đủ sáng.',
      CaptureWarning.blurred => 'Ảnh bị mờ. Hãy giữ máy chắc và chụp lại.',
      CaptureWarning.bright => 'Có vùng quá sáng. Thử đổi góc chụp.',
      CaptureWarning.lowTexture => 'Kiểm tra ảnh trước khi sử dụng.',
    };
