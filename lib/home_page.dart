import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'controller/home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  HomeController controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00ACDB),
          title: const Text(
            "Polygon demo",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Obx(() {
                var refresh = controller.refreshMap.value;
                var markerList = controller.markerPositions;
                print('------- build googleMap');
                return GoogleMap(
                    zoomControlsEnabled: false,
                    buildingsEnabled: true,
                    indoorViewEnabled: true,
                    polygons: controller.polygon,
                    markers: markerList.isEmpty?{}:markerList.keys.map((markerId) {
                      return Marker(
                        draggable: true,
                        consumeTapEvents: true,
                        visible: true,
                        markerId: markerId,
                        icon:BitmapDescriptor.defaultMarker,
                        // icon: controller.iconUniCode != null
                        //     ? BitmapDescriptor.fromBytes(
                        //         controller.iconUniCode!)
                        //     : BitmapDescriptor.defaultMarker,
                        position: markerList[markerId]!,
                        onTap: () => controller.onMarkerTapped(markerId,context:context),
                        onDragEnd: (value) => controller.onDragEnd(markerId, value),
                      );
                    }).toSet(),
                    onLongPress: controller.onLongPress,
                    initialCameraPosition: controller.kGoogle,
                    mapType: MapType.hybrid,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    onCameraMove: controller.onCameraMove,
                    onMapCreated: (GoogleMapController controllerr) {
                      controller.controller.complete(controllerr);
                    },
                    onCameraIdle: () => controller.onCameraIdle(),
                  mapToolbarEnabled: refresh,
                );
              }),
              Obx(() => !controller.pentagonEnable.value
                  ? Positioned(
                      top: 50,
                      right: 20,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith((states) {
                            // If the button is pressed, return green, otherwise blue
                            if (states.contains(MaterialState.pressed)) {
                              return Colors.green;
                            }
                            return Colors.blue;
                          }),
                          textStyle:
                              MaterialStateProperty.resolveWith((states) {
                            // If the button is pressed, return size 40, otherwise 20
                            if (states.contains(MaterialState.pressed)) {
                              return TextStyle(fontSize: 40);
                            }
                            return TextStyle(fontSize: 20);
                          }),
                        ),
                        onPressed: () {
                          controller.getPentagonCoordinates();
                        },
                        child: const Text(
                          'Draw',
                          style: TextStyle(color: Colors.white),
                        ),
                      ))
                  : SizedBox()),
              Obx(() {
                var totalArea = controller.totalArea.value;
                var dragging = controller.isDraggingPolygon.value;
                return totalArea != null
                    ? Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Column(
                            children: [
                              dragging
                                  ? const Text(
                                      'Move now',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 30),
                                    )
                                  : const SizedBox(),
                              dragging
                                  ? const SizedBox(
                                      height: 0,
                                    )
                                  : const SizedBox(),
                              totalArea != null
                                  ? Text(totalArea,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 25))
                                  : SizedBox()
                            ],
                          ),
                        ),
                      )
                    : const SizedBox();
              })
            ],
          ),
        ),
        floatingActionButton: Obx(() => controller.pentagonEnable.value
            ? FloatingActionButton(
                child: const Icon(Icons.clear),
                onPressed: () => controller.onClearPolygenTap())
            : const SizedBox()));
  }
}
