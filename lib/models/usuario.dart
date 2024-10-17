class Usuario{

  String _idUsuario = "";
  String _nome = "";
  String _email = "";
  String _senha = "";
  String _tipoUsuario = "";

  Usuario();

  String verificarTipoUsuario(bool tipoUsuario){
    return tipoUsuario ? "motorista" : "passageiro";
  }

  Map<String,dynamic> toMap(){
    Map<String, dynamic> map = {
      "nome":this.nome,
      "email":this.email,
      "tipoUsuario":this.tipoUsuario,

    };
    return map;
  }


  String get tipoUsuario => _tipoUsuario;

  set tipoUsuario(String value) {
    _tipoUsuario = value;
  }

  String get senha => _senha;

  set senha(String value) {
    _senha = value;
  }

  String get email => _email;

  set email(String value) {
    _email = value;
  }

  String get nome => _nome;

  set nome(String value) {
    _nome = value;
  }

  String get idUsuario => _idUsuario;

  set idUsuario(String value) {
    _idUsuario = value;
  }
}