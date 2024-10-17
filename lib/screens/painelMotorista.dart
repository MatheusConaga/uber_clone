import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber_clone/routes/routeGenerator.dart';

class PainelMotorista extends StatefulWidget {
  const PainelMotorista({super.key});

  @override
  State<PainelMotorista> createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  FirebaseAuth auth = FirebaseAuth.instance;
  List<String> itensMenu = [
    "Configuracoes", "Deslogar"
  ];

  _deslogarUsuario() async{
    await auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_)=> false);
  }

  _escolhaMenu( String escolha ){

    switch (escolha){
      case "Deslogar":
        _deslogarUsuario();
        break;

    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel do motorista"),
        actions: [
          PopupMenuButton(
            onSelected: _escolhaMenu,
            itemBuilder: (context){
              return itensMenu.map((String item){
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Container(),
    );
  }
}
