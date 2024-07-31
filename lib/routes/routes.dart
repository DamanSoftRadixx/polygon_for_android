import 'package:get/get.dart';
import '../home_page.dart';


class Routes {
  Routes._();

  static const String root = "/";
  static const String appleMapTwo = "/appleMapTwo";

}

List<GetPage> appPages() => [
GetPage(
name: Routes.root,
page: () => const HomePage(),
fullscreenDialog: true,
),
];