import 'dart:html' as html;

void addUnloadListener(Function callback) {
  html.window.addEventListener('unload', (event) async {
    await callback();
  });
}
