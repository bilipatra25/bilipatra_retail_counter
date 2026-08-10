// final String googleApiKey = "AIzaSyBFBgppTOfyBMC1Z1CQBfIjZD-O26dzYRk";
final String googleApiKey = "AIzaSyC7F4lVQwwZ8hxTexJuqW7r6doPBLwf0CE";
final String CONFIG = "CONFIG";
int MIN_FREE_AMOUNT = 300;
int DELIVERY_CHARGE = 30;
final String USER_DATA = "userResponse";
final String EMPLOYEE_DATA = "EMPLOYEE_DATA";

enum OrderType { cash, online }

extension OrderTypeExtension on OrderType {
  String get label {
    switch (this) {
      case OrderType.cash:
        return 'Cash';
      case OrderType.online:
        return 'Online';
    }
  }

  String get value {
    return toString().split('.').last;
  }
}
enum DateFilter {
  today,
  yesterday,
  thisMonth,
  lifetime,
  custom,
}