import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:uber_clone/models/destino.dart';
import 'package:uber_clone/models/marcador.dart';
import 'package:uber_clone/models/requisicao.dart';
import 'package:uber_clone/models/usuario.dart';
import 'package:uber_clone/routes/routeGenerator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uber_clone/utils/statusRequisicao.dart';
import 'package:uber_clone/utils/usuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({Key? key}) : super(key: key);

  @override
  State<PainelPassageiro> createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  final TextEditingController _controllerDestino = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Completer<GoogleMapController> _controller = Completer();

  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-2.911022, -41.753691),
    zoom: 18,
  );

  final List<String> _itensMenu = ["Configurações", "Deslogar"];
  Set<Marker> _marcadores = {};

  bool _exibirCaixaDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = Colors.blue;
  void Function()? _funcaoBotao;
  String _idRequisicao = "";
  late Position _posicaoPassageiro;
  late Map<String, dynamic> _dadosRequisicao;

  StreamSubscription<DocumentSnapshot>? _streamSubscriptionRequisicoes = null;


  void _exibirPassageiro(Position local) async {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final BitmapDescriptor icone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      "assets/images/passageiro.png",
    );

    final Marker marcadorPassageiro = Marker(
      markerId: MarkerId("marcador-passageiro"),
      position: LatLng(local.latitude, local.longitude),
      infoWindow: InfoWindow(title: "Meu local"),
      icon: icone,
    );

    setState(() {
      _marcadores.add(marcadorPassageiro);
    });
  }

  Future<void> _deslogarUsuario() async {
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

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> _recuperaLocalizacao() async {
    try {
      bool servicosHabilitados = await Geolocator.isLocationServiceEnabled();
      LocationPermission permissao = await Geolocator.checkPermission();

      if (!servicosHabilitados) {
        print("Os serviços de localização estão desabilitados.");
        return;
      }

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          print("Permissão de localização negada.");
          return;
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        print(
            "Permissão de localização negada permanentemente. Não é possível solicitar permissão.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _posicaoPassageiro = position;
      });

      _movimentarCamera(CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 18,
      ));

      _exibirPassageiro(position);
    } catch (e) {
      print("Erro ao recuperar localização: $e");
    }
  }

  Future<void> _movimentarCamera(CameraPosition cameraPosition) async {
    final GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

  void _adicionarListenerLocalizacao() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      print(
          "Localização do passageiro: ${position.latitude} e ${position.longitude}");

      if (position != null) {
        setState(() {
          _posicaoPassageiro = position;
        });

        if (_idRequisicao.isNotEmpty) {
          UsuarioFirebase.atualizarDadosLocalizacao(
              _idRequisicao,
              position.latitude,
              position.longitude,
              "passageiro"
          );
        } else{

          setState(() {
            _posicaoPassageiro = position;
          });
          _statusUberNaoChamado();
        }


      }
    });
  }

  Future<void> _chamarUber() async {
    final String enderecoDestino = _controllerDestino.text;

    if (enderecoDestino.isNotEmpty) {
      List<Location> listaEnderecos =
          await locationFromAddress(enderecoDestino);

      if (listaEnderecos.isNotEmpty) {
        final Location location = listaEnderecos[0];
        final double latitude = location.latitude;
        final double longitude = location.longitude;

        List<Placemark> placemarks =
            await placemarkFromCoordinates(latitude, longitude);

        if (placemarks.isNotEmpty) {
          final Placemark endereco = placemarks[0];
          Destino destino = Destino()
            ..cidade = endereco.administrativeArea ?? "N/A"
            ..cep = endereco.postalCode ?? "N/A"
            ..bairro = endereco.subLocality ?? "N/A"
            ..rua = endereco.thoroughfare ?? "N/A"
            ..latitude = latitude
            ..longitude = longitude
            ..numero = endereco.subThoroughfare ?? "N/A";

          String enderecoConfirmacao = '''
            Cidade: ${destino.cidade}
            Rua: ${destino.rua}, ${destino.numero}
            Bairro: ${destino.bairro}
            Cep: ${destino.cep}
          ''';

          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Confirmação do Endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: const EdgeInsets.all(16),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Salvar requisicao
                      _salvarRequisicao(destino);
                      Navigator.pop(context);
                    },
                    child: const Text("Confirmar",
                        style: TextStyle(color: Colors.green)),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    Usuario? passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro?.latitude = _posicaoPassageiro.latitude ?? 0.0;
    passageiro?.longitude = _posicaoPassageiro.longitude ?? 0.0;

    if (passageiro == null) {
      print("Usuário não está logado.");
      return;
    }

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino; // O destino deve ser não nulo aqui
    requisicao.passageiro = passageiro; // O passageiro não pode ser nulo
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // Salvar a requisição ao Firestore
      await db
          .collection("requisicoes")
          .doc(requisicao.id)
          .set(requisicao.toMap());
      print("Requisição salva com sucesso.");

      Map<String, dynamic> dadosRequisicaoAtiva = {};
      dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
      dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
      dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

      db
          .collection("requisicao_ativa")
          .doc(passageiro.idUsuario)
          .set(dadosRequisicaoAtiva);

      if (_streamSubscriptionRequisicoes == null){
        _adicionarListenerRequisicao(requisicao.id);

      }


    } catch (e) {
      print("Erro ao salvar a requisição: $e");
    }
  }

  _alterarBotaoPrincipal(String texto, Color cor, void Function() funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaDestino = true;
    _alterarBotaoPrincipal("Chamar uber", Colors.blue, () {
      _chamarUber();
    });

    if ( _posicaoPassageiro != null ){

      Position position = Position(
          latitude: _posicaoPassageiro.latitude,
          longitude: _posicaoPassageiro.longitude,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0);

      _exibirPassageiro(position);
      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(
          position.latitude,
          position.longitude,
        ),
        zoom: 18,
      );
      _movimentarCamera(cameraPosition);

    }

  }

  _statusAguardando() {
    _exibirCaixaDestino = false;
    _alterarBotaoPrincipal("Cancelar", Colors.red, () {
      _cancelarUber();
    });

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position = Position(
        latitude: _posicaoPassageiro.latitude,
        longitude: _posicaoPassageiro.longitude,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0);

    _exibirPassageiro(position);

    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );

    _movimentarCamera(cameraPosition);
  }

  _statusCaminho() {
    _exibirCaixaDestino = false;
    _alterarBotaoPrincipal(
        "Motorista a caminho",
        Colors.grey,
            () {

            }
    );

    double latitudeDestino = _dadosRequisicao["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "assets/images/motorista.png",
        "Local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "assets/images/passageiro.png",
        "Local passageiro"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _statusEmViagem() {
    _exibirCaixaDestino = false;
    _alterarBotaoPrincipal(
      "Em viagem",
      Colors.grey,
          () {
      },
    );

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "assets/images/motorista.png",
        "Local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "assets/images/destino.png",
        "Local destino"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
    
    
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


      _alterarBotaoPrincipal(
        "Total - R\$ ${valorViagemFormatado}",
        Colors.green,
            () {},
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

      _marcadores = {};

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

    if( _streamSubscriptionRequisicoes !=null ) {
      _streamSubscriptionRequisicoes!.cancel();
      _streamSubscriptionRequisicoes = null;
    }
      _exibirCaixaDestino = true;

      _alterarBotaoPrincipal(
          "Chamar uber",
          Colors.blue,
              () {
        _chamarUber();
      });


    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position = Position(
        latitude: _posicaoPassageiro.latitude,
        longitude: _posicaoPassageiro.longitude,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0);

    _exibirPassageiro(position);

    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );

    _movimentarCamera(cameraPosition);

    _dadosRequisicao = {};



  }

  void _exibirMarcador(Position local, String caminhoIcone, String infoWindow) async {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final BitmapDescriptor bitmapIcone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      caminhoIcone,
    );

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


  _exibirCentralizarDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino ){

    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;
    double latitudeDestino = marcadorDestino.local.latitude;
    double longitudeDestino = marcadorDestino.local.longitude;

    _exibirDoisMarcadores(
        marcadorOrigem,
        marcadorDestino,
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



  _exibirDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino ) async {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    Set<Marker> _listaMarcadores = {};
    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;

    final BitmapDescriptor icone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      marcadorOrigem.caminhoImagem,
    );

    final Marker mOrigem = Marker(
      markerId: MarkerId(marcadorOrigem.caminhoImagem),
      position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
      infoWindow: InfoWindow(title: marcadorOrigem.titulo),
      icon: icone,
    );
    _listaMarcadores.add(mOrigem);

    final BitmapDescriptor iconeP = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      marcadorDestino.caminhoImagem,
    );

    final Marker mDestino = Marker(
      markerId: MarkerId(marcadorDestino.caminhoImagem),
      position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
      infoWindow: InfoWindow(title: marcadorDestino.titulo),
      icon: iconeP,
    );

    _listaMarcadores.add(mDestino);

    setState(() {
      _marcadores = _listaMarcadores;
    });
  }

  Future<void> _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    final GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        latLngBounds,
        100,
      ),
    );
  }

  _cancelarUber() async {
    User? usuarioAtual = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes")
        .doc(_idRequisicao)
        .update({
      "status": StatusRequisicao.CANCELADA
        }).then((_) {

      db.collection("requisicao_ativa").doc(usuarioAtual!.uid).delete();

      _statusUberNaoChamado();

      if( _streamSubscriptionRequisicoes != null ){

        _streamSubscriptionRequisicoes!.cancel();
        _streamSubscriptionRequisicoes = null;

      }


    });
  }

  _recuperarRequisicaoAtiva() async {
    User? usuarioAtual = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot =
        await db.collection("requisicao_ativa").doc(usuarioAtual!.uid).get();

    if (documentSnapshot.data() != null) {
      Map<String, dynamic> dados =
          documentSnapshot.data() as Map<String, dynamic>;
      _idRequisicao = dados["id_requisicao"];
      _adicionarListenerRequisicao(_idRequisicao);
    } else {
      _statusUberNaoChamado();
    }
  }



  _adicionarListenerRequisicao(String idRequisicao) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    _streamSubscriptionRequisicoes = await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
        _dadosRequisicao = dados;

        // Verifique se _dadosRequisicao["status"] e _dadosRequisicao["id_requisicao"] não são nulos
        String status =
            dados["status"] ?? ""; // Use um valor padrão se for nulo
        _idRequisicao =
            dados["id"] ?? ""; // Use um valor padrão se for nulo

        switch (status) {
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
          default:
            print("Status desconhecido: $status");
        }
      } else {
        print("Document snapshot is null.");
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperaLocalizacao();
    _recuperarRequisicaoAtiva();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel Passageiro"),
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
          Visibility(
            visible: _exibirCaixaDestino,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  left: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white,
                      ),
                      child: const TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          icon: Padding(
                            padding: EdgeInsets.only(left: 10, right: 10),
                            child: Icon(Icons.location_on, color: Colors.green),
                          ),
                          hintText: "Meu Local",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 55,
                  right: 0,
                  left: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white,
                      ),
                      child: TextField(
                        controller: _controllerDestino,
                        decoration: InputDecoration(
                          icon: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Icon(Icons.local_taxi, color: Colors.black),
                          ),
                          hintText: "Insira o destino",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
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
                child: Text(_textoBotao,
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes?.cancel();
    _streamSubscriptionRequisicoes = null;
  }

}
