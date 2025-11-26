import 'package:flutter/material.dart';
import 'MusicCategoryPresenter.dart';
import 'MusicListPresenter.dart';
import 'MusicSearchPresenter.dart';

class CatSubcatMusicPresenter {
  final MusicCategoryPresenter _category = MusicCategoryPresenter();
  final MusicListPresenter _list = MusicListPresenter();
  final MusicSearchPresenter _search = MusicSearchPresenter();

  CatSubcatMusicPresenter();

  // Category delegates
  Future getCatSubCatMusicList(String token, BuildContext context) =>
      _category.getCatSubCatMusicList(token, context);

  Future getCatSubCatMusicListLegacy(String token) =>
      _category.getCatSubCatMusicListLegacy(token);

  // Music list delegates
  Future getMusicCategory(
    String token,
    String type,
    int pageNumber,
    int numberOfPostsPerRequest,
    BuildContext context,
  ) => _list.getMusic(
    token: token,
    type: type,
    page: pageNumber,
    limit: numberOfPostsPerRequest,
    context: context,
  );

  Future getMusicCategoryLegacy(
    String token,
    String type,
    int pageNumber,
    int numberOfPostsPerRequest,
  ) => _list.getMusicLegacy(
    token: token,
    type: type,
    page: pageNumber,
    limit: numberOfPostsPerRequest,
  );

  // Backwards-compatible method names retained for callers that used the
  // original large presenter. These simply delegate to the new
  // `MusicListPresenter` implementations.
  Future<String> getMusic({
    required String token,
    required String type,
    required int page,
    required int limit,
    required BuildContext context,
    String? search,
  }) => _list.getMusic(
    token: token,
    type: type,
    page: page,
    limit: limit,
    context: context,
    search: search,
  );

  Future<String> getMusicLegacy({
    required String token,
    required String type,
    required int page,
    required int limit,
    String? search,
  }) => _list.getMusicLegacy(
    token: token,
    type: type,
    page: page,
    limit: limit,
    search: search,
  );

  Future getMusicListByCategory(
    String id,
    String type,
    String token, [
    BuildContext? context,
  ]) => _list.getMusicListByCategory(id, type, token, context);

  // Search delegates
  Future getMusicListBySearchNamePage(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
    BuildContext context,
  ) => _search.getMusicListBySearchNamePage(
    search,
    token,
    pageNumber,
    numberOfPostsPerRequest,
    context,
  );

  Future getMusicListBySearchNamePageLegacy(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
  ) => _search.getMusicListBySearchNamePageLegacy(
    search,
    token,
    pageNumber,
    numberOfPostsPerRequest,
  );

  Future getMusicListBySearchName(
    String search,
    String token, [
    BuildContext? context,
  ]) => _search.getMusicListBySearchName(search, token, context);
}
