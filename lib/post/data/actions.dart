import 'package:e1547/app/app.dart';
import 'package:e1547/interface/interface.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

extension PostTagging on Post {
  bool hasTag(String tag) {
    if (tag.trim().isEmpty) return false;

    if (tag.contains(':')) {
      String identifier = tag.split(':')[0];
      String value = tag.split(':')[1];
      switch (identifier) {
        case 'id':
          return id == int.tryParse(value);
        case 'rating':
          return rating == Rating.values.asNameMap()[value] ||
              value == rating.title.toLowerCase();
        case 'type':
          return ext.toLowerCase() == value.toLowerCase();
        case 'width':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(width);
        case 'height':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(height);
        case 'filesize':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(size);
        case 'score':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(vote.score);
        case 'favcount':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(favCount);
        case 'fav':
          return isFavorited;
        case 'uploader':
        case 'user':
          // This cannot be implemented, as it requires a user lookup
          return false;
        case 'userid':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(uploaderId);
        case 'username':
          // This cannot be implemented, as it requires a user lookup
          return false;
        case 'pool':
          return pools.contains(int.tryParse(value));
        case 'tagcount':
          NumberRange? range = NumberRange.tryParse(value);
          if (range == null) return false;
          return range.has(tags.values.fold<int>(
            0,
            (previousValue, element) => previousValue + element.length,
          ));
      }
    }

    return tags.values.any((category) => category.contains(tag.toLowerCase()));
  }
}

extension PostDenying on Post {
  bool isDeniedBy(List<String> denylist) => getDeniers(denylist) != null;

  List<String>? getDeniers(List<String> denylist) {
    List<String> deniers = [];

    for (String line in denylist) {
      bool pass = true;
      bool isOptional = false;
      bool hasOptional = false;

      for (String tag in line.split(' ')) {
        if (tagToRaw(tag).isEmpty) continue;

        bool optional = false;
        bool inverted = false;

        if (tag[0] == '~') {
          optional = true;
          tag = tag.substring(1);
        }

        if (tag[0] == '-') {
          inverted = true;
          tag = tag.substring(1);
        }

        bool matches = hasTag(tag);

        if (inverted) {
          matches = !matches;
        }

        if (optional) {
          isOptional = true;
          if (matches) {
            hasOptional = true;
          }
        } else {
          if (!matches) {
            pass = false;
            break;
          }
        }
      }

      if (pass && isOptional) {
        pass = hasOptional;
      }

      if (!pass) continue;

      deniers.add(line);
    }

    return deniers.isEmpty ? null : deniers;
  }
}

enum PostType {
  image,
  video,
  unsupported,
}

extension PostTyping on Post {
  PostType get type {
    switch (ext) {
      case 'mp4':
      case 'webm':
        if (PlatformCapabilities.hasVideos) {
          return PostType.video;
        }
        return PostType.unsupported;
      case 'swf':
        return PostType.unsupported;
      default:
        return PostType.image;
    }
  }
}

extension PostVideoPlaying on Post {
  VideoPlayer? getVideo(BuildContext context, {bool? listen}) {
    if (type == PostType.video && file != null) {
      VideoService service;
      if (listen ?? true) {
        service = context.watch<VideoService>();
      } else {
        service = context.read<VideoService>();
      }
      return service.getVideo(file!);
    }
    return null;
  }
}

extension PostLinking on Post {
  static String getPostLink(int id) => '/posts/$id';

  String get link => getPostLink(id);
}

extension PostUpdating on Post {
  Post withVote({
    required Post post,
    required bool upvote,
    required bool replace,
  }) {
    return post.copyWith(
        vote: post.vote.withVote(
      upvote ? VoteStatus.upvoted : VoteStatus.downvoted,
      replace,
    ));
  }

  Post withFav() {
    if (!isFavorited) {
      return copyWith(
        isFavorited: true,
        favCount: favCount + 1,
      );
    }
    return this;
  }

  Post withUnfav() {
    if (isFavorited) {
      return copyWith(
        isFavorited: false,
        favCount: favCount - 1,
      );
    }
    return this;
  }
}
