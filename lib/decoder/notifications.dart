import 'package:api/decoder/posts.dart';
import 'package:api/decoder/users.dart';

import 'base.dart';

class NotificationsInfo {
  int id;
  String contentType;

  /// Map or String
  dynamic content;
  String createdAt;
  bool isRead;
  UserInfo fromUser;
  PostInfo post;
  Map source;

  NotificationsInfo(this.id, this.contentType, this.content, this.createdAt,
      this.isRead, this.fromUser, this.post, this.source);

  factory NotificationsInfo.formMapAndId(Map map, int id) {
    return NotificationsInfo(id, map["contentType"], map["content"],
        map["createdAt"], map["isRead"], null, null, map);
  }
}

class NotificationInfoList {
  Links links;
  List<NotificationsInfo> list;

  factory NotificationInfoList.formJson(String data) {
    return NotificationInfoList.formBase(BaseListBean.formJson(data));
  }

  factory NotificationInfoList.formBase(BaseListBean base) {
    List<NotificationsInfo> list = [];
    Map<int, UserInfo> allUsers = {};
    Map<int, PostInfo> allPosts = {};
    base.included.data.forEach((d) {
      switch (d.type) {
        case "users":
          UserInfo u = UserInfo.formBaseData(d);
          allUsers.addAll({u.id: u});
          break;
        case "posts":
          PostInfo p = PostInfo.formBaseData(d);
          allPosts.addAll({p.id: p});
          break;
      }
    });

    base.data.list.forEach((d) {
      NotificationsInfo n = NotificationsInfo.formMapAndId(d.attributes, d.id);
      var u = allUsers[int.parse(d.relationships["fromUser"]["data"]["id"])];
      var p = allPosts[int.parse(d.relationships["subject"]["data"]["id"])];
      n.fromUser = u;
      n.post = p;
      list.add(n);
    });
    return NotificationInfoList(list, base.links);
  }

  NotificationInfoList(this.list, this.links);
}
