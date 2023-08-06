import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';

class UserFavoritesController extends PostsController {
  UserFavoritesController({
    required this.user,
    required super.client,
  });

  final String user;

  @override
  StreamFuture<List<Post>> stream(int page, bool force) {
    return client.postsByFavoriter(
      username: user,
      page: page,
      force: force,
      cancelToken: cancelToken,
    );
  }
}

class UserUploadsController extends PostsController {
  UserUploadsController({
    required this.user,
    required super.client,
  });

  final String user;

  @override
  StreamFuture<List<Post>> stream(int page, bool force) {
    return client.postsByUploader(
      username: user,
      page: page,
      force: force,
      cancelToken: cancelToken,
    );
  }
}
