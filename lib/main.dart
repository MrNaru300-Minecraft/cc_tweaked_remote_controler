import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = 'WebSocket Demo';
    return MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController _controller = TextEditingController();
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:3000'),
  );

  var _selectedComputer = "";
  var _computers = <String>[];
  final _logs = <Log>[];
  var _complete = <String>[];

  _MyHomePageState() {
    _send('list');

    _channel.stream.listen((event) {
      var msg = json.decode(event.toString());
      switch (msg["event"]) {
        case "list":
          setState(() {
            _computers = (msg["data"] as List<dynamic>)
                .map((e) => e.toString())
                .toList();
          });
          print("Computers list updated: $_computers");
          break;
        default:
          try {
            var computer = json.decode(msg['data']);
            switch (computer['type']) {
              case 'complete':
                setState(() {
                  if (computer['data'] is List<dynamic>)
                    _complete = computer['data']
                        .map<String>((e) => _controller.text + e.toString())
                        .toList();
                  else
                    _complete = <String>[];
                  _controller.notifyListeners();
                });
                break;
              case "message":
                setState(() {
                  _logs.insert(
                      0,
                      Log(
                        dateTime: DateTime.now(),
                        text: computer['data'].toString(),
                      ));
                });
                break;
              default:
                setState(() {
                  _logs.insert(
                      0,
                      Log(
                        dateTime: DateTime.now(),
                        text: event.toString(),
                      ));
                });
            }
            ;
          } catch (e) {
            setState(() {
              _logs.insert(
                  0,
                  Log(
                    dateTime: DateTime.now(),
                    text: event.toString(),
                  ));
            });
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Prompt(
              onSelectionChanged: (value) => _selectedComputer = value ?? "",
              complete: _complete,
              computers: _computers,
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                _controller = textEditingController;
                return TextFormField(
                  focusNode: focusNode,
                  controller: textEditingController,
                  onChanged: (value) => _onTextFieldChanged(value),
                  onFieldSubmitted: (value) => _sendCommand(),
                  decoration:
                      const InputDecoration(labelText: 'Send a message'),
                  autofocus: true,
                );
              },
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                  itemCount: _logs.length,
                  cacheExtent: 100,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) => _logs[index]),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendCommand,
        tooltip: 'Send message',
        child: Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _send(String type,
      {String? computer_id, dynamic data, Map<String, dynamic>? metadata}) {
    _channel.sink.add(jsonEncode(<String, dynamic>{
      'type': type,
      'data': data,
      'computer_id': computer_id
    }..addAll(metadata ?? {})));
  }

  void _onTextFieldChanged(String value) {
    _complete = [];

    if (_controller.text.isNotEmpty && _selectedComputer != "") {
      _send('complete', computer_id: _selectedComputer, data: _controller.text);
    }
  }

  void _sendCommand() {
    if (_controller.text.isNotEmpty && _selectedComputer != "") {
      _send("message", computer_id: _selectedComputer, data: _controller.text);
      _controller.text = '';
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}

class Prompt extends StatelessWidget {
  const Prompt(
      {Key? key,
      required this.complete,
      required this.computers,
      required this.fieldViewBuilder,
      this.onSubmitted,
      this.onTextChanged,
      this.onSelectionChanged})
      : super(key: key);

  final List<String> complete;
  final List<String> computers;
  final void Function(String)? onSubmitted;
  final void Function(String)? onTextChanged;
  final void Function(String?)? onSelectionChanged;
  final Widget Function(
          BuildContext, TextEditingController, FocusNode, void Function())
      fieldViewBuilder;

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Row(
        children: [
          Expanded(
            child: Autocomplete(
                fieldViewBuilder: fieldViewBuilder,
                optionsBuilder: (value) => complete),
          ),
          SizedBox(
            width: 20,
          ),
          SizedBox(
              width: 100,
              child: DropdownButtonFormField<String>(
                  onChanged: onSelectionChanged,
                  items: computers
                      .map((e) =>
                          DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList())),
        ],
      ),
    );
  }
}

class Log extends StatelessWidget {
  final DateTime dateTime;

  final String? text;

  const Log({Key? key, required this.dateTime, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: RichText(
          text: TextSpan(children: [
        TextSpan(
            text: '[${dateTime.hour}:${dateTime.minute}:${dateTime.second}] ',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
        TextSpan(text: text)
      ])),
    );
  }
}
