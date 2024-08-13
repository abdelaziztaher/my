import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jiffy/jiffy.dart';
import 'package:http/io_client.dart';

class MessageScreen extends StatefulWidget {
  final String userName;
  final String? userImage;
  final String senderId;
  final String receiverId;

  const MessageScreen({
    Key? key,
    required this.userName,
    this.userImage,
    required this.senderId,
    required this.receiverId,
  }) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> messages = []; // Change the type to List<Message>
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  void _fetchMessages() async {
    final ioClient = IOClient(HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true);

    final response = await ioClient.post(
      Uri.parse('http://192.168.8.6:3000/getMessages'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'senderId': widget.senderId,
        'receiverId': widget.receiverId,
      }),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      setState(() {
        messages = [for (var jsonMessage in jsonData) Message.fromJson(jsonMessage)];
      });
      _scrollToBottom();
    } else {
      // handle error
    }
  }

  void sendMessage() async {
    if (_inputController.text.isNotEmpty) {
      final message = Message(
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          message: _inputController.text,
          timestamp: DateTime.now()
      );

      // إرسال الرسالة إلى الخادم
      final response = await http.post(
        Uri.parse('http://192.168.8.6:3000/sendMessage'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'senderId': widget.senderId,
          'receiverId': widget.receiverId,
          'message': message.message, // استخدم الرسالة من الـ object
          'timestamp': message.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          messages.add(message);
          _inputController.clear();
          isTyping = false;
        });

        _scrollToBottom();
      } else {
        // التعامل مع الخطأ في الإرسال
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final isSentByMe = message.senderId == widget.senderId;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                    alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: isSentByMe ? Colors.green[200] : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                          bottomLeft: isSentByMe ? Radius.circular(10) : Radius.circular(0),
                          bottomRight: isSentByMe ? Radius.circular(0) : Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.message,
                            style: TextStyle(
                              color: isSentByMe ? Colors.black : Colors.white,
                            ),
                          ),
                          Text(
                            message.timestamp.toLocal().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onChanged: (text) {
                      setState(() {
                        isTyping = text.isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(isTyping ? Icons.send : Icons.mic),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;

  Message({required this.senderId, required this.receiverId, required this.message, required this.timestamp});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      message: json['message'],
      timestamp: Jiffy.parse(json['timestamp']).dateTime, // parse the string to a DateTime using Jiffy
    );
  }
}
