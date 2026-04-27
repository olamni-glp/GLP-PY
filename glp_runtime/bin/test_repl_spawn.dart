// Minimal harness that mimics ReplPlayRunner stdin handling on Windows.
// Args: <suite> <play> [extraFiles...]
// suite: cssg | bonds | bonds12
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final suite = args.isNotEmpty ? args[0] : 'cssg';
  final play = args.length > 1 ? args[1] : '1';
  final dart = r'C:\Users\smbuser\flutter\bin\dart.bat';

  late final List<String> files;
  late final List<String> prefix;
  switch (suite) {
    case 'cssg':
      files = [
        '../programs/typed_book/cssg/typed_social_agent.glp',
        '../programs/typed_book/cssg/typed_ui_mediator.glp',
        '../programs/typed_book/cssg/typed_ui_actors.glp',
        '../programs/typed_book/cssg/play_ui_sim_boot.glp',
      ];
      prefix = [];
      break;
    case 'bonds':
      files = [
        '../programs/typed_book/bonds/agent.glp',
        '../programs/typed_book/bonds/mediator.glp',
        '../programs/typed_book/bonds/actors.glp',
        '../programs/typed_book/bonds/boot.glp',
      ];
      prefix = [':limit 1000000'];
      break;
    case 'bonds12':
      files = [
        '../programs/typed_book/bonds/agent.glp',
        '../programs/typed_book/bonds/mediator.glp',
        '../programs/typed_book/bonds/actors.glp',
        '../programs/typed_book/bonds/play12/alice.glp',
        '../programs/typed_book/bonds/play12/bob.glp',
        '../programs/typed_book/bonds/play12/charlie.glp',
        '../programs/typed_book/bonds/play12/diana.glp',
        '../programs/typed_book/bonds/play12/eve.glp',
        '../programs/typed_book/bonds/play12/frank.glp',
        '../programs/typed_book/bonds/boot.glp',
      ];
      prefix = [':limit 5000000'];
      break;
    default:
      throw 'unknown suite: $suite';
  }

  final p = await Process.start(
    dart,
    ['run', 'bin/glp_repl.dart'],
    workingDirectory: r'D:\BSTDEV\glp\GLP-PY\glp_runtime',
    runInShell: false,
  );
  final cmds = [...files, ':debug', ...prefix, 'fplay$play.', ':quit'].join('\n');
  p.stdin.writeln(cmds);
  await p.stdin.close();
  final out = StringBuffer();
  await Future.wait([
    p.stdout.transform(utf8.decoder).forEach(out.write),
    p.stderr.transform(utf8.decoder).forEach((s) => out.write('STDERR:$s')),
  ]);
  final ec = await p.exitCode;
  print(out);
  print('exit=$ec');
}
