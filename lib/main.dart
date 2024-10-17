import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uber_clone/routes/routeGenerator.dart';
import 'package:uber_clone/screens/cadastro.dart';
import 'package:uber_clone/screens/login.dart';


void main () async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _handleLocationPermission();

  runApp(MaterialApp(
    title: "Uber",
    debugShowCheckedModeBanner: false,
    initialRoute: Routes.login,
    home: Login(),
    onGenerateRoute: RouteGenerator.generateRoute,
  ));
}

Future<void>_handleLocationPermission() async{
  LocationPermission permission;

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if(!serviceEnabled){
    print("Serviço de localização desabilitado");
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied){
    permission = await Geolocator.requestPermission();
    if(permission == LocationPermission.denied){
      print("Permissao de localização negada");
    }
  }
  if(permission == LocationPermission.deniedForever){
    print("Permissao de localização permanentemente negada");
  }
  if (permission == LocationPermission.whileInUse || permission == LocationPermission.always){
    print("Permissao de localizacao conceida");
  }
}

