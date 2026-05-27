import '../../../l10n/l10n.dart';

sealed class CameraMessage {
  const CameraMessage();

  String localize(AppLocalizations localizations);
}

class CameraNoCameraFoundMessage extends CameraMessage {
  const CameraNoCameraFoundMessage();

  @override
  String localize(AppLocalizations localizations) {
    return localizations.cameraNoCameraFound;
  }
}

class CameraStartingMessage extends CameraMessage {
  const CameraStartingMessage();

  @override
  String localize(AppLocalizations localizations) {
    return localizations.cameraStartingCamera;
  }
}

class CameraErrorMessage extends CameraMessage {
  const CameraErrorMessage(this.message);

  final String message;

  @override
  String localize(AppLocalizations localizations) {
    return localizations.cameraErrorMessage(message);
  }
}
