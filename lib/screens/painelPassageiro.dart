import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uber_clone/models/destino.dart';
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

  CameraPosition _posicaoCamera = const CameraPosition(
    target: LatLng(-2.911022, -41.753691),
    zoom: 18,
  );

  final List<String> _itensMenu = ["Configurações", "Deslogar"];
  final Set<Marker> _marcadores = {};

  void _exibirPassageiro(Position local) async {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final BitmapDescriptor icone = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      "assets/images/passageiro.png",
    );

    final Marker marcadorPassageiro = Marker(
      markerId: const MarkerId("marcador-passageiro"),
      position: LatLng(local.latitude, local.longitude),
      infoWindow: const InfoWindow(title: "Meu local"),
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
      var locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null) {
        _exibirPassageiro(position);
        setState(() {
          _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18,
          );
          _movimentarCamera(_posicaoCamera);
        });
      } else {
        print("Nenhuma posição conhecida encontrada.");
      }
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

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _exibirPassageiro(position);
        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        );
        _movimentarCamera(_posicaoCamera);
      });
    });
  }

  Future<void> _chamarUber() async {
    final String enderecoDestino = _controllerDestino.text;

    if (enderecoDestino.isNotEmpty) {
      List<Location> listaEnderecos = await locationFromAddress(enderecoDestino);

      if (listaEnderecos.isNotEmpty) {
        final Location location = listaEnderecos[0];
        final double latitude = location.latitude;
        final double longitude = location.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

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
                    child: const Text("Cancelar", style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Salvar requisicao
                      _salvarRequisicao( destino );
                      Navigator.pop(context);
                    },
                    child: const Text("Confirmar", style: TextStyle(color: Colors.green)),
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
    // Obtém os dados do usuário logado
    Usuario? passageiro = await UsuarioFirebase.getDadosUsuarioLogado();

    // Verifica se o passageiro está disponível
    if (passageiro == null) {
      print("Usuário não está logado.");
      return; // Saia da função se o usuário não estiver logado
    }

    // Cria uma nova requisição
    Requisicao requisicao = Requisicao();
    requisicao.destino = destino; // O destino deve ser não nulo aqui
    requisicao.passageiro = passageiro; // O passageiro não pode ser nulo
    requisicao.status = StatusRequisicao.AGUARDANDO; // Certifique-se que este valor é válido

    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // Adiciona a requisição ao Firestore
      await db.collection("requisicoes").add(requisicao.toMap());
      print("Requisição salva com sucesso.");
    } catch (e) {
      print("Erro ao salvar a requisição: $e"); // Tratamento de erro
    }
  }


  @override
  void initState() {
    super.initState();
    _recuperaLocalizacao();
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
          ),
          Positioned(
            right: 0,
            left: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: _chamarUber,
                child: const Text("Chamar Uber", style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}