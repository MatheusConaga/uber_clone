import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber_clone/models/usuario.dart';
import 'package:uber_clone/routes/routeGenerator.dart';
import 'package:uber_clone/utils/statusRequisicao.dart';
import 'package:uber_clone/utils/usuarioFirebase.dart';

class Corrida extends StatefulWidget {
  final String idRequisicao;

  const Corrida(this.idRequisicao, {super.key});

  @override
  State<Corrida> createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  String _idRequisicao = "";
  String _mensagemStatus = "";
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;
  Map<String, dynamic> _dadosRequisicao = {};
  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-2.911022, -41.753691),
    zoom: 18,
  );
  final List<String> _itensMenu = ["Configurações", "Deslogar"];

  Future<void> _deslogarUsuario() async {
    FirebaseAuth _auth = FirebaseAuth.instance;
    try {
      await _auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
    } catch (e) {
      print("Erro ao deslogar: $e");
    }
  }

  void _escolhaMenu(String escolha) {
    if (escolha == "Deslogar") {
      _deslogarUsuario();
    }
  }

  String _textoBotao = "Aceitar Corrida";
  Color _corBotao = Colors.blue;
  void Function()? _funcaoBotao;

  late Position _localMotorista;

  _alterarBotaoPrincipal(String texto, Color cor, void Function() funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  void _adicionarListenerLocalizacao() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getLastKnownPosition().then((Position? position) {
      if (position != null) {
        setState(() {
          _localMotorista = position;
        });
        // Movimenta a câmera para a última localização conhecida
        _movimentarCamera(CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        ));
        _exibirMarcador(
          position,
          "assets/images/motorista.png",
          "Motorista",
        );
      }
    });

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (position != null) {
        print("Posição recebida: ${position.latitude}, ${position.longitude}");

        setState(() {
          _localMotorista = position;
        });

        // Se a requisição já foi iniciada, atualiza a localização no Firebase
        if (_idRequisicao.isNotEmpty && _statusRequisicao != StatusRequisicao.AGUARDANDO) {
          UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao,
            position.latitude,
            position.longitude,
            "motorista"
          );
        } else{
          setState(() {
            _localMotorista = position;
          });
          _statusAguardando();
        }

        // Movimenta a câmera para a nova posição do motorista
        _movimentarCamera(CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        ));

        _exibirMarcador(
          position,
          "assets/images/motorista.png",
          "Motorista",
        );
      }
    });
  }


  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> _recuperaLocalizacao() async {
    try {
      var locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null) {

      }
    } catch (e){
      print("Erro de execução $e");
    }
  }

  Future<void> _movimentarCamera(CameraPosition cameraPosition) async {
    final GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

  void _exibirMarcador(Position local, String caminhoIcone, String infoWindow) async {
     final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final BitmapDescriptor bitmapIcone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      caminhoIcone,
    );

     _marcadores = {};

    final Marker marcador = Marker(
      markerId: MarkerId(infoWindow),
      position: LatLng(local.latitude, local.longitude),
      infoWindow: InfoWindow(title: infoWindow),
      icon: bitmapIcone,
    );

    setState(() {
      _marcadores.add(marcador);
    });
  }


  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot = await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .get();

    if (documentSnapshot.data() != null) {
      _dadosRequisicao = documentSnapshot.data() as Map<String, dynamic>;

    } else {
      print("Nenhuma requisição encontrada.");
    }
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    await db.collection("requisicoes").doc(_idRequisicao).snapshots().listen((snapshot) {
      if (snapshot.data() != null) {

        _dadosRequisicao = snapshot.data() as Map<String, dynamic>;

        Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
        _statusRequisicao = dados["status"];

        switch (_statusRequisicao) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.CAMINHO:
            _statusCaminho();
            break;
          case StatusRequisicao.VIAGEM:
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA:
            _statusFinalizada();
            break;
          case StatusRequisicao.CONFIRMADA:
            _statusConfirmada();
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal(
      "Aceitar corrida",
      Colors.blue,
          () {
        _aceitarCorrida();
      },
    );

    if( _localMotorista != null ){
      double motoristaLat = _localMotorista!.latitude;
      double motoristaLon = _localMotorista!.longitude;

      Position position = Position(
          latitude: motoristaLat,
          longitude: motoristaLon,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0
      );

      _exibirMarcador(
        position,
        "assets/images/motorista.png",
        "motorista",
      );

      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 18,
      );

      _movimentarCamera(cameraPosition);

    }

  }

  _statusCaminho() {
    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
      "Iniciar corrida",
      Colors.blue,
          () {
        _iniciarCorrida();
          },
    );

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];


    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    _exibirDoisMarcadores(
      LatLng(latitudeMotorista, longitudeMotorista),
      LatLng(latitudePassageiro, longitudePassageiro),
    );

    var nLat, nLon, sLat, sLon;
    if( latitudeMotorista <= latitudePassageiro ){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    } else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if( longitudeMotorista <= longitudePassageiro ){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    } else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

      _movimentarCameraBounds(
          LatLngBounds(
            northeast: LatLng(nLat, nLon),
            southwest: LatLng(sLat, sLon),
          ),
      );

  }

  _finalizarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes")
    .doc( _idRequisicao )
    .update({
      "status":StatusRequisicao.FINALIZADA
    });


    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
        .doc( idPassageiro )
        .update({
      "status": StatusRequisicao.FINALIZADA
    });

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .doc( idMotorista )
        .update({
      "status": StatusRequisicao.FINALIZADA
    });

  }

  _statusFinalizada() async{

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["origem"]["longitude"];

    double distanciaEmMetros = await Geolocator.distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestino,
        longitudeDestino
    );

    double distanciaKm = distanciaEmMetros / 1000;

    double valorViagem = distanciaKm * 8;

    var f = NumberFormat('#,##0.00', 'pt_BR');
    var valorViagemFormatado = f.format(valorViagem);

    _mensagemStatus = "Viagem finalizada";
    _alterarBotaoPrincipal(
      "Confirmar - R\$ ${valorViagemFormatado}",
      Colors.blue,
          () {
        _confirmarCorrida();
      },
    );

    Position position = Position(
        latitude: latitudeDestino,
        longitude: longitudeDestino,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0
    );

    _exibirMarcador(
      position,
      "assets/images/destino.png",
      "Destino",
    );

    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );

    _movimentarCamera(cameraPosition);


  }

  _statusConfirmada(){

    Navigator.pushReplacementNamed(
        context,
        Routes.motorista
    );

  }

  _confirmarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
        .doc( _idRequisicao )
        .update({
      "status": StatusRequisicao.CONFIRMADA
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
        .doc( idPassageiro )
        .delete();

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .doc( idMotorista )
        .delete();

  }

  _statusEmViagem() {
    _mensagemStatus = "Em viagem";
    _alterarBotaoPrincipal(
      "Finalizar corrida",
      Colors.blue,
          () {
        _finalizarCorrida();
      },
    );

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    _exibirDoisMarcadores(
      LatLng(latitudeOrigem, longitudeOrigem),
      LatLng(latitudeDestino, longitudeDestino),
    );

    var nLat, nLon, sLat, sLon;
    if( latitudeOrigem <= latitudeDestino ){
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    } else{
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if( longitudeOrigem <= longitudeDestino ){
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    } else{
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }

    _movimentarCameraBounds(
      LatLngBounds(
        northeast: LatLng(nLat, nLon),
        southwest: LatLng(sLat, sLon),
      ),
    );

  }



  _iniciarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc( _idRequisicao )
    .update({
      "origem":{
        "latitude": _dadosRequisicao["motorista"]["latitude"],
        "longitude": _dadosRequisicao["motorista"]["longitude"],
      },
      "status": StatusRequisicao.VIAGEM
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
    .doc( idPassageiro )
    .update({
      "status": StatusRequisicao.VIAGEM
    });

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .doc( idMotorista )
        .update({
      "status": StatusRequisicao.VIAGEM
    });
    
  }

  Future<void> _movimentarCameraBounds( LatLngBounds latLngBounds ) async {
    final GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        latLngBounds,
          100,
      ),
    );
  }

  _exibirDoisMarcadores(LatLng latLngMot, LatLng latLongPas ) async{

    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    Set<Marker> _listaMarcadores ={};


    final BitmapDescriptor icone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      "assets/images/motorista.png",
    );

    final Marker marcadorMotorista = Marker(
      markerId: const MarkerId("marcador-motorista"),
      position: LatLng(latLngMot.latitude, latLngMot.longitude),
      infoWindow: const InfoWindow(title: "Local motorista"),
      icon: icone,
    );
    _listaMarcadores.add(marcadorMotorista);

    final BitmapDescriptor iconeP = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      "assets/images/passageiro.png",
    );

    final Marker marcadorPassageiro = Marker(
      markerId: const MarkerId("marcador-passageiro"),
      position: LatLng(latLongPas.latitude, latLongPas.longitude),
      infoWindow: const InfoWindow(title: "Local passageiro"),
      icon: iconeP,
    );

    _listaMarcadores.add(marcadorPassageiro);

    setState(() {
      _marcadores = _listaMarcadores;
    });


  }


  _aceitarCorrida() async {
    String idRequisicao = _dadosRequisicao["id"];
    FirebaseFirestore db = FirebaseFirestore.instance;

    Usuario? motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista!.latitude = _localMotorista.latitude;
    motorista!.longitude = _localMotorista.longitude;


    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": motorista.toMap(),
      "status": StatusRequisicao.CAMINHO,
    }).then((_) {

      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa").doc(idPassageiro).update({
        "status": StatusRequisicao.CAMINHO,
      });

      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista").doc(idMotorista).set({
        "id_requisicao": idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.CAMINHO,
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _adicionarListenerLocalizacao();
    _idRequisicao = widget.idRequisicao;
    _adicionarListenerRequisicao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - " + _mensagemStatus),
        actions: [
          PopupMenuButton(
            onSelected: _escolhaMenu,
            itemBuilder: (context) {
              return _itensMenu.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _posicaoCamera,
            onMapCreated: _onMapCreated,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            markers: _marcadores,
          ),
          Positioned(
            right: 0,
            left: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _corBotao),
                onPressed: _funcaoBotao,
                child: Text(_textoBotao, style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}