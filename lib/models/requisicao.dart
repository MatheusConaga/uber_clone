import 'package:uber_clone/models/destino.dart';
import 'package:uber_clone/models/usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Requisicao {
  String _id = "";
  String _status = "";
  Usuario? _passageiro;
  Usuario? _motorista;
  Destino? _destino;

  double latitude = 0.0;
  double longitude = 0.0;

  Requisicao(){

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentReference reference = db.collection("requisicoes")
    .doc();
    this.id = reference.id;

  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> dadosPassageiro = {
      "nome": _passageiro?.nome,
      "email": _passageiro?.email,
      "tipoUsuario": _passageiro?.tipoUsuario,
      "idUsuario": _passageiro?.idUsuario,
      "latitude": _passageiro?.latitude,
      "longitude": _passageiro?.longitude,
    };

    Map<String, dynamic> dadosDestino = {
      "rua": _destino?.rua,
      "numero": _destino?.numero,
      "bairro": _destino?.bairro,
      "cep": _destino?.cep,
      "latitude": _destino?.latitude,
      "longitude": _destino?.longitude,
    };

    Map<String, dynamic> dadosRequisicao = {
      "id": this.id,
      "status": _status,
      "passageiro": dadosPassageiro,
      "motorista": null,
      "destino": dadosDestino,
    };

    return dadosRequisicao;
  }

  Destino? get destino => _destino;

  set destino(Destino? value) {
    _destino = value;
  }

  Usuario? get motorista => _motorista;

  set motorista(Usuario? value) {
    _motorista = value;
  }

  Usuario? get passageiro => _passageiro;

  set passageiro(Usuario? value) {
    _passageiro = value;
  }

  String get status => _status;

  set status(String value) {
    _status = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }
}
