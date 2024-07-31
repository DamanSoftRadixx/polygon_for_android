import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mapTol;
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

class HomeController extends GetxController {
  Completer<GoogleMapController> controller = Completer();
  final CameraPosition kGoogle = const CameraPosition(
    target: LatLng(40.718504, -73.996847),
    zoom: 13,
  );
  double oneSquareMileInSquareMeters = 2599999.0;
  double oneSquareMile = 2599999.0;
  var pentagonEnable = false.obs;
  var isDraggingPolygon = false.obs;
  RxnString totalArea = RxnString();
  Uint8List? iconUniCode;
  var initialDragPosition = Rxn<LatLng>();
  Timer? debounce;
  Timer? onCameraDebounce;
  Map<MarkerId, LatLng> markerPositions = Map();
  var refreshMap = false.obs;
  var polygon = <Polygon>{};

  @override
  void onInit() {
    // getImages('assets/png/custom_marker_two.png', 100);
    super.onInit();
  }

  double calculateRadiusForAreaa(double area, int numberOfSides) {
    return math.sqrt(
        (2 * area) / (numberOfSides * math.sin((2 * math.pi) / numberOfSides)));
  }

  Future<List<LatLng>> getPentagonCoordinates() async {
    if (pentagonEnable.value) {
      return [];
    }
    const int numberOfSides = 5;
    double radiusInMeters =
        calculateRadiusForAreaa(oneSquareMileInSquareMeters, numberOfSides);
    GoogleMapController controllerr = await controller.future;
    LatLngBounds bounds = await controllerr.getVisibleRegion();
    LatLng center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
    const double angleBetweenVertices = 360.0 / numberOfSides;
    final List<LatLng> pentagonPoints = [];
    var tempList = <MarkerId, LatLng>{};
    for (var i = 0; i < numberOfSides; i++) {
      final double currentAngle = angleBetweenVertices * i;
      final double angleInRadians = math.pi * currentAngle / 180.0;
      final double xOffset = math.cos(angleInRadians) * radiusInMeters;
      final double yOffset = math.sin(angleInRadians) * radiusInMeters;
      var latLng = LatLng(
          center.latitude + (yOffset / 111320),
          center.longitude +
              (xOffset / (111320 * math.cos(center.latitude * math.pi / 180))));
      pentagonPoints.add(latLng);
      var length = tempList.length;
      var markerId = MarkerId('Marker ${length == 0 ? 1 : (length + 1)}');
      tempList[markerId] = latLng;
    }
    // polygon.clear();
    // markerPositions.value = tempList;
    initializePolygonsFirstTime(tempList);
    return pentagonPoints;
  }

  Future<Uint8List> getImages(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    var icon = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    iconUniCode = icon;
    refreshMap.value = true;
    print('inside getImages  ${iconUniCode}');
    return icon;
    //await appleMap.BitmapDescriptor.fromBytes(markerIcon)
    // icon: await googleMap.BitmapDescriptor.fromBytes(markerIcon), png iamge
  }

/*  onMarkerTap(LatLng lat) async {
    var length = markerPositions.length;
    if (length < 5) {
      var markerId = MarkerId('Marker ${length == 0 ? 1 : (length + 1)}');
      markerPositions[markerId] = lat;
      initializePolygons(list: markerPositions);
      // // setState(() {});
    }
  }*/

  onMarkerTapped(MarkerId markerId, {required BuildContext context}) async {
    var position = markerPositions[markerId];
    final tappedLat = position?.latitude;
    final tappedLng = position?.longitude;
    print('Tapped marker position: $tappedLat, $tappedLng');
    calculateArea(fromClick: true, context: context);
  }

  onDragEnd(MarkerId markerId, LatLng position) async {
    isDraggingPolygon.value = false;
    initialDragPosition.value = null;
    LatLng previousLatLang = markerPositions[markerId]!;
    markerPositions[markerId] = position;
    refreshMap.refresh();
    if (await isAreaMoreThanOneSquareMile()) {
      Future.delayed(const Duration(milliseconds: 250), () {
        markerPositions[markerId] = previousLatLang;
        refreshMap.refresh();
      });
    } else {
      await initializePolygons();
    }
  }

  initializePolygonsFirstTime(Map<MarkerId, LatLng> markerPosition) async {
    if (markerPosition.length > 2) {
      await Future.delayed(
          Duration(milliseconds: polygon.isNotEmpty ? 300 : 0));
      List<LatLng> markList = markerPosition.entries
          .where((entry) => !(entry.key.toString().startsWith('center')))
          .map((entry) => entry.value)
          .toList();
      polygon.clear();
      polygon.add(await Polygon(
        polygonId: PolygonId(math.Random.secure().nextInt(1000).toString()),
        points: markList,
        fillColor: Color(0xFF00ACDB).withOpacity(0.3),
        strokeColor: Color(0xFF00ACDB),
        geodesic: true,
        strokeWidth: 4,
      ));
      refreshMap.refresh();
      await Future.delayed(const Duration(milliseconds: 250));
      markerPositions = markerPosition;
      pentagonEnable.value = true;
      refreshMap.refresh();
      calculateArea(fromClick: false, context: null);
    }
    return true;
  }

  initializePolygons({bool firstTimeCreate = false}) {
    if (markerPositions.length > 2) {
      if (debounce?.isActive ?? false) debounce?.cancel();
      debounce =
          Timer(Duration(milliseconds: firstTimeCreate ? 0 : 250), () async {
        // polygon.clear();
        // markerPositions.refresh();
        // await Future.delayed(const Duration(milliseconds: 250));
        List<LatLng> markList = markerPositions.entries
            .where((entry) => !(entry.key.toString().startsWith('center')))
            .map((entry) => entry.value)
            .toList();
        polygon.clear();
        polygon.add(Polygon(
          visible: true,
          polygonId: PolygonId(math.Random.secure().nextInt(1000).toString()),
          // polygonId: const PolygonId('1'),
          points: markList,
          fillColor: Color(0xFF00ACDB).withOpacity(0.3),
          strokeColor: Color(0xFF00ACDB),
          geodesic: true,
          strokeWidth: 4,
        ));
        await Future.delayed(Duration(milliseconds: 0));
        refreshMap.refresh();
        calculateArea(fromClick: false, context: null);
      });
    }
    return true;
  }

  void onCameraMove(CameraPosition position) async {
    if (markerPositions.length > 2) {
      if (isDraggingPolygon.value && initialDragPosition.value != null) {
        LatLng newDragPosition = position.target;
        double deltaLat =
            newDragPosition.latitude - initialDragPosition.value!.latitude;
        double deltaLng =
            newDragPosition.longitude - initialDragPosition.value!.longitude;
        var newMarkerPositions = Map<MarkerId, LatLng>.from(markerPositions);
        await Future.forEach(newMarkerPositions.entries, (entry) async {
          var key = entry.key;
          var value = entry.value;
          newMarkerPositions[key] =
              LatLng(value.latitude + deltaLat, value.longitude + deltaLng);
        });

        initialDragPosition.value = newDragPosition;
        markerPositions = newMarkerPositions;
        refreshMap.refresh();
        initializePolygons();
      }
    } else {
      changePolygenAreaAcdoingtToZoom();
    }
  }

  changePolygenAreaAcdoingtToZoom() async {
    var zoomLevel = await ((await controller.future).getZoomLevel());
    print('zoomLevel for adujct $zoomLevel');
    switch (zoomLevel) {
      case >= 18.50:
        oneSquareMileInSquareMeters = 900;
      case >= 18:
        oneSquareMileInSquareMeters = 5000.0;
      case >= 17.50:
        oneSquareMileInSquareMeters = 10000.0;
      case >= 17:
        oneSquareMileInSquareMeters = 18000.0;
      case >= 16.50:
        oneSquareMileInSquareMeters = 22000.0;
      case >= 16:
        oneSquareMileInSquareMeters = 25000.0;
      case >= 15.50:
        oneSquareMileInSquareMeters = 109999.0;
      case >= 15:
        oneSquareMileInSquareMeters = 209999.0;
      case >= 14.70:
        oneSquareMileInSquareMeters = 2299999.0;
      default:
        oneSquareMileInSquareMeters = 2599999.0;
        break;
    }
    print('oneSquareMileInSquareMeters $oneSquareMileInSquareMeters');
    // oneSquareMileInSquareMeters=zoomLevel;
  }

  void calculateArea(
      {bool fromClick = false, required BuildContext? context}) async {
    if (markerPositions.length > 2) {
      List<mapTol.LatLng> points = markerPositions.values
          .map((point) => mapTol.LatLng(point.latitude, point.longitude))
          .toList();
      final area =
          (await mapTol.SphericalUtil.computeArea(points)); // square meters.

      // Convert area to appropriate units and format it.
      const sqMetersToSqFeet = 10.7639;
      const sqMetersToSqMiles = 3.861e-7;

      String formattedArea;
      if (area > 2.58999e+6) {
        // 1 square mile in square meters
        final areaInSquareMiles = area * sqMetersToSqMiles;
        formattedArea = '${areaInSquareMiles.toStringAsFixed(2)} sq miles';
      } else {
        final areaInSquareFeet = area * sqMetersToSqFeet;
        if (areaInSquareFeet > 1000) {
          // formattedArea =
          //     '${(areaInSquareFeet / 1000).toStringAsFixed(2)} sqft';
          formattedArea = '${areaInSquareFeet.toInt()} sqft';
        } else {
          formattedArea = '${areaInSquareFeet.toStringAsFixed(2)} sqft';
        }
      }
      totalArea.value = formattedArea;
      // totalArea = '$area';
      print('Area of polygon: $area square meters');
      if (fromClick && context != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Property Area"),
              content: Text("The area of the property is $formattedArea."),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      print('Not enough points to form a polygon');
    }
  }

  Future<num> getArea() async {
    if (markerPositions.length > 2) {
      List<mapTol.LatLng> points = markerPositions.values
          .map((point) => mapTol.LatLng(point.latitude, point.longitude))
          .toList();
      final area =
          (await mapTol.SphericalUtil.computeArea(points)); // square meters.
      return area;
    } else {
      return 0;
    }
  }

  Future<bool> isAreaMoreThanOneSquareMile({bool showSnap = true}) async {
    final areaInSquareMeters = await getArea();
    // var isMoreThan = areaInSquareMeters > oneSquareMileInSquareMeters;
    var isMoreThan = areaInSquareMeters > oneSquareMile;
    if (isMoreThan && showSnap) {
      Fluttertoast.showToast(
          msg: "Area selection is limited to 1 square mile.",
          // msg: "Area selection is limited to ${totalArea.value} square mile.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          backgroundColor: Colors.red,
          fontSize: 16.0);
    }
    return isMoreThan;
  }

  Future checkInsidePolygonOrNot(LatLng lat) async {
    var pointCheck = mapTol.LatLng(lat.latitude, lat.longitude);
    var points = markerPositions.values
        .map((value) => mapTol.LatLng(value.latitude, value.longitude))
        .toList();
    final insidePolyOrNot =
        mapTol.PolygonUtil.containsLocation(pointCheck, points, false);
    if (insidePolyOrNot) {
      Future.delayed(
        const Duration(milliseconds: 2500),
        () {
          if (initialDragPosition == lat) {
            isDraggingPolygon.value = false;
            initialDragPosition.value = null;
          }
        },
      );
      isDraggingPolygon.value = true;
      initialDragPosition.value = lat;
    } else {
      isDraggingPolygon.value = false;
    }
  }

  void onLongPress(LatLng lat) async {
    checkInsidePolygonOrNot(lat);
  }

  onClearPolygenTap() async {
    changePolygenAreaAcdoingtToZoom();
    await _deleteCacheDir();
    markerPositions.clear();
    refreshMap.refresh();
    await Future.delayed(const Duration(milliseconds: 250));
    polygon.clear();
    refreshMap.refresh();
    pentagonEnable.value = false;
    isDraggingPolygon.value = false;
    initialDragPosition.value = null;
    totalArea.value = null;
  }
  Future<void> _deleteCacheDir() async {
    try {
      var tempDir = await  getTemporaryDirectory();

      if (await tempDir.exists()) {
        // Get the list of files in the directory
        var files = tempDir.listSync();

        // Delete each file
        for (var file in files) {
          try {
            if (file is File) {
              await file.delete();
            } else if (file is Directory) {
              await file.delete(recursive: true);
            }
          } catch (e) {
            print("Error deleting file: $e");
          }
        }
        print("Temporary cache cleared");
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
    /* try {
      var tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final dir = Directory(tempDir.path);
        await dir.delete(recursive: true);
        print("Temporary cache cleared");
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }*/

  }


  onCameraIdle() {
    isDraggingPolygon.value = false;
    initialDragPosition.value = null;
  }
}
