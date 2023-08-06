import 'package:e1547/client/client.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';

class LikeDisplay extends StatelessWidget {
  const LikeDisplay({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            VoteDisplay(
              status: post.vote.status,
              score: post.vote.score,
              onUpvote: (isLiked) async {
                Client client = context.read<Client>();
                ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                if (client.hasLogin) {
                  Future(() async {
                    try {
                      await client.votePost(post.id, true, !isLiked);
                    } on ClientException {
                      messenger.showSnackBar(SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text('Failed to upvote Post #${post.id}'),
                      ));
                    }
                  });
                  return !isLiked;
                } else {
                  return false;
                }
              },
              onDownvote: (isLiked) async {
                Client client = context.read<Client>();
                ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                if (client.hasLogin) {
                  Future(() async {
                    try {
                      await client.votePost(post.id, false, !isLiked);
                    } on ClientException {
                      messenger.showSnackBar(SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text('Failed to downvote Post #${post.id}'),
                      ));
                    }
                  });
                  return !isLiked;
                } else {
                  return false;
                }
              },
            ),
            Row(
              children: [
                Text(post.favCount.toString()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.favorite,
                    color: post.isFavorited ? Colors.pinkAccent : IconTheme.of(context).color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {},
      child: LikeButton(
        isLiked: post.isFavorited,
        circleColor: const CircleColor(start: Colors.pink, end: Colors.red),
        bubblesColor: const BubblesColor(
            dotPrimaryColor: Colors.pink, dotSecondaryColor: Colors.red),
        likeBuilder: (isLiked) => Icon(
          Icons.favorite,
          color: isLiked ? Colors.pinkAccent : IconTheme.of(context).color,
        ),
        onTap: (isLiked) async {
          Client client = context.read<Client>();
          ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
          if (isLiked) {
            Future(() async {
              try {
                await client.removeFavorite(post.id);
              } on ClientException {
                messenger.showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content: Text(
                        'Failed to remove Post #${post.id} from favorites'),
                  ),
                );
              }
            });
            return false;
          } else {
            bool upvote = context.read<Settings>().upvoteFavs.value;
            Future(() async {
              try {
                await client.addFavorite(post.id);
                if (upvote) {
                  await client.votePost(post.id, true, true);
                }
              } on ClientException {
                messenger.showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    content:
                        Text('Failed to add Post #${post.id} to favorites'),
                  ),
                );
              }
            });
            return true;
          }
        },
      ),
    );
  }
}
