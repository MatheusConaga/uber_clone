import 'package:flutter/material.dart';
import 'package:uber_clone/models/usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber_clone/routes/routeGenerator.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({super.key});

  @override
  State<Cadastro> createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {

  TextEditingController _controllerNome = TextEditingController();
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  bool _tipoUsuario = false;
  String _mensagemErro = "";

  _validarCampos(){

    String nome = _controllerNome.text;
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    if(nome.isNotEmpty){

      if (email.isNotEmpty && email.contains("@") ){

        if(senha.isNotEmpty && senha.length >= 8){

          Usuario usuario = Usuario();
          usuario.nome = nome;
          usuario.email = email;
          usuario.senha = senha;
          usuario.tipoUsuario = usuario.verificarTipoUsuario(_tipoUsuario);

          _cadastrarUsuario(usuario);

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


    } else{
      setState(() {
        _mensagemErro = "Insira o nome corretamente!";
      });
    }

  }

  _cadastrarUsuario( Usuario usuario ) async{

    FirebaseAuth auth = FirebaseAuth.instance;

    auth.createUserWithEmailAndPassword(
        email: usuario.email,
        password: usuario.senha
    ).then((UserCredential usercredential){

      FirebaseFirestore db = FirebaseFirestore.instance;

      db.collection("usuarios")
      .doc(usercredential.user!.uid)
      .set(
        usuario.toMap()
      );

      switch( usuario.tipoUsuario ){
        case "motorista":
          Navigator.pushNamedAndRemoveUntil(context, Routes.motorista, (_)=> false);
          break;
        case "passageiro":
          Navigator.pushNamedAndRemoveUntil(context, Routes.passageiro, (_)=> false);
          break;

      }

    }).catchError((erro){
      _mensagemErro = "Erro ao cadastrar usuario!";
    });

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black54,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Cadastro no uber", style: TextStyle(color: Colors.white),),
      ),
      body: Container(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              //Inserir o nome
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllerNome,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    hintText: "Insira o nome",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32)
                    ),
                  ),
                ),
              ),

              // Inserir o email
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

              // Inserir senha

              Padding(
                padding: EdgeInsets.only(bottom: 10),
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

              // Marcador se for Passageiro ou Motorista

              Padding(
                  padding: EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Passageiro", style: TextStyle(fontSize: 16),),
                    Switch(
                        value: _tipoUsuario,
                        onChanged: (bool valor){
                          setState(() {
                            _tipoUsuario = valor;
                          });
                        }
                    ),
                    Text("Motorista", style: TextStyle(fontSize: 16),),
                  ],
                ),
              ),

              // Botao de cadastrar

              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,),
                    onPressed: (){
                      _validarCampos();
                    },
                    child: Text("Cadastrar",style: TextStyle(color: Colors.white, fontSize: 20),)
                ),
              ),

              // Mensagem de erro

              Center(

                child: Text(
                    _mensagemErro,
                  style: TextStyle(color: Colors.red, fontSize: 20),
                ),

              ),

            ],
          ),
        ),
      ),
    );
  }
}
