import 'dart:convert';

import 'package:api/decoder/notifications.dart';
import 'package:dio/dio.dart';
import 'decoder/discussions.dart';
import 'decoder/forums.dart';
import 'decoder/loginResult.dart';
import 'decoder/posts.dart';
import 'decoder/tags.dart';
import 'decoder/users.dart';

class Api {
  static Dio _dio;
  static String apiUrl = "";
  static Map<int, TagInfo> _allTags;
  static Tags _tags;
  static String logTag = "api";

  static Future<void> init(String url) async {
    apiUrl = url;
    _dio = Dio()
      ..options.baseUrl = url
      ..options.responseType = ResponseType.plain
      ..options.headers = {"user-agent": "flarum-app/1.0.x"}
      ..options.connectTimeout = 10000
      ..options.sendTimeout = 20000
      ..options.receiveTimeout = 20000;
    Logs.addLog(logTag, "init done");
  }

  static Future<ForumInfo> checkUrl(String url) async {
    if (_isUrl(url)) {
      try {
        var info = ForumInfo.formJson((await Dio().get(url)).data);
        Logs.addLog(logTag, "Mode:checkUrl\nStatus:ok");
        return info;
      } catch (e) {
        Logs.addLog(logTag, "Mode:checkUrl\nError:$e");
        return null;
      }
    } else {
      return null;
    }
  }

  static String getIndexUrl() {
    return apiUrl.replaceAll("/api", "");
  }

  static Tags getTagsWithCache() {
    return _tags;
  }

  static Future<Tags> getTags() async {
    _allTags = {};
    try {
      var t = TagInfo.getListFormJson((await _dio.get("/tags")).data);
      _tags = t;
      t.tags.forEach((_, tag) {
        if (tag.children != null) {
          tag.children.forEach((id, t) {
            _allTags.addAll({t.id: t});
          });
        }
        _allTags.addAll({tag.id: tag});
      });
      t.miniTags.forEach((id, tag) {
        _allTags.addAll({tag.id: tag});
      });
      Logs.addLog(logTag, "Mode:getTags\nStatus:ok");
      return t;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getTags\nError:$e");
      return null;
    }
  }

  static TagInfo getTagById(int id) {
    return _allTags[id];
  }

  static TagInfo getTagBySlug(String slug) {
    for (var t in _allTags.values.toList()) {
      if (t.slug == slug) {
        return t;
      }
    }
    return null;
  }

  static Future<DiscussionInfo> getDiscussionById(String id) async {
    return getDiscussionByUrl("/discussions/$id");
  }

  static Future<DiscussionInfo> getDiscussionByUrl(String url) async {
    try {
      var d = DiscussionInfo.formJson((await _dio.get(url)).data);
      Logs.addLog(logTag, "Mode:getDiscussionById\nStatus:ok");
      return d;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getDiscussionById\nError:$e");
      return null;
    }
  }

  static Future<DiscussionInfo> getDiscussionWithNearNumber(
      String id, int number) {
    String url = "/discussions/$id?page[near]=$number";
    return getDiscussionByUrl(url);
  }

  static Future<Discussions> getDiscussionList(String sortKey,
      {String tagSlug}) async {
    String url;
    if (tagSlug == null) {
      url = "/discussions?include=user,tags"
          "&sort=$sortKey&";
    } else {
      url = "/discussions?include=user,tags"
          "&sort=$sortKey&filter[q]=tag:${Uri.encodeComponent(tagSlug)}&";
    }
    return getDiscussionListByUrl(url);
  }

  static Future<Discussions> searchDiscuss(String key, String tagSlug) async {
    String url =
        "/discussions?include=user,lastPostedUser,mostRelevantPost,mostRelevantPost.user,firstPost,tags&filter[q]=$key tag:$tagSlug&";
    return getDiscussionListByUrl(url);
  }

  static Future<Discussions> getDiscussionListByUrl(String url) async {
    try {
      var data = Discussions.formJson((await _dio.get(url)).data);
      Logs.addLog(logTag, "Mode:getDiscussionListByUrl\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getDiscussionListByUrl\nError:$e");
      return null;
    }
  }

  static Future<DiscussionInfo> createDiscussion(
      List<TagInfo> tags, String title, String post) async {
    List<Map<String, String>> ts = [];
    tags.forEach((TagInfo t) {
      ts.add({"type": "tags", "id": t.id.toString()});
    });

    var m = {
      "data": {
        "type": "discussions",
        "attributes": {"title": title, "content": post},
        "relationships": {
          "tags": {"data": ts}
        }
      }
    };

    try {
      var r = await _dio.post("/discussions", data: m);
      if (r.statusCode == 201) {
        Logs.addLog(logTag, "Mode:createDiscussion\nStatus:ok");
        return DiscussionInfo.formJson(r.data);
      } else {
        Logs.addLog(logTag, "Mode:createDiscussion\nStatus:${r.statusCode}");
        return null;
      }
    } catch (e) {
      Logs.addLog(logTag, "Mode:createDiscussion\nError:$e");
      return null;
    }
  }

  static Future<Posts> getPostsById(List<int> l) async {
    var url = "/posts?filter[id]=";
    l.forEach((id) {
      url += "$id,";
    });
    try {
      var data = Posts.formJson((await _dio.get(url)).data);
      Logs.addLog(logTag, "Mode:getPostsById\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getPostsById\nError:$e");
      return null;
    }
  }

  static Future<PostInfo> createPost(String discussionId, String post) async {
    var m = {
      "data": {
        "type": "posts",
        "attributes": {"content": post},
        "relationships": {
          "discussion": {
            "data": {"type": "discussions", "id": discussionId}
          }
        }
      }
    };
    try {
      var data = PostInfo.formJson((await _dio.post("/posts", data: m)).data);
      Logs.addLog(logTag, "Mode:createPost\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:createPost\nError:$e");
      return null;
    }
  }

  static Future<PostInfo> likePost(String id, bool isLiked) async {
    var m = {
      "data": {
        "type": "posts",
        "id": "$id",
        "attributes": {"isLiked": isLiked}
      }
    };
    try {
      var data = PostInfo.formJson((await _dio
              .patch("https://discuss.flarum.org/api/posts/$id", data: m))
          .data);
      Logs.addLog(logTag, "Mode:likePost\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:likePost\nError:$e");
      return null;
    }
  }

  static Future<bool> setLastReadPostNumber(String postId, int number) async {
    try {
      var r = await _dio.patch("/discussions/$postId", data: {
        "data": {
          "type": "discussions",
          "id": postId,
          "attributes": {"lastReadPostNumber": number}
        }
      });
      if (r.statusCode == 200) {
        Logs.addLog(logTag, "Mode:setLastReadPostNumber\nStatus:ok");
        return true;
      }
      Logs.addLog(logTag, "Mode:setLastReadPostNumber\nStatus:${r.statusCode}");
      return false;
    } catch (e) {
      Logs.addLog(logTag, "Mode:setLastReadPostNumber\nError:$e");
      return false;
    }
  }

  static Future<UserInfo> getLoggedInUserInfo(LoginResult data) async {
    if (data.userId == -1) {
      return null;
    }
    _dio
      ..options.headers.addAll(
          {"Authorization": "Token ${data.token};userId=${data.userId}"});
    var u = await getUserInfoByNameOrId(data.userId.toString());
    return u;
  }

  static Future<UserInfo> getUserInfoByNameOrId(String nameOrId) async {
    return getUserByUrl("users/$nameOrId");
  }

  static Future<NotificationInfoList> getNotification() async {
    return getNotificationByUrl("/notifications");
  }

  static Future<NotificationInfoList> getNotificationByUrl(String url) async {
    try {
      var data = NotificationInfoList.formJson((await _dio.get(url)).data);
      Logs.addLog(logTag, "Mode:getNotificationByUrl\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getNotificationByUrl\nError:$e");
      return null;
    }
  }

  static Future<NotificationsInfo> setNotificationIsRead(String id) async {
    var m = {
      "data": {
        "type": "notifications",
        "id": id,
        "attributes": {"isRead": true}
      }
    };
    try {
      var data = NotificationsInfo.formJson(
          (await _dio.patch("/notifications/$id", data: m)).data);
      Logs.addLog(logTag, "Mode:setNotificationIsRead\nError:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:setNotificationIsRead\nError:$e");
      return null;
    }
  }

  static Future<bool> readAllNotification() async {
    try {
      var r = await _dio.post("/notifications/read");
      if (r.statusCode == 204) {
        Logs.addLog(logTag, "Mode:readAllNotification\nStatus:ok");
        return true;
      }
      Logs.addLog(logTag, "Mode:readAllNotification\nStatus:${r.statusCode}");
      return false;
    } catch (e) {
      Logs.addLog(logTag, "Mode:readAllNotification\nError:$e");
      return false;
    }
  }

  static Future<UserInfo> getUserByUrl(String url) async {
    try {
      var data = UserInfo.formJson((await _dio.get(url)).data);
      Logs.addLog(logTag, "Mode:getUserByUrl\nStatus:ok");
      return data;
    } catch (e) {
      Logs.addLog(logTag, "Mode:getUserByUrl\nError:$e");
      return null;
    }
  }

  static Future<LoginResult> login(String username, String password) async {
    var result;
    try {
      result = (await _dio.post("/token", data: {
        "identification": username,
        "password": password,
      }));
      var d = result.data;
      var data;
      if (d is Map) {
        data = LoginResult.formMap(d);
      } else {
        data = LoginResult.formMap(json.decode(d));
      }

      if (data != null) {
        Logs.addLog(logTag, "Mode:login\nStatus:ok");
        return data;
      } else {
        Logs.addLog(logTag, "Mode:login\nError:???");
        return null;
      }
    } catch (e) {
      Logs.addLog(logTag, "Mode:login\nError:$e");
      return null;
    }
  }

  static bool _isUrl(String text) {
    return RegExp("https://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]")
        .hasMatch(text);
  }
}

class Logs {
  static List<String> _logs = [];
  static void addLog(String logTag, String log) {
    log = "[$logTag]-[${DateTime.now().toString()}] : $log";
    _logs.add(log);
    print(log);
  }

  static String getLog(int index) {
    return _logs[index];
  }

  static List<String> getAllLog() {
    return _logs;
  }

  static List<String> getLastLogs(int count) {
    if (count >= _logs.length){
      count = 0;
    }
    int len = _logs.length;
    return _logs.sublist(len - count);
  }
}
