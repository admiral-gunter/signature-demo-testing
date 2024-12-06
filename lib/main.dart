import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String pathPDF = "";
  String landscapePathPdf = "";
  String remotePDFpath = "";
  String corruptedPathPDF = "";

  @override
  void initState() {
    super.initState();
    fromAsset('assets/corrupted.pdf', 'corrupted.pdf').then((f) {
      setState(() {
        corruptedPathPDF = f.path;
      });
    });
    fromAsset('assets/demo-link.pdf', 'demo.pdf').then((f) {
      setState(() {
        pathPDF = f.path;
      });
    });
    fromAsset('assets/demo-landscape.pdf', 'landscape.pdf').then((f) {
      setState(() {
        landscapePathPdf = f.path;
      });
    });

    createFileOfPdfUrl().then((f) {
      setState(() {
        remotePDFpath = f.path;
      });
    });
  }

  Future<File> createFileOfPdfUrl() async {
    Completer<File> completer = Completer();
    print("Start download file from internet!");
    try {
      // "https://berlin2017.droidcon.cod.newthinking.net/sites/global.droidcon.cod.newthinking.net/files/media/documents/Flutter%20-%2060FPS%20UI%20of%20the%20future%20%20-%20DroidconDE%2017.pdf";
      // final url = "https://pdfkit.org/docs/guide.pdf";
      final url = "http://www.pdf995.com/samples/pdf.pdf";
      final filename = url.substring(url.lastIndexOf("/") + 1);
      var request = await HttpClient().getUrl(Uri.parse(url));
      var response = await request.close();
      var bytes = await consolidateHttpClientResponseBytes(response);
      var dir = await getApplicationDocumentsDirectory();
      print("Download files");
      print("${dir.path}/$filename");
      File file = File("${dir.path}/$filename");

      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file! $e');
    }

    return completer.future;
  }

  Future<File> fromAsset(String asset, String filename) async {
    // To open from assets, you can copy them to the app storage folder, and the access them "locally"
    Completer<File> completer = Completer();

    try {
      var dir = await getApplicationDocumentsDirectory();
      File file = File("${dir.path}/$filename");
      var data = await rootBundle.load(asset);
      var bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file! $e');
    }

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter PDF View',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                TextButton(
                  child: Text("Open PDF"),
                  onPressed: () {
                    if (pathPDF.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: pathPDF),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Open Landscape PDF"),
                  onPressed: () {
                    if (landscapePathPdf.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PDFScreen(path: landscapePathPdf),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Remote PDF"),
                  onPressed: () {
                    if (remotePDFpath.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: remotePDFpath),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Open Corrupted PDF"),
                  onPressed: () {
                    if (pathPDF.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PDFScreen(path: corruptedPathPDF),
                        ),
                      );
                    }
                  },
                )
              ],
            );
          },
        )),
      ),
    );
  }
}

class PDFScreen extends StatefulWidget {
  final String? path;

  PDFScreen({Key? key, this.path}) : super(key: key);

  _PDFScreenState createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with WidgetsBindingObserver {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();

  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  String imgSignaturePath = "";
  List<Map<String, dynamic>> _listSignature = [];
  File? savedFile;

  double xPosition = 50;
  double yPosition = 50;
  double width = 300;
  double height = 150;

  List<Map<String, dynamic>> items = [
    // {
    //   'x': 50.0,
    //   'y': 50.0,
    //   'width': 300.0,
    //   'height': 150.0,
    //   'file': 'path/to/file1.png'
    // },
    // {
    //   'x': 100.0,
    //   'y': 200.0,
    //   'width': 200.0,
    //   'height': 100.0,
    //   'file': 'path/to/file2.png'
    // },
    // Add more items as needed
  ];

  void showSignatureDialog(BuildContext context) {
    final SignatureController _controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Draw your signature', style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.transparent,
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      _controller.clear();
                    },
                    child: Text('Clear'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final signature = await _controller.toPngBytes();
                      if (signature != null) {
                        await saveSignatureAsPng(signature);
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> saveSignatureAsPng(Uint8List signature) async {
    // Decode bytes to an image object for additional processing
    // final img.Image? image = img.decodeImage(signature);
    // if (image != null) {
    //   // Save or use the image as needed
    //   // Example: Save the image to a file
    //   // Uncomment the following if using path_provider to get a directory:
    //   // final directory = await getApplicationDocumentsDirectory();
    //   // final path = '${directory.path}/signature.png';
    //   // final file = File(path);
    //   // await file.writeAsBytes(img.encodePng(image));
    //   print('Signature saved!');
    // }

    final img.Image? image = img.decodeImage(signature);
    if (image != null) {
      // Ensure the image has an alpha channel
      final transparentImage = img.Image.from(
        image,
      );

      // Encode the processed image back to PNG
      final Uint8List pngBytes =
          Uint8List.fromList(img.encodePng(transparentImage));

      // Get the downloads directory
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String fileName = 'signature_$timestamp.png';
        final File file = File('${downloadsDir.path}/$fileName');

        // Write the PNG bytes to the file
        await file.writeAsBytes(pngBytes);
        // setState(() {
        //   savedFile = file;
        // });

        // setState(() {
        //   _listSignature.add({'signature': file});
        // });

        setState(() {
          items.add({
            'x': 50.0,
            'y': 50.0,
            'width': 200.0,
            'height': 100.0,
            'file': file,
            'page': currentPage,
            'selected': true
          });
        });

        print('Signature saved as ${file.path}');
      } else {
        print('Failed to find downloads directory.');
      }
    } else {
      print('Failed to decode image.');
    }
  }

  double _currentScale = 1.0;
  Offset _currentOffset = Offset.zero; // Track the current pan offset

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          InteractiveViewer(
            onInteractionUpdate: (details) {
              setState(() {
                // _currentScale = double.parse(details.scale.toStringAsFixed(2));

                _currentScale =
                    max(1.0, double.parse(details.scale.toStringAsFixed(10)));
                _currentOffset = details.focalPoint; // Track pan offset
                // _currentScale =
                print('new $_currentScale');
              });
            },
            child: PDFView(
              filePath: widget.path,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: true,
              pageSnap: true,
              defaultPage: currentPage!,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation:
                  false, // if set to true the link is handled in flutter
              backgroundColor: Colors.black,
              onRender: (_pages) {
                setState(() {
                  pages = _pages;
                  isReady = true;
                });
              },
              onError: (error) {
                setState(() {
                  errorMessage = error.toString();
                });
                print(error.toString());
              },
              onPageError: (page, error) {
                setState(() {
                  errorMessage = '$page: ${error.toString()}';
                });
                print('$page: ${error.toString()}');
              },
              onViewCreated: (PDFViewController pdfViewController) {
                _controller.complete(pdfViewController);
              },
              onLinkHandler: (String? uri) {
                print('goto uri: $uri');
              },
              onPageChanged: (int? page, int? total) {
                print('page change: $page/$total');
                setState(() {
                  currentPage = page;
                });
              },
            ),
          ),
          errorMessage.isEmpty
              ? !isReady
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : Container()
              : Center(
                  child: Text(errorMessage),
                ),
          ElevatedButton(
            onPressed: () {
              showSignatureDialog(context);
            },
            child: Text('Open Signature Dialog'),
          ),
          for (int i = 0; i < items.length; i++)
            currentPage == items[i]['page']
                ? Positioned(
                    left: (items[i]['x'] * _currentScale) +
                        (_currentOffset.dx / _currentScale),
                    top: (items[i]['y'] * _currentScale) +
                        (_currentOffset.dy / _currentScale),
                    child: TapRegion(
                      onTapInside: (tap) {
                        items[i]['selected'] = true;

                        print('On Tap Inside!!');
                      },
                      onTapOutside: (tap) {
                        setState(() {
                          items[i]['selected'] = false;
                        });
                        print('On Tap Outside!!');
                      },
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            // xPosition += details.delta.dx;
                            // yPosition += details.delta.dy;
                            items[i]['x'] += details.delta.dx / _currentScale;
                            items[i]['y'] += details.delta.dy / _currentScale;
                          });
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: items[i]['width'],
                              height: items[i]['height'],
                              decoration: BoxDecoration(
                                border: items[i]['selected'] == true
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : Border(),
                              ),
                              child: Image.file(
                                items[i]['file']!,
                                width: items[i]['width'],
                                height: items[i]['height'],
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: items[i]['selected'] == true
                                  ? GestureDetector(
                                      onPanUpdate: (details) {
                                        print('aa');
                                        setState(() {
                                          // width += details.delta.dx;
                                          // height += details.delta.dy;

                                          double newHeight = items[i]
                                                  ['height'] +
                                              details.delta.dy / _currentScale;
                                          double newWidth = items[i]['width'] +
                                              details.delta.dx / _currentScale;

                                          items[i]['height'] = newHeight > 0
                                              ? newHeight
                                              : items[i]['height'];
                                          items[i]['width'] = newWidth > 0
                                              ? newWidth
                                              : items[i]['width'];

                                          // items[i]['width'] += details.delta.dx;
                                          // items[i]['height'] += details.delta.dy;
                                        });
                                      },
                                      child: Icon(
                                        Icons.crop_square,
                                        size: 24,
                                        color: Colors.blue,
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child: items[i]['selected'] == true
                                  ? GestureDetector(
                                      onTap: () {
                                        print('waduhd elete');
                                        setState(() {
                                          items.removeAt(i);
                                          // width += details.delta.dx;
                                          // height += details.delta.dy;
                                          // items[i]['width'] += details.delta.dx;
                                          // items[i]['height'] += details.delta.dy;
                                        });
                                      },
                                      child: Icon(
                                        Icons.delete,
                                        size: 24,
                                        color: Colors.red,
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SizedBox.shrink(),
        ],
      ),
      floatingActionButton: FutureBuilder<PDFViewController>(
        future: _controller.future,
        builder: (context, AsyncSnapshot<PDFViewController> snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton.extended(
              label: Text("Go to ${currentPage}"),
              onPressed: () async {
                await snapshot.data!.setPage(pages! ~/ 2);
              },
            );
          }

          return Container();
        },
      ),
    );
  }
}
