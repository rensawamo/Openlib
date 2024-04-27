import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'files.dart';

Future<String> _getFilePath(String fileName) async {
  final path = await getAppDirectoryPath;
  return '$path/$fileName';
}

List<String> _reorderMirrors(List<String> mirrors) {
  List<String> ipfsMirrors = [];
  List<String> httpsMirrors = [];

  for (var element in mirrors) {
    if (element.contains('ipfs') == true) {
      ipfsMirrors.add(element);
    } else {
      if (element.startsWith('https://annas-archive.org') != true &&
          element.startsWith('https://1lib.sk') != true) {
        httpsMirrors.add(element);
      }
    }
  }
  return [...ipfsMirrors, ...httpsMirrors];
}

// 生きている ミラーのサイトを返す
Future<String?> _getAliveMirror(List<String> mirrors) async {
  Dio dio = Dio();
  for (var url in mirrors) {
    try {
      final response = await dio.head(url,
          options: Options(receiveTimeout: const Duration(seconds: 10)));
      if (response.statusCode == 200) {
        dio.close();
        return url;
      }
    } catch (_) {
      // print("timeOut");
    }
  }
  return null;
}

Future<void> downloadFile(
    {required List<String> mirrors,
    required String md5,
    required String format,
    // provider で 状態をリアルタイムで更新するための関数
    required Function onStart,
    required Function onProgress,
    required Function cancelDownlaod,
    required Function mirrorStatus,
    required Function onDownlaodFailed}) async {
  if (mirrors.isEmpty) {
    onDownlaodFailed('No mirrors available!');
  } else {
    Dio dio = Dio();

    String path = await _getFilePath('$md5.$format');
    List<String> orderedMirrors = _reorderMirrors(mirrors);

    String? workingMirror = await _getAliveMirror(orderedMirrors);

    // print(workingMirror);
    // print(path);
    // print(orderedMirrors);
    // print(orderedMirrors[0]);

    if (workingMirror != null) {
      onStart();  // run 状態に戻す
      try {
        CancelToken cancelToken = CancelToken();
        dio.download(
          workingMirror,
          path,
          options: Options(headers: {
            //このヘッダーは、リクエストを行っているクライアント（この場合はブラウザ）に関する情報をサーバーに提供. ブラウザの最適化
            'Connection': 'Keep-Alive',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36'
          }),
          onReceiveProgress: (rcv, total) {
            if (!(rcv.isNaN || rcv.isInfinite) &&
                !(total.isNaN || total.isInfinite)) {
              onProgress(rcv, total);
            }
          },
          deleteOnError: true,
          cancelToken: cancelToken,
        ).catchError((err) {
          if (err.type != DioExceptionType.cancel) {
            onDownlaodFailed('downloaded Failed! try again...');
          }
          throw err;
        });

        mirrorStatus(true);

        cancelDownlaod(cancelToken);
      } catch (_) {
        onDownlaodFailed('downloaded Failed! try again...');
      }
    } else {
      onDownlaodFailed('No working mirrors available to download book!');
    }
  }
}

Future<bool> verifyFileCheckSum(
    {required String md5Hash, required String format}) async {
  try {
    final path = await getAppDirectoryPath;
    final filePath = '$path/$md5Hash.$format';
    final file = File(filePath);
    final stream = file.openRead();
    final hash = await md5.bind(stream).first;
    if (md5Hash == hash.toString()) {
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
