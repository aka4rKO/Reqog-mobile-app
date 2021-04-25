import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;

  const DisplayPictureScreen({Key key, this.imagePath}) : super(key: key);

  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
}

enum TtsState { playing, stopped, paused, continued }

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  final Dio dio = Dio();
  FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;
  stt.SpeechToText _speech;
  bool _isListening = false;
  String _question = "";
  String _answer = "";
  bool _available = false;
  String url = "http://871d566c5610.ngrok.io/get-prediction";

  get isPlaying => ttsState == TtsState.playing;
  get isStopped => ttsState == TtsState.stopped;
  get isPaused => ttsState == TtsState.paused;
  get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    initSpeechState();
    initTts();
  }

  initTts() {
    flutterTts = FlutterTts();

    if (isAndroid) {
      _getEngines();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    if (isWeb || isIOS) {
      flutterTts.setPauseHandler(() {
        setState(() {
          print("Paused");
          ttsState = TtsState.paused;
        });
      });

      flutterTts.setContinueHandler(() {
        setState(() {
          print("Continued");
          ttsState = TtsState.continued;
        });
      });
    }

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future _getEngines() async {
    var engines = await flutterTts.getEngines;
    if (engines != null) {
      for (dynamic engine in engines) {
        print(engine);
      }
    }
  }

  Future _speak(String message) async {
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(message);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<String> uploadData() async {
    String fileName = widget.imagePath.split('/').last;
    print("File name: " + fileName);
    FormData formData = new FormData.fromMap({
      "image":
          await MultipartFile.fromFile(widget.imagePath, filename: fileName),
      "question": _question,
    });
    Response response = await dio.post(url, data: formData);
    return response.toString();
  }

  Future<void> initSpeechState() async {
    var available = await _speech.initialize(
      onStatus: (val) async {
        print('onStatus: $val');
        if (val == 'notListening') {
          _speech.stop();
        }
      },
      onError: (val) {
        print('onError: $val');
        setState(() => _isListening = false);
        _speech.stop();
      },
    );

    setState(() {
      _available = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: _isListening,
        glowColor: Theme.of(context).primaryColor,
        endRadius: 50.0,
        duration: const Duration(milliseconds: 2000),
        repeatPauseDuration: const Duration(milliseconds: 100),
        repeat: true,
        child: Semantics(
          label: "Double tap to ask question",
          hint: "Start asking your question immediately after double tapping",
          child: ExcludeSemantics(
            excluding: true,
            child: FloatingActionButton(
                onPressed: () {
                  _question = "";
                  _answer = "";
                  _listen();
                },
                child: Icon(_isListening ? Icons.mic : Icons.mic_none)),
          ),
        ),
      ),
      appBar: AppBar(
          leading: Semantics(
        label: "Go back to capture another image",
        hint: "Double tap to go back",
        child: ExcludeSemantics(
          excluding: true,
          child: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      )),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Container(
                  height: MediaQuery.of(context).size.width,
                  child: Center(
                      child: Image.file(File(widget.imagePath),
                          semanticLabel: "Captured"))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                    child: Column(
                  children: [
                    Semantics(
                      label: _question == ""
                          ? "You have not yet asked a question"
                          : "Your question is " + _question,
                      child: ExcludeSemantics(
                        excluding: true,
                        child: MergeSemantics(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("QUESTION: ",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Flexible(
                                child: Text(
                                  _question,
                                  style: TextStyle(fontSize: 20),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Semantics(
                      label: _answer == ""
                          ? "Ask a question to get answer"
                          : "The answer is " + _answer,
                      child: ExcludeSemantics(
                        excluding: true,
                        child: MergeSemantics(
                          child: Row(
                            children: [
                              Text("ANSWER: ",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(_answer, style: TextStyle(fontSize: 20))
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
              )
            ],
          ),
        ],
      ),
    );
  }

  void _listen() {
    if (!_isListening) {
      if (_available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() async {
            _question = val.recognizedWords;
            _isListening = false;
            if (_question != "" && _speech.isNotListening) {
              await _speak("Please wait");
              _answer = await uploadData();
              print("Predicted answer: " + _answer);
              await _speak("The answer is " + _answer);
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }
}
