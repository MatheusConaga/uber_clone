import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber_clone/models/usuario.dart';
import 'package:uber_clone/routes/routeGenerator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  String _mensagemErro = "";
  bool _carregando = false;


  _validarCampos(){

    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

      if (email.isNotEmpty && email.contains("@") ){

        if(senha.isNotEmpty && senha.length >= 8){

          Usuario usuario = Usuario();
          usuario.email = email;
          usuario.senha = senha;

          _logarUsuario( usuario );

        } else{
          setState(() {
            _mensagemErro = "Insira ao menos 8 caracteres na senha!";
          });
        }

      } else{
        setState(() {
          _mensagemErro = "Insira o email corretamente";
        });
      }
  }

  _logarUsuario(Usuario usuario){

    setState(() {
      _carregando = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;
    
    auth.signInWithEmailAndPassword(
        email: usuario.email,
        password: usuario.senha
    ).then((UserCredential usercredential){

    _redirecionaUsuario(usercredential.user!.uid);

    }).catchError((erro){
        _mensagemErro = "Erro ao autenticar usuario, verifique e-mail e senha e tente novamente!";
    });

  }

  _redirecionaUsuario( String idUsuario ) async{

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot = await db.collection("usuarios")
    .doc( idUsuario )
    .get();

    Map<String,dynamic> dados = snapshot.data() as Map<String,dynamic>;
    String tipoUsuario = dados["tipoUsuario"];

    setState(() {
      _carregando = false;
    });

    switch( tipoUsuario ){
      case "motorista":
        Navigator.pushNamedAndRemoveUntil(context, Routes.motorista, (_)=> false);
        break;
      case "passageiro":
        Navigator.pushNamedAndRemoveUntil(context, Routes.passageiro, (_)=> false);
        break;
    }

  }

  _verificarUsuarioLogado() async{
    FirebaseAuth auth = FirebaseAuth.instance;
    User? usuarioLogado = await auth.currentUser;
    if(usuarioLogado != null){

      String idUsuario = usuarioLogado.uid;
      _redirecionaUsuario(idUsuario);

    }
  }

  @override
  void initState() {
    _verificarUsuarioLogado();
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/fundo.png"), fit: BoxFit.cover)),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _carregando
                    ? Center(child: CircularProgressIndicator(backgroundColor: Colors.white ,),)
                    : Container(),
                //imagem
                Padding(
                    padding: EdgeInsets.only(bottom: 26, top: 20),
                  child: Image(image: AssetImage("assets/images/logo.png"), width: 150,height: 150,),
                ),
                // input email
                Padding(
                    padding: EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _controllerEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Insira o e-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32)
                      ),
                    ),
                  ),
                ),
                // input senha
                Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: TextField(
                    controller: _controllerSenha,
                    keyboardType: TextInputType.text,
                    obscureText: true,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Insira a senha",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32)
                      ),
                    ),
                  ),
                ),
                // botao de cadastro
                Padding(
                    padding: EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,),
                      onPressed: (){
                        _validarCampos();
                      },
                      child: Text("Entrar",style: TextStyle(color: Colors.white, fontSize: 20),)
                  ),
                ),
                // link que redireciona para cadastro
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context,Routes.cadastro),
                    child: Text(
                      "Não possui conta? cadastre-se",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                Padding(
                    padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      _mensagemErro,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

