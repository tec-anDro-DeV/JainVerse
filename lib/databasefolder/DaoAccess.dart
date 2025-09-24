import 'package:floor/floor.dart';

import 'ListEntity.dart';

@dao
abstract class DaoAccess {
  @Query('SELECT * FROM ListEntity WHERE userId = :userId')
  Future<List<ListEntity>> findAllList(String userId);

  @Query(
      'SELECT * FROM ListEntity WHERE userId = :userId and name LIKE %search%')
  Future<List<ListEntity>> searchAllList(String userId, String search);

  @Query(
      'SELECT * FROM ListEntity WHERE AudioId = :AudioId and userId = :userId')
  Stream<ListEntity?> findById(String AudioId, String userId);

  @insert
  Future<void> insertInList(ListEntity list);

  @Query('DELETE FROM ListEntity WHERE id = :id')
  Future<void> delete(ListEntity list);
}
