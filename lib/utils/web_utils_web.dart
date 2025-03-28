import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get window;

void addUnloadListener(Function callback) {
  final jsCallback = (JSObject event) async {
    await callback();
  }.toJS;

  window.callMethod('addEventListener'.toJS, 'unload'.toJS, jsCallback);
}