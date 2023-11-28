import 'dart:typed_data';
import "dart:convert";
import 'package:flutter/material.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

late NfcState _nfcState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _nfcState = await NfcHce.checkDeviceNfcState();

  if (_nfcState == NfcState.enabled) {
    await NfcHce.init(
      // AID that match at least one aid-filter in apduservice.xml
      // In my case it is A000DADADADADA.
      aid: Uint8List.fromList([0xA0, 0x00, 0xDA, 0xDA, 0xDA, 0xDA, 0xDA]),
      // next parameter determines whether APDU responses from the ports
      // on which the connection occurred will be deleted.
      // If `true`, responses will be deleted, otherwise won't.
      permanentApduResponses: true,
      // next parameter determines whether APDU commands received on ports
      // to which there are no responses will be added to the stream.
      // If `true`, command won't be added, otherwise will.
      listenOnlyConfiguredPorts: false,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool apduAdded = false;

  // change port here
  final port = 0;
  // change data to transmit here
  final data = [5, 1, 5, 3, 9, 5, 7, 7, 7, 2];

  // this will be changed in the NfcHce.stream listen callback
  NfcApduCommand? nfcApduCommand;
  var typedData = "";

  @override
  void initState() {
    super.initState();

    NfcHce.stream.listen((command) {
      setState(() => nfcApduCommand = command);
    });
  }

  void onTypeTextInputField(text) {
    setState(() {
      typedData = text.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _nfcState == NfcState.enabled
        ? Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'NFC State is ${_nfcState.name}',
                  style: const TextStyle(fontSize: 20),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter to send via NFC',
                    ),
                    onChanged: onTypeTextInputField,
                  ),
                ),
                SizedBox(
                  height: 200,
                  width: 300,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        apduAdded ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                    onPressed: () async {
                      if (apduAdded == false) {
                        await NfcHce.addApduResponse(
                            port, utf8.encode(typedData));
                      } else {
                        await NfcHce.removeApduResponse(port);
                      }

                      setState(() => apduAdded = !apduAdded);
                    },
                    child: FittedBox(
                      child: Text(
                        apduAdded
                            ? 'remove\n$data\nfrom\nport $port'
                            : 'add\n$data\nto\nport $port',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          color: apduAdded ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                if (nfcApduCommand != null)
                  Text(
                    'You listened to the stream and received the '
                    'following command on the port ${nfcApduCommand!.port}:\n'
                    '${nfcApduCommand!.command}\n'
                    'with additional data ${nfcApduCommand!.data}',
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          )
        : Center(
            child: Text(
              'Oh no...\nNFC is ${_nfcState.name}',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NFC HCE example app'),
        ),
        body: body,
      ),
    );
  }
}
