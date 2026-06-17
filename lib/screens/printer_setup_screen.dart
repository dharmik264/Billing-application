import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/printer_service.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const Color _danger = Color(0xFFDC2626);
  static const double _panelWidth = 360;

  bool _wifiEnabled = false;
  bool _connected = false;
  bool _showDisconnectPrompt = false;
  String _paperSize = '58 mm';

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initPrinter();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _paperSize = prefs.getString('paper_size') ?? '58 mm';
      _wifiEnabled = prefs.getBool('is_network_printer') ?? false;
    });
  }

  Future<void> _initPrinter() async {
    _connected = await PrinterService.instance.isConnected;
    if (_connected) {
      _showDisconnectPrompt = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(_panelWidth, constraints.maxWidth);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(width: width, child: _buildPanel()),
                  ),
                );
              },
            ),
            if (_isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.1),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _label('Connect New Device'),
                const SizedBox(height: 8),
                _scanBluetoothButton(),
                const SizedBox(height: 8),
                _wifiCard(),
                const SizedBox(height: 16),
                _label('Current Connection'),
                const SizedBox(height: 8),
                _currentConnectionCard(),
                if (_showDisconnectPrompt && _connected) ...[
                  const SizedBox(height: 16),
                  _disconnectPrompt(),
                ],
                const SizedBox(height: 16),
                _label('Paper Size'),
                const SizedBox(height: 8),
                _paperSizeOptions(),
                const SizedBox(height: 16),
                _saveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _goBack,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.arrow_back, size: 19, color: Color(0xFF555555)),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Printer Setup',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanBluetoothButton() {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (_isScanning || _isProcessing) ? null : _scanBluetooth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.bluetooth,
                          size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isScanning ? 'Scanning...' : 'Scan Bluetooth',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Find nearby wireless printers',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.search, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
        if (_devices.isNotEmpty && !_connected) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _softBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _devices
                  .map((device) => ListTile(
                        title: Text(device.name ?? 'Unknown'),
                        subtitle: Text(device.address ?? ''),
                        trailing: const Icon(Icons.link, color: _primary),
                        onTap: () => _connectDevice(device),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _wifiCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isProcessing
          ? null
          : () {
              if (!_wifiEnabled) {
                _showIpDialog();
              } else {
                setState(() => _wifiEnabled = false);
              }
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _softBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _panelBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi, size: 18, color: Color(0xFF555555)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WiFi / Network',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Connect via IP Address',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            _switch(_wifiEnabled, activeColor: _primary),
          ],
        ),
      ),
    );
  }

  Widget _currentConnectionCard() {
    if (!_connected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _softBorder, width: 0.5),
        ),
        child: const Text(
          'No printer connected',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print, size: 20, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        Text(
                          _wifiEnabled
                              ? 'Network Printer'
                              : (_connectedDevice?.name ?? 'Bluetooth Printer'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                        _statusBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _wifiEnabled
                          ? 'WiFi \u00B7 Port 9100'
                          : 'Bluetooth \u00B7 MAC: ${_connectedDevice?.address ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _testPrintButton(),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isProcessing
                    ? null
                    : () => setState(() => _showDisconnectPrompt = true),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(Icons.link_off, size: 18, color: _danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Connected',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF065F46),
        ),
      ),
    );
  }

  Widget _testPrintButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _isProcessing
          ? null
          : () async {
              _showSnackBar('Sending test print...');
              await PrinterService.instance.printTest();
            },
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _softBorder, width: 0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: _textSecondary),
            SizedBox(width: 6),
            Text(
              'Test Print',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disconnectPrompt() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disconnect Printer?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _wifiEnabled
                ? 'This will disconnect the network printer. You will not be able to print until reconnected.'
                : 'This will disconnect ${_connectedDevice?.name ?? 'the printer'}. You will not be able to print until reconnected.',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _promptButton(
                  'Cancel',
                  Colors.white,
                  _textSecondary,
                  () => setState(() => _showDisconnectPrompt = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _promptButton(
                  'Disconnect',
                  _danger,
                  Colors.white,
                  _disconnect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promptButton(
    String label,
    Color background,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _paperSizeOptions() {
    return Row(
      children: [
        Expanded(
          child: _paperOption(
            size: '58 mm',
            description: 'Standard portable thermal',
            paperWidth: 36,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _paperOption(
            size: '80 mm',
            description: 'Desktop receipt printers',
            paperWidth: 46,
          ),
        ),
      ],
    );
  }

  Widget _paperOption({
    required String size,
    required String description,
    required double paperWidth,
  }) {
    final selected = _paperSize == size;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isProcessing ? null : () => setState(() => _paperSize = size),
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primary : _softBorder,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: paperWidth,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : _panelBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Text(
                size.replaceAll(' ', ''),
                style: const TextStyle(fontSize: 9, color: _mutedColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              size,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? const Color(0xFF1E40AF) : _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? const Color(0xFF3B82F6) : _textSecondary,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 11, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isProcessing
            ? null
            : () async {
                setState(() => _isProcessing = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('paper_size', _paperSize);
                  await PrinterService.instance.initPreferences();
                  _showSnackBar('Printer settings saved');
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text(
                'Save Printer Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  Widget _switch(bool value, {required Color activeColor}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? activeColor : const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _label(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _scanBluetooth() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      final devices = await PrinterService.instance.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
      if (devices.isEmpty) {
        _showSnackBar(
            'No bonded devices found. Pair a printer in Android settings first.');
      }
    } catch (e) {
      _showSnackBar('Error scanning: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showIpDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Printer IP'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'e.g. 192.168.1.100',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.isEmpty) return;

              setState(() => _isProcessing = true);
              try {
                _showSnackBar('Connecting to ${controller.text}...');
                final success = await PrinterService.instance
                    .connectNetwork(controller.text);
                if (!mounted) return;

                if (success) {
                  setState(() {
                    _wifiEnabled = true;
                    _connected = true;
                    _connectedDevice = null;
                  });
                  _showSnackBar('Connected to network printer');
                } else {
                  _showSnackBar('Failed to connect. Check IP and network.');
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    setState(() => _isProcessing = true);
    try {
      _showSnackBar('Connecting to ${device.name}...');
      final success = await PrinterService.instance.connect(device);
      if (!mounted) return;

      if (success) {
        setState(() {
          _connectedDevice = device;
          _connected = true;
          _devices = [];
        });
        _showSnackBar('Connected successfully');
      } else {
        _showSnackBar('Failed to connect');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isProcessing = true);
    try {
      await PrinterService.instance.disconnect();
      if (!mounted) return;
      setState(() {
        _connected = false;
        _connectedDevice = null;
        _wifiEnabled = false;
        _showDisconnectPrompt = false;
      });
      _showSnackBar('Printer disconnected');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _showSnackBar('Back pressed');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

const Color _mutedColor = Color(0xFFAAAAAA);
