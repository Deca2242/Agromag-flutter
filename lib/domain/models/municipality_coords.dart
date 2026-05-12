import 'municipality.dart';

typedef MunicipalityCoords = ({double lat, double lon});

/// Coordenadas geográficas de cada municipio del Magdalena.
/// Espejo de los valores en `Municipality.java` del backend.
const Map<Municipality, MunicipalityCoords> _kCoords = {
  Municipality.SANTA_MARTA: (lat: 11.2408, lon: -74.1992),
  Municipality.CIENAGA: (lat: 11.0069, lon: -74.2478),
  Municipality.FUNDACION: (lat: 10.5172, lon: -74.1922),
  Municipality.ZONA_BANANERA: (lat: 10.7617, lon: -74.1556),
  Municipality.ARACATACA: (lat: 10.5911, lon: -74.1850),
  Municipality.EL_RETEN: (lat: 10.6106, lon: -74.2683),
  Municipality.PUEBLOVIEJO: (lat: 10.9825, lon: -74.3103),
  Municipality.PIVIJAY: (lat: 10.4500, lon: -74.7500),
  Municipality.PLATO: (lat: 9.7925, lon: -74.7814),
  Municipality.EL_BANCO: (lat: 9.0003, lon: -73.9753),
  Municipality.ALGARROBO: (lat: 10.1667, lon: -74.0833),
  Municipality.ARIGUANI: (lat: 9.8500, lon: -74.0833),
  Municipality.CERRO_SAN_ANTONIO: (lat: 10.3333, lon: -74.8667),
  Municipality.CHIBOLO: (lat: 10.0167, lon: -74.6000),
  Municipality.CONCORDIA: (lat: 10.2833, lon: -74.6167),
  Municipality.EL_PINON: (lat: 10.3833, lon: -74.9500),
  Municipality.GUAMAL: (lat: 9.1500, lon: -74.2167),
  Municipality.NUEVA_GRANADA: (lat: 10.0333, lon: -74.3833),
  Municipality.PEDRAZA: (lat: 10.1833, lon: -74.9167),
  Municipality.PIJINO_DEL_CARMEN: (lat: 9.3333, lon: -74.4500),
  Municipality.REMOLINO: (lat: 10.6500, lon: -74.7167),
  Municipality.SABANAS_DE_SAN_ANGEL: (lat: 9.9333, lon: -74.2167),
  Municipality.SALAMINA: (lat: 10.4833, lon: -74.8000),
  Municipality.SAN_SEBASTIAN: (lat: 9.2333, lon: -74.3833),
  Municipality.SAN_ZENON: (lat: 9.2500, lon: -74.5000),
  Municipality.SANTA_ANA: (lat: 9.3167, lon: -74.5667),
  Municipality.SANTA_BARBARA: (lat: 9.4333, lon: -74.7000),
  Municipality.SITIONUEVO: (lat: 10.7833, lon: -74.8667),
  Municipality.TENERIFE: (lat: 10.5667, lon: -74.8500),
  Municipality.ZAPAYAN: (lat: 10.2167, lon: -74.8500),
};

/// Devuelve las coordenadas del municipio dado.
MunicipalityCoords coordsOf(Municipality municipality) {
  return _kCoords[municipality] ??
      (lat: 11.2408, lon: -74.1992); // fallback: Santa Marta
}
