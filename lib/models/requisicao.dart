import 'package:uber_clone/models/destino.dart';
import 'package:uber_clone/models/usuario.dart';

class Requisicao {
  String _id = "";
  String _status = "";
  Usuario? _passageiro;
  Usuario? _motorista;
  Destino? _destino;

  Requisicao();

  Map<String, dynamic> toMap() {
    // Verifique se o passageiro não é nulo antes de acessar suas propriedades
    Map<String, dynamic> dadosPassageiro = {
      "nome": _passageiro?.nome, // Usa o operador de acesso seguro
      "email": _passageiro?.email,
      "tipoUsuario": _passageiro?.tipoUsuario,
      "idUsuario": _passageiro?.idUsuario,
    };

    // Verifique se o destino não é nulo antes de acessar suas propriedades
    Map<String, dynamic> dadosDestino = {
      "rua": _destino?.rua,
      "numero": _destino?.numero,
      "bairro": _destino?.bairro,
      "cep": _destino?.cep,
      "latitude": _destino?.latitude,
      "longitude": _destino?.longitude,
    };

    Map<String, dynamic> dadosRequisicao = {
      "status": _status,
      "passageiro": dadosPassageiro,
      "motorista": null, // Se você tiver um motorista, coloque aqui.
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
