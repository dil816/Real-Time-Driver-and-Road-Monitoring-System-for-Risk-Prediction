class RoadSignModel {
  List<String>? lables = [];

  RoadSignModel({required this.lables});

  RoadSignModel.fromJson(Map<String, dynamic> json) {
    json['labels'] != null
        ? lables = List<String>.from(json['labels'])
        : lables = [];
  }
}
