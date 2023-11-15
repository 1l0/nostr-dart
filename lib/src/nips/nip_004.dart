import 'dart:math';

import 'package:nostr_core_dart/nostr.dart';

/// Encrypted Direct Message
class Nip4 {
  /// Returns the EDMessage Encrypted Direct Message event (kind=4)
  ///
  /// ```dart
  ///  var event = Event.from(
  ///    pubkey: senderPubKey,
  ///    created_at: 12121211,
  ///    kind: 4,
  ///    tags: [
  ///      ["p", receiverPubKey],
  ///      ["e", <event-id>, <relay-url>, <marker>],
  ///    ],
  ///    content: "wLzN+Wt2vKhOiO8v+FkSzA==?iv=X0Ura57af2V5SuP80O6KkA==",
  ///  );
  ///
  ///  EDMessage eDMessage = Nip4.decode(event);
  ///```
  static EDMessage? decode(Event event, String pubkey, String privkey) {
    if (event.kind == 4) {
      return _toEDMessage(event, pubkey, privkey);
    }
    return null;
  }

  /// Returns EDMessage from event
  static EDMessage _toEDMessage(Event event, String pubkey, String privkey) {
    String sender = event.pubkey;
    int createdAt = event.createdAt;
    String receiver = "";
    String replyId = "";
    String content = "";
    String subContent = event.content;
    String? expiration;
    for (var tag in event.tags) {
      if (tag[0] == "p") receiver = tag[1];
      if (tag[0] == "e") replyId = tag[1];
      if (tag[0] == "subContent") subContent = tag[1];
      if (tag[0] == "expiration") expiration = tag[1];
    }

    if (receiver.isNotEmpty && receiver.compareTo(pubkey) == 0) {
      content = decryptContent(subContent, privkey, sender);
    } else if (receiver.isNotEmpty && sender.compareTo(pubkey) == 0) {
      content = decryptContent(subContent, privkey, receiver);
    } else {
      throw Exception("not correct receiver, is not nip4 compatible");
    }

    return EDMessage(sender, receiver, createdAt, content, replyId, expiration);
  }

  static String decryptContent(String content, String privkey, String pubkey) {
    int ivIndex = content.indexOf("?iv=");
    if (ivIndex <= 0) {
      print("Invalid content for dm, could not get ivIndex: $content");
      return "";
    }
    String iv = content.substring(ivIndex + "?iv=".length, content.length);
    String encString = content.substring(0, ivIndex);
    try {
      return decrypt(privkey, '02$pubkey', encString, iv);
    } catch (e) {
      return "";
    }
  }

  static Event encode(
      String receiver, String content, String replyId, String privkey, {String? subContent, int? expiration}) {
    String enContent = encryptContent(content, privkey, receiver);
    List<List<String>> tags = toTags(receiver, replyId, expiration);
    if(subContent != null && subContent.isNotEmpty){
      String enSubContent = encryptContent(subContent, privkey, receiver);
      tags.add(['subContent', enSubContent]);
    }
    Event event =
        Event.from(kind: 4, tags: tags, content: enContent, privkey: privkey);
    return event;
  }

  static String encryptContent(String content, String privkey, String pubkey) {
    return encrypt(privkey, '02$pubkey', content);
  }

  static List<List<String>> toTags(String p, String e, int? expiration) {
    List<List<String>> result = [];
    result.add(["p", p]);
    if (e.isNotEmpty) result.add(["e", e, '', 'reply']);
    if (expiration != null) result.add(['expiration', expiration.toString()]);
    return result;
  }
}

/// ```
class EDMessage {
  String sender;

  String receiver;

  int createdAt;

  String content;

  String replyId;

  String? expiration;

  /// Default constructor
  EDMessage(
      this.sender, this.receiver, this.createdAt, this.content, this.replyId, this.expiration);
}
