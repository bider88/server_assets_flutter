import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

const api =
    'https://firebasestorage.googleapis.com/v0/b/storage-serve.appspot.com/o/1609870595474-GIMBeta4ene.zip?alt=media&token=3799fa86-6a28-49e3-843d-79d548d0c5ab';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {

  MyHomePage();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _dir;
  String nameZip;
  String name;
  bool filesNotDownloaded = true;

  @override
  void initState() {
    nameZip = _getNameZip();
    name = _getNameWithoutZip();
    _downloadAssets();
    print('_dir:::::::::::: $_dir');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: filesNotDownloaded ? CircularProgressIndicator() :
        Text('Contenidos descargados...'),
        // WebView(
        //   initialUrl: _dir + '/index.html'
        // ),
      ),
    );
  }

  Future<void> _downloadAssets() async {
    print('_downloadAssets>>>>>>>>>>>>>');
    if (_dir == null) {
      _dir = (await getApplicationDocumentsDirectory()).path;
    }

    print('_dir:::::::::::: $_dir');

    if (!await _hasToDownloadAssets(name, _dir)) {
      setState(() {
        filesNotDownloaded = false;
      });
      return;
    }

    var zippedFile = await _downloadFile(api, '$nameZip', _dir);

    var bytes = zippedFile.readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);

    for (var file in archive) {
      var filename = '$_dir/${file.name}';
      print('filename:::::::::::: $filename');
      if (file.isFile) {
        var outFile = File(filename);
        outFile = await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      }
    }
    setState(() {
      filesNotDownloaded = false;
    });
  }

  Future<bool> _hasToDownloadAssets(String name, String dir) async {
    var file = File('$dir/$name.zip');
    return !(await file.exists());
  }

  Future<File> _downloadFile(String url, String filename, String dir) async {
    print('start _downloadFile>>>>>>>>>>>>>');
    var req = await http.Client().get(Uri.parse(url));
    print('start _downloadFile>>>>>>>>>>>>>');
    var file = File('$dir/$filename');
    return file.writeAsBytes(req.bodyBytes);
  }

  String _getNameZip() {
    String keyToFind = '.zip';
    int posZip = api.lastIndexOf(keyToFind);
    String url = api.substring(0, posZip + keyToFind.length);
    List<String> splitUrl = url.split('/');
    String nameZip = splitUrl.lastWhere((split) => split.endsWith('.zip'));
    return nameZip;
  }
  
  String _getNameWithoutZip() {
    List<String> split = nameZip.split('.zip');
    return split[0];
  }

  File _getEntryPointFile(String dir) => File('$dir/index.html');
}