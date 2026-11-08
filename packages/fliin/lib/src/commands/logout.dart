import '../license/license_store.dart';
import 'project_command.dart';

/// Efface la clé de licence que `fliin login` a rangée.
class LogoutCommand extends ProjectCommand {
  LogoutCommand(super.openRegistry, super.io, this.licenses);

  final LicenseStore licenses;

  @override
  String get name => 'logout';

  @override
  String get description =>
      'Deletes the Fliin Pro license key that fliin login saved.';

  @override
  Future<int> execute() async {
    final path = licenses.path;
    final deleted = licenses.delete();
    return succeed(
      {'deleted': deleted, 'path': path},
      [
        if (deleted)
          'License key deleted from $path.'
        else
          'No saved license key ($path).',
        if (licenses.fromEnvironment)
          '${LicenseStore.variable} is still set: unset it to stop using '
              'Fliin Pro.',
      ],
    );
  }
}
