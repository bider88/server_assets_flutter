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
  bool filesNotDownloaded = false;
  bool filesDownloading = false;

  bool _loading = true;
  HttpServer _server;
  String _host = InternetAddress.loopbackIPv4.host;
  final _port = 8100;

  @override
  void initState() {
    nameZip = _getNameZip();
    name = _getNameWithoutZip();
    _verifyContentIsDownloaded();
    _startServer();
    print('initState:: _dir:::::::::::: $_dir');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: new Text('App'),
      ),
      body: Center(
        child: Column(
          children: [
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: (filesDownloading || filesNotDownloaded) ? null : _downloadAssets,
                  child: Text('Descargar contenido $filesDownloading $filesNotDownloaded')
                ),
                TextButton(
                  onPressed: filesDownloading ? null : filesNotDownloaded ? _deleteAssets : null,
                  child: Text('Eliminar contenido')
                ),
              ],
            ),
            filesDownloading ? LinearProgressIndicator() :
            filesNotDownloaded ? Text('Contenido descargado...') : Text('En espera de descarga de contenido...'),
            Container(
              width: double.infinity,
              height: 400,
              child: _loading ?
              Center(
                child: CircularProgressIndicator(),
              )
              : filesNotDownloaded ?
              WebView(
                initialUrl: 'http://127.0.0.1:$_port/',
                javascriptMode: JavascriptMode.unrestricted
              ) : Text(''),
            )
          ],
        ),
        // WebView(
        //   initialUrl: _dir + '/index.html'
        // ),
      ),
    );
  }

  Future<void> _downloadAssets() async {
    setState(() => filesDownloading = true );
    print('_downloadAssets>>>>>>>>>>>>>');
    await _checkDirectory();

    print('_dir:::::::::::: $_dir');

    if (!await _hasToDownloadAssets(name, _dir)) {
      setState(() {
        filesNotDownloaded = false;
        filesDownloading = false;
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
      filesNotDownloaded = true;
      filesDownloading = false;
    });
  }

  Future<void> _deleteAssets() async {
    print('_deleteAssets>>>>>>>>>>>>>');
    await _checkDirectory();

    print('_dir:::::::::::: $_dir');

    if (!await _hasToDownloadAssets(name, _dir)) {
      setState(() => filesDownloading = true );
      print('_deleting Assets>>>>>>>>>>>>>');
      final dir = Directory(_dir);
      dir.deleteSync(recursive: true);
      setState(() {
        filesNotDownloaded = false;
        filesDownloading = false;
      });
      print('_delete all Assets>>>>>>>>>>>>>');
      return;
    }
    print('do anything>>>>>>>>>>>>>');
    return;
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

  Future<void> _verifyContentIsDownloaded() async {
    await _checkDirectory();
    filesNotDownloaded = !await _hasToDownloadAssets(name, _dir);
    setState(() => {});
  }

  File _getEntryPointFile() => File('$_dir/index.html');


  Future<void> _checkDirectory() async {
    if (_dir == null) {
      _dir = (await getApplicationDocumentsDirectory()).path;
    }
  }

  _startServer() async {

    await _checkDirectory();

    File targetFile = _getEntryPointFile();

    _server = await HttpServer.bind(_host, _port);
    print(
      '1. Server running on IP : ' +
      _server.address.toString() +
      ' On Port : ' + _server.port.toString()
    );
    setState(() => _loading = false);
    await for (HttpRequest request in _server) {
      if (await targetFile.exists()) {
        print("Serving ${targetFile.path}.");
        request.response.headers.contentType = ContentType.html;
        try {
          await request.response.addStream(targetFile.openRead());
        } catch (e) {
          print("Couldn't read file: $e");
          exit(-1);
        }
      } else {
        print("Can't open ${targetFile.path}.");
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    }
  }
}