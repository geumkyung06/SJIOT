/// QR 인증(start 200) 응답으로 받은 주문 정보.
class OrderInfo {
  final String orderId;

  /// start 응답의 `keycap` (MBTI 4글자)
  final String mbti;

  /// 서버 색상 코드 r · y · b · g
  final List<String> colors;

  /// 이 단말의 조립대 번호 (서버 ③번 검사로 배정 조립대와 같음이 보장됨)
  final int assignedWorkstation;

  const OrderInfo({
    required this.orderId,
    required this.mbti,
    required this.colors,
    required this.assignedWorkstation,
  });
}
