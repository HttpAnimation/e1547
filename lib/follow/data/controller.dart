import 'package:e1547/follow/follow.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';

class FollowTimelineController extends PostsController {
  FollowTimelineController({
    required super.client,
    required this.follows,
  }) : super(canSearch: false);

  final FollowsService follows;

  @override
  StreamFuture<List<Post>> stream(int page, bool force) {
    return StreamFuture.resolve(
      () async => client
          .postsByTags(
            await (follows.all(
              types: [FollowType.update, FollowType.notify],
            ).then((e) => e.map((e) => e.tags).toList())),
            page,
            force: force,
            cancelToken: cancelToken,
          )
          .asStream(),
    );
  }
}
