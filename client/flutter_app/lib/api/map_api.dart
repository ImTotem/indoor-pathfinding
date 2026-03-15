import '../models/map_model.dart';
import 'api_client.dart';

class MapApi {
  final _dio = ApiClient().dio;

  Future<List<MapModel>> getAll() async {
    final response = await _dio.get('/api/maps/');
    return (response.data as List)
        .map((json) => MapModel.fromJson(json))
        .toList();
  }

  Future<MapModel> getById(String id) async {
    final response = await _dio.get('/api/maps/$id');
    return MapModel.fromJson(response.data);
  }

  Future<MapModel> create({
    required String name,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.post('/api/maps/', data: {
      'name': name,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return MapModel.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/api/maps/$id');
  }
}
