import 'dart:typed_data';
import "dart:convert";
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

final guidEmailMapper = {
  "ranit.saha@ranitdev.onmicrosoft.com": "rsaha043",
  "debayan.mukherjee@ranitdev.onmicrosoft.com": "dmukherjee005",
  "hardik.dalmia@ranitdev.onmicrosoft.com": "hdalmia002",
  "saurabh.kumer@ranitdev.onmicrosoft.com": "skumar466",
};

final Uint8List aesIV =
    Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
final Uint8List aesKey = Uint8List.fromList([
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30,
  0x30
]);

late NfcState _nfcState;

var navigatorKey = GlobalKey<NavigatorState>();

Config config = Config(
  tenant: "ddbaf2cd-efd8-4f1b-8580-cca059c9a6cb",
  clientId: "2f44aedb-6924-4ef4-932b-2f5bddf78dcf",
  scope: "openid email offline_access",
  redirectUri: "msauth://nfc_emulator/M%2BgDaV1h2ms2kbe4tXumTHigw3Q%3D",
  navigatorKey: navigatorKey,
  webUseRedirect: true,
  loader: const Center(child: CircularProgressIndicator()),
);

AadOAuth oauth = AadOAuth(config);

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

  // this will be changed in the NfcHce.stream listen callback
  NfcApduCommand? nfcApduCommand;

  @override
  void initState() {
    super.initState();

    NfcHce.stream.listen((command) {
      setState(() => nfcApduCommand = command);
    });
  }

  dynamic getEncryptedToken() async {
    final isUserLoggedin = await oauth.hasCachedAccountInformation;
    if (!isUserLoggedin) {
      final result = await oauth.login();
      result.fold(
        (failure) => () {
          print(failure.toString());
        },
        (token) => () {
          print('Logged in successfully, your access token: $token');
        },
      );
    }
    String? accessToken = await oauth.getAccessToken();
    JWT decodedToken = JWT.decode(accessToken!);
    String userGuid = guidEmailMapper[decodedToken.payload['unique_name']]!;
    String encryptedString = encryptAES(userGuid);
    return encryptedString;
  }

  String encryptAES(String plainText) {
    final key = encrypt.Key.fromBase64(base64.encode(aesKey));
    final iv = IV.fromBase64(base64.encode(aesIV));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
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
                // Padding(
                //   padding:
                //       const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                //   child: TextField(
                //     enabled: !apduAdded,
                //     decoration: const InputDecoration(
                //       border: OutlineInputBorder(),
                //       hintText: 'Enter to send via NFC',
                //     ),
                //     onChanged: onTypeTextInputField,
                //   ),
                // ),
                SizedBox(
                  height: 100.0,
                  width: 500.0,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (apduAdded == false) {
                        dynamic accessToken = await getEncryptedToken();
                        await NfcHce.addApduResponse(
                            port, utf8.encode(accessToken!));
                      } else {
                        await NfcHce.removeApduResponse(port);
                      }

                      setState(() => apduAdded = !apduAdded);
                    },
                    icon: !apduAdded
                        ? const Icon(
                            Icons.lock_open,
                            size: 40,
                          )
                        : const Icon(
                            Icons.lock,
                            size: 40,
                          ),
                    label: !apduAdded
                        ? const Text(
                            "Unlock",
                            style: TextStyle(fontSize: 20),
                          )
                        : const Text(
                            "Lock",
                            style: TextStyle(fontSize: 20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'Oh no...\nNFC is ${_nfcState.name}',
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Door Unlock using NFC'),
        ),
        body: body,
      ),
    );
  }
}
