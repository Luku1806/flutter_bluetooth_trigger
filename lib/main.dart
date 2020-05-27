// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote trigger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection connection;
  BluetoothDevice _device;
  List<BluetoothDevice> _devicesList = [];
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  bool _connecting = false;

  bool get isConnected => connection?.isConnected ?? false;

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    enableBluetooth();

    FlutterBluetoothSerial.instance.onStateChanged().listen(
      (BluetoothState state) {
        setState(() {
          _bluetoothState = state;
          getPairedDevices();
        });
      },
    );
  }

  @override
  void dispose() {
    connection.dispose();
    connection = null;
    super.dispose();
  }

  Future<void> enableBluetooth() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Remote trigger"),
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.settings_bluetooth,
                color: Colors.white,
              ),
              label: Text(
                "Settings",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              onPressed: FlutterBluetoothSerial.instance.openSettings,
            ),
          ],
        ),
        body: Container(
          child: RefreshIndicator(
            onRefresh: () async {
              await getPairedDevices().then((_) {
                _showSnackBar('Device list refreshed');
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Visibility(
                    visible: _connecting,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Enable Bluetooth',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Switch(
                          value: _bluetoothState.isEnabled,
                          onChanged: (value) async {
                            if (value) {
                              await FlutterBluetoothSerial.instance
                                  .requestEnable();
                            } else {
                              await FlutterBluetoothSerial.instance
                                  .requestDisable();
                            }

                            await getPairedDevices();

                            setState(() {
                              if (isConnected) {
                                _disconnect();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton(
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            RaisedButton(
                              onPressed: isConnected ? _disconnect : _connect,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              color: Colors.blue,
                              child: Text(
                                isConnected ? 'Disconnect' : 'Connect',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              width: 2,
                              color: isConnected ? Colors.green : Colors.black,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    isConnected
                                        ? _device.name
                                        : "Not connected",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: isConnected
                                      ? () => _sendMessageToBluetooth("TRIGGER")
                                      : null,
                                  child: Text(
                                    "BOOM",
                                    style: TextStyle(
                                      color: isConnected
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "NOTE: If you cannot find the device in the list, please pair the device by going to the bluetooth settings",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  void _connect() async {
    setState(() {
      _connecting = true;
    });

    if (_device == null) {
      _showSnackBar('No device selected');
    } else {
      if (connection != null ? !connection.isConnected : true) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          connection = _connection;

          connection.input.listen(null).onDone(() {
            if (this.mounted) {
              setState(() {});
            }
          });

          _showSnackBar('Device connected');
        }).catchError((error) {
          _showSnackBar('Cannot connect');
          print('Cannot connect, exception occurred');
          print(error);
        });
      }
    }

    setState(() {
      _connecting = false;
    });
  }

  void _disconnect() async {
    await connection?.close();
    setState(() {
      connection = null;
    });
    _showSnackBar('Device disconnected');
  }

  void _sendMessageToBluetooth(String message) async {
    connection.output.add(utf8.encode(message + "\r\n"));
    await connection.output.allSent;
    _showSnackBar('Sent message to device');
  }

  Future _showSnackBar(
    String message, [
    Duration duration = const Duration(seconds: 3),
  ]) async {
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}
