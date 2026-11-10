/// El RUC que trae fijo esta instalación, y que no se puede cambiar en la app.
///
/// Se inyecta al compilar desde `config_privada.json`, que Git ignora: este
/// repositorio es público y un RUC que empieza con 10 lleva adentro el DNI de
/// su dueño. Sin ese archivo queda vacío y el campo se llena a mano.
const String kRucFijo = String.fromEnvironment('RUC_FIJO');
