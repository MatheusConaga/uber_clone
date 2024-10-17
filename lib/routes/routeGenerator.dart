import 'package:flutter/material.dart';
import 'package:uber_clone/screens/cadastro.dart';
import 'package:uber_clone/screens/login.dart';
import 'package:uber_clone/screens/painelMotorista.dart';
import 'package:uber_clone/screens/painelPassageiro.dart';

class RouteGenerator{
  static Route<dynamic>generateRoute(RouteSettings settings){
    switch(settings.name){
      case Routes.login:
        return MaterialPageRoute(builder: (_) => Login());
      case Routes.cadastro:
        return MaterialPageRoute(builder: (_) => Cadastro());
      case Routes.passageiro:
        return MaterialPageRoute(builder: (_) => PainelPassageiro());
      case Routes.motorista:
        return MaterialPageRoute(builder: (_) => PainelMotorista());

      default:
        return MaterialPageRoute(builder: (context){
          return Scaffold(
            appBar: AppBar(
              title: const Text("Tela nao encontrada!"),
            ),
            body: const Center(
              child: Text("Tela nao encontrada!"),
            ),
          );
        });
    }

  }
}

class Routes{

  static const String login = "/";
  static const String cadastro = "/cadastro";
  static const String passageiro = "/passageiro";
  static const String motorista = "/motorista";

}

