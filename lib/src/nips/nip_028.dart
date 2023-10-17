import 'dart:convert';
import 'package:nostr_core_dart/nostr.dart';

/// Public Chat & Channel
class Nip28 {
  static Channel getChannelCreation(Event event) {
    try {
      if (event.kind == 40) {
        // create channel
        Map content = jsonDecode(event.content);
        Map<String, String> additional = Map.from(content)
            .map((key, value) => MapEntry(key, value.toString()));
        String? name = additional.remove("name");
        String? about = additional.remove("about");
        String? picture = additional.remove("picture");
        String? pinned = additional.remove("pinned");
        return Channel(event.id, name ?? '', about ?? '', picture ?? '', pinned,
            event.pubkey, null, null, additional);
      } else {
        throw Exception("${event.kind} is not nip28 compatible");
      }
    } catch (e, s) {
      throw Exception(s);
    }
  }

  static Channel getChannelMetadata(Event event) {
    try {
      Map content = jsonDecode(event.content);
      if (event.kind == 41) {
        // create channel
        Map<String, String> additional = Map.from(content);
        String? name = additional.remove("name");
        String? about = additional.remove("about");
        String? picture = additional.remove("picture");
        String? pinned = additional.remove("pinned");
        String? channelId;
        String? relay;
        String owner = event.pubkey;
        List<String> members = [];
        for (var tag in event.tags) {
          if (tag[0] == "e") {
            channelId = tag[1];
            relay = tag[2];
          }
          if (tag[0] == "p") {
            members.add(tag[1]);
          }
        }
        Channel result = Channel(channelId!, name!, about!, picture!, pinned,
            owner, relay, members, additional);
        return result;
      } else {
        throw Exception("${event.kind} is not nip28 compatible");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static ChannelMessage getChannelMessage(Event event) {
    try {
      if (event.kind == 42) {
        var content = event.content;
        GroupActionsType actionsType = GroupActionsType.message;
        for (var tag in event.tags) {
          if (tag[0] == "subContent") content = tag[1];
          if (tag[0] == "type") actionsType = _typeToActions(tag[1]);
        }
        Thread thread = Nip10.fromTags(event.tags);
        String channelId = thread.root.eventId;
        return ChannelMessage(channelId, event.pubkey, content, thread,
            event.createdAt, actionsType);
      }
      throw Exception("${event.kind} is not nip28 compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static String? tagsToMessageId(List<List<String>> tags) {
    String? messageId;
    for (var tag in tags) {
      if (tag[0] == "e") {
        messageId = tag[1];
        break;
      }
    }
    return messageId;
  }

  static ChannelMessageHidden getMessageHidden(Event event) {
    try {
      if (event.kind == 43) {
        Map content = jsonDecode(event.content);
        String reason = content['reason'];
        return ChannelMessageHidden(event.pubkey, tagsToMessageId(event.tags)!,
            reason, event.createdAt);
      }
      throw Exception("${event.kind} is not nip28(hide message) compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static ChannelUserMuted getUserMuted(Event event) {
    try {
      if (event.kind == 44) {
        String? userPubkey;
        for (var tag in event.tags) {
          if (tag[0] == "p") {
            userPubkey = tag[1];
            break;
          }
        }
        String reason = '';
        if (event.content.isNotEmpty) {
          Map content = jsonDecode(event.content);
          reason = content.containsKey('reason') ? content['reason'] : '';
        }
        return ChannelUserMuted(
            event.pubkey, userPubkey!, reason, event.createdAt);
      }
      throw Exception("${event.kind} is not nip28(mute user) compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Event createChannel(String name, String about, String picture,
      Map<String, String> additional, String privkey) {
    Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
    };
    map.addAll(additional);
    String content = jsonEncode(map);
    Event event =
        Event.from(kind: 40, tags: [], content: content, privkey: privkey);
    return event;
  }

  static Event setChannelMetaData(
      String name,
      String about,
      String picture,
      List<String>? pinned,
      List<String>? members,
      Map<String, String>? additional,
      String channelId,
      String relayURL,
      String privkey) {
    Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
    };
    if (pinned != null) map['pinned'] = pinned;
    if (additional != null) map.addAll(additional);
    String content = jsonEncode(map);
    List<List<String>> tags = [];
    tags.add(["e", channelId, relayURL]);
    if (members != null) {
      for (var p in members) {
        tags.add(['p', p]);
      }
    }
    Event event =
        Event.from(kind: 41, tags: tags, content: content, privkey: privkey);
    return event;
  }

  static Event sendChannelMessage(
      String channelId, String content, String privkey,
      {String? channelRelay,
      String? replyMessage,
      String? replyMessageRelay,
      String? replyUser,
      String? replyUserRelay,
      String? subContent,
      String? actionsType}) {
    List<List<String>> tags = [];
    ETag root = Nip10.rootTag(channelId, channelRelay ?? '');

    Thread thread = Thread(
        root,
        replyMessage == null
            ? null
            : ETag(replyMessage, replyMessageRelay ?? '', 'reply'),
        null,
        replyUser == null ? null : [PTag(replyUser, replyUserRelay ?? '')]);
    tags = Nip10.toTags(thread);
    if (subContent != null && subContent.isNotEmpty) {
      tags.add(['subContent', subContent]);
    }
    if (actionsType != null && actionsType != 'message') {
      tags.add(['type', actionsType]);
    }
    Event event =
        Event.from(kind: 42, tags: tags, content: content, privkey: privkey);
    return event;
  }

  static Event hideChannelMessage(
      String messageId, String reason, String privkey) {
    Map<String, dynamic> map = {
      'reason': reason,
    };
    String content = jsonEncode(map);
    List<List<String>> tags = [];
    tags.add(["e", messageId]);
    Event event =
        Event.from(kind: 43, tags: tags, content: content, privkey: privkey);
    return event;
  }

  static Event muteUser(String pubkey, String reason, String privkey) {
    Map<String, dynamic> map = {
      'reason': reason,
    };
    String content = jsonEncode(map);
    List<List<String>> tags = [];
    tags.add(["p", pubkey]);
    Event event =
        Event.from(kind: 44, tags: tags, content: content, privkey: privkey);
    return event;
  }

  static GroupActionsType _typeToActions(String type) {
    switch (type) {
      case 'invite':
        return GroupActionsType.invite;
      case 'request':
        return GroupActionsType.request;
      case 'join':
        return GroupActionsType.join;
      case 'add':
        return GroupActionsType.add;
      case 'leave':
        return GroupActionsType.leave;
      case 'remove':
        return GroupActionsType.remove;
      case 'updateName':
        return GroupActionsType.updateName;
      case 'updatePinned':
        return GroupActionsType.updatePinned;
      default:
        return GroupActionsType.request;
    }
  }
}

/// channel info
class Channel {
  /// channel create event id
  String channelId;

  String name;

  String about;

  String picture;

  String? pinned;

  String owner;

  String? relay;

  List<String>? members;

  /// Clients MAY add additional metadata fields.
  Map<String, String> additional;

  /// Default constructor
  Channel(this.channelId, this.name, this.about, this.picture, this.pinned,
      this.owner, this.relay, this.members, this.additional);
}

/// messages in channel
class ChannelMessage {
  String channelId;
  String sender;
  String content;
  Thread thread;
  int createTime;
  GroupActionsType? actionsType;

  ChannelMessage(this.channelId, this.sender, this.content, this.thread,
      this.createTime, this.actionsType);
}

class ChannelMessageHidden {
  String operator;
  String messageId;
  String reason;
  int createTime;

  ChannelMessageHidden(
      this.operator, this.messageId, this.reason, this.createTime);
}

class ChannelUserMuted {
  String operator;
  String userPubkey;
  String reason;
  int createTime;

  ChannelUserMuted(
      this.operator, this.userPubkey, this.reason, this.createTime);
}

/// group actions
enum GroupActionsType {
  message,
  invite,
  request,
  join,
  add,
  leave,
  remove,
  updateName,
  updatePinned
}
