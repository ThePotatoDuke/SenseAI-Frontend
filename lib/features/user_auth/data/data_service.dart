import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  final status = await Permission.storage.request();
  if (!status.isGranted) {
    throw Exception("Storage permission not granted");
  }
}
