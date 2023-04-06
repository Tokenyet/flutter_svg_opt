import 'dart:io';

import 'package:args/args.dart';
import 'package:xml/xml.dart';

const helpCmd = 'help';
const directoryCmd = 'dir';

Future<void> fixSvgFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser.addFlag(helpCmd, abbr: 'h', help: 'Usage help', negatable: false);
  // Make default null to differentiate when it is explicitly set
  parser.addOption(
    directoryCmd,
    abbr: 'd',
    help:
        'Change all svg under specified directory and all sub directorys. (default: assets)',
    defaultsTo: '',
  );
  final ArgResults argResults = parser.parse(arguments);
  // ignore: avoid_print
  print(argResults[helpCmd]);
  if (argResults[helpCmd] == true) {
    stdout.writeln('Fix <defs> on svg for flutter_svg');
    stdout.writeln(parser.usage);
    exit(0);
  }

  if (argResults[directoryCmd] != '') {
    // ignore: avoid_print
    print('process on ${argResults[directoryCmd]}...');
    await processSvgsUnderDir(argResults[directoryCmd]);
    exit(0);
  } else {
    // ignore: avoid_print
    print('process on assets...');
    await processSvgsUnderDir('assets');
    exit(0);
  }
}

Future<void> processSvgsUnderDir(String asset) async {
  final assetFolder = Directory(asset);
  await for (final entity in assetFolder.list(recursive: true)) {
    if (entity is File) {
      if (entity.path.lastIndexOf('.svg') != -1) {
        // ignore: avoid_print
        print('process file: ${entity.path}');
        await processSvg(entity);
      }
    }
  }
}

Future<void> processSvg(File svg) async {
  final rawXml = await svg.readAsString();
  final doc = XmlDocument.parse(rawXml);
  final svgDoc = doc.firstElementChild;

  if (svgDoc == null) {
    return;
  }

  final reordered = svgDoc.childElements.toList();
  bool isDefs(XmlElement e) => e.name.qualified.toLowerCase() == 'defs';
  reordered.sort((a, b) {
    if (isDefs(a)) return -1;
    if (isDefs(b)) return 1;
    return 0;
  });

  final builder = XmlBuilder();
  builder.element(
    'svg',
    attributes: getAttributeMap(svgDoc.attributes),
    nest: () {
      for (final element in reordered) {
        builder.xml(element.outerXml);
      }
    },
  );

  final output = builder.buildDocument().toXmlString(pretty: true);

  await svg.writeAsString(output);
}

Map<String, String> getAttributeMap(Iterable<XmlAttribute> attributes) {
  return Map.fromEntries(
    attributes.map(
      (e) => MapEntry(e.name.qualified, e.value),
    ),
  );
}
