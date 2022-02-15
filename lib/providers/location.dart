import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider extends ChangeNotifier {
  final SharedPreferences sharedPreferences;
  LocationProvider({required this.sharedPreferences});  

  Future<void> getCurrentPosition(BuildContext context) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      sharedPreferences.setDouble("lat", position.latitude);
      sharedPreferences.setDouble("long", position.longitude);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      sharedPreferences.setString("currentNameAddress", "${place.thoroughfare} ${place.subThoroughfare} \n${place.locality}, ${place.postalCode}");
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch(e) {
      debugPrint(e.toString());
    } 
  }

  String get getCurrentNameAddress => sharedPreferences.getString("currentNameAddress") ?? "Location no Selected"; 

  double get getCurrentLat => sharedPreferences.getDouble("lat") ?? 0.0;
  
  double get getCurrentLng => sharedPreferences.getDouble("long") ?? 0.0;
}
