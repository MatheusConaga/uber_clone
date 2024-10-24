import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber_clone/routes/routeGenerator.dart';
import 'package:uber_clone/utils/statusRequisicao.dart';
import 'package:uber_clone/utils/usuarioFirebase.dart';

class PainelMotorista extends StatefulWidget {
  const PainelMotorista({super.key});

  @override
  State<PainelMotorista> createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

  FirebaseAuth auth = FirebaseAuth.instance;
  List<String> itensMenu = ["Configuracoes", "Deslogar"];

  _deslogarUsuario() async {
    await auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  _escolhaMenu(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
    }
  }

  Stream<QuerySnapshot> _adicionarListenerRequisicoes() {
    final stream = db
        .collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();

    stream.listen((dados){
      _controller.add(dados);
    });
    return stream;

  }
  _recuperaRequisicaoMotorista() async {
    try {
      User? firebaseUser = await UsuarioFirebase.getUsuarioAtual();

      if (firebaseUser == null) {
        Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
        return;
      }

      DocumentSnapshot documentSnapshot = await db
          .collection("requisicao_ativa_motorista")
          .doc(firebaseUser.uid)
          .get();

      var dadosRequisicao = documentSnapshot.data();

      if (dadosRequisicao == null) {
        _adicionarListenerRequisicoes();
      } else {
        String idRequisicao = (dadosRequisicao as Map<String, dynamic>)["id_requisicao"];
        Navigator.pushReplacementNamed(
          context,
          Routes.corrida,
          arguments: idRequisicao,
        );
      }
    } catch (e) {
      print("Erro ao recuperar a requisição ativa do motorista: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _recuperaRequisicaoMotorista();
  }

  @override
  Widget build(BuildContext context) {

    var mensagemCarregando = Center(
      child: Column(
        children: [
          Text("Carregando requisições"),
          CircularProgressIndicator(),
        ],
      ),
    );

    var mensagemSemDados = Center(
      child: Text(
          "Voce não tem nenhuma requisicao",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );


    return Scaffold(
      appBar: AppBar(
        title: Text("Painel do motorista"),
        actions: [
          PopupMenuButton(
            onSelected: _escolhaMenu,
            itemBuilder: (context) {
              return itensMenu.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: _controller.stream,
          builder: (context, snapshot) {
                switch(snapshot.connectionState){
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return mensagemCarregando;
                    break;
                  case ConnectionState.active:
                  case ConnectionState.done:

                    if(snapshot.hasError){
                      return Text("Erro ao carregar os dados!");
                    }else{
                      QuerySnapshot querySnapshot = snapshot.data as QuerySnapshot;
                      if( querySnapshot.docs.length == 0 ){

                        return mensagemSemDados;

                      } else{

                        return ListView.separated(
                          itemCount: querySnapshot.docs.length,
                          separatorBuilder: (context,index)=> Divider(
                            height: 2,
                            color: Colors.grey,
                          ),
                            itemBuilder: (context,index){

                              List<DocumentSnapshot> requisicoes = querySnapshot.docs.toList();
                              DocumentSnapshot item = requisicoes[index];

                              String idRequisicao = item["id"];
                              String nomePassageiro = item["passageiro"]["nome"];
                              String rua = item["destino"]["rua"];
                              String numero = item["destino"]["numero"];

                              return ListTile(
                                title: Text(nomePassageiro),
                                subtitle: Text("destino: $rua, $numero"),
                                onTap: (){
                                    Navigator.pushNamed(context, Routes.corrida, arguments: idRequisicao);
                                },
                              );

                            },
                        );

                      }

                    }

                    break;

                }
          }
          ),
    );
  }
}
