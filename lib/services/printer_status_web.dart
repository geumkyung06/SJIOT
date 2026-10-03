// [신규] printer_status_service.dart의 웹(Chrome) 빌드용 더미 구현.
//
// 웹 빌드는 실제 행사용 exe가 아니라 화면 확인용이라 Windows 드라이버에
// 접근할 방법이 없습니다. 그래서 항상 "모름"(2)만 돌려줘서, 이 기능이 웹
// 빌드에서는 아무 영향도 주지 않도록(주문을 절대 막지 않도록) 합니다.
int checkPaperStatusCode(String printerName) => 2;