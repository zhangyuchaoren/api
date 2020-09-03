import 'package:api/decoder/notifications.dart';

import 'decoder/discussions.dart';
import 'decoder/forums.dart';
import 'decoder/tags.dart';
import 'decoder/users.dart';

class InitData {
  ForumInfo forumInfo;
  Tags tags;
  Discussions discussions;
  UserInfo loggedUser;
  NotificationInfoList notificationInfoList;

  InitData(this.forumInfo, this.tags, this.discussions,this.notificationInfoList, this.loggedUser);
}
