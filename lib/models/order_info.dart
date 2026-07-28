class OrderInfo {
  final String orderId;
  final String mbti;
  final List<String> colors;
  final int assignedWorkstation;

  const OrderInfo({
    required this.orderId,
    required this.mbti,
    required this.colors,
    required this.assignedWorkstation,
  });

  /// QR 코드의 JSON 데이터를 OrderInfo 객체로 변환
  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      orderId: json['order_id'] as String,
      mbti: json['mbti'] as String,
      colors: List<String>.from(json['colors'] as List),
      assignedWorkstation: json['assembly_station'] as int,
    );
  }

  /// 조립대 번호를 화면에 01, 02, 03 형식으로 표시
  String get workstationLabel => assignedWorkstation.toString().padLeft(2, '0');
}
