// Source of web/drift_worker.js. Compile it from the resolved packages so the worker always matches
// web/sqlite3.wasm (see README → Web):
//   dart compile js -O4 --no-source-maps tool/drift_worker.dart -o web/drift_worker.js && rm web/drift_worker.js.deps
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
