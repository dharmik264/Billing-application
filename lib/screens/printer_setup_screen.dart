import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/printer_service.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  static const double _panelWidth = 360;

  bool _wifiEnabled = false;
  bool _connected = false;
  bool _showDisconnectPrompt = false;
  String _paperSize = '58 mm';

  double _printFontSize = 55.0;

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
      _printFontSize = prefs.getDouble('print_font_size') ?? (_paperSize == '80 mm' ? 55.0 : 16.0);
    });
  }

  Future<void> _initPrinter() async {
    _connected = await PrinterService.instance.isConnected;
    if (_connected) {
      _showDisconnectPrompt = false;
    } else {
      _scanBluetooth();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Connect New Device
              _sectionHeader('CONNECT NEW DEVICE', badgeText: 'BT & LAN Active', isGreenBadge: true),
              const SizedBox(height: 8),
              _buildScanningCard(),
              const SizedBox(height: 10),
              _wifiCard(),

              const SizedBox(height: 20),
              // Section 2: Current Connection
              _sectionHeader('CURRENT CONNECTION', badgeText: 'Status'),
              const SizedBox(height: 8),
              _currentConnectionCard(),
              if (_showDisconnectPrompt && _connected) ...[
                const SizedBox(height: 12),
                _disconnectPrompt(),
              ],

              const SizedBox(height: 20),
              // Section 3: Paper Size
              _sectionHeader('PAPER SIZE', badgeText: 'ESC/POS'),
              const SizedBox(height: 8),
              _paperSizeOptions(),

              const SizedBox(height: 24),
              _saveButton(),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Compatible with Star Micronics, Epson, POS-58, and universal ESC/POS thermal printers.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF71717A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {String? badgeText, bool isGreenBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF71717A),
            letterSpacing: 0.8,
          ),
        ),
        if (badgeText != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGreenBadge) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                badgeText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF71717A),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _goBack,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF111111)),
            ),
          ),
          Text(
            'Printer Setup',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111111),
              letterSpacing: -0.2,
            ),
          ),
          IconButton(
            tooltip: 'Help & Manual',
            icon: const Icon(Icons.help_outline_rounded, size: 20, color: Color(0xFF71717A)),
            onPressed: () {
              _showSnackBar('Ensure Bluetooth or Wi-Fi printer is powered on and in range.');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScanningCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: const Icon(Icons.print_outlined, size: 22, color: Color(0xFF111111)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isScanning ? 'Scanning nearby printers...' : 'Scan Bluetooth Printers',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111111),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF111111),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: _isScanning ? const Color(0xFF111111) : const Color(0xFF71717A),
                          ),
                          onPressed: (_isScanning || _isProcessing) ? null : _scanBluetooth,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Searching for thermal Bluetooth & LAN devices in range',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _devices
                    .map((device) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          title: Text(device.name ?? 'Unknown Device', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF111111))),
                          subtitle: Text(device.address ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF71717A))),
                          trailing: Icon(
                            _connectedDevice?.address == device.address ? Icons.check_circle_rounded : Icons.link_rounded,
                            color: _connectedDevice?.address == device.address ? const Color(0xFF10B981) : const Color(0xFF111111),
                          ),
                          onTap: () => _connectDevice(device),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF4F4F5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF71717A)),
                    const SizedBox(width: 6),
                    Text(
                      'Hold printer close for Bluetooth discovery',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF71717A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'POS-ESC/POS',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF52525B), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: const Icon(Icons.wifi_rounded, size: 20, color: Color(0xFF111111)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wi-Fi / Ethernet Network',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connect via IP Address & standard Port 9100',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
                  ),
                ],
              ),
            ),
            _switch(_wifiEnabled, activeColor: const Color(0xFF111111)),
          ],
        ),
      ),
    );
  }

  Widget _currentConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F4F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFF71717A)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _connected
                            ? (_wifiEnabled ? 'Network Printer' : (_connectedDevice?.name ?? 'Bluetooth Printer'))
                            : 'No printer connected',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF27272A),
                        ),
                      ),
                      Text(
                        _connected ? 'Active device ready for billing' : 'Select a device from discovered list to bind',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF71717A)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _connected ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _connected ? 'Connected' : 'Idle',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF52525B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF4F4F5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _showIpDialog,
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Color(0xFF111111)),
                      const SizedBox(width: 4),
                      Text(
                        'Add Printer by IP',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showSnackBar('Tip: Ensure Bluetooth is turned ON and printer paper roll is loaded.');
                  },
                  child: Text(
                    'Troubleshoot',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A), decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disconnectPrompt() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disconnect Printer?',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
          ),
          const SizedBox(height: 4),
          Text(
            'This will disconnect current printer connection.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDisconnectPrompt = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                  onPressed: _disconnect,
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paperSizeOptions() {
    return Row(
      children: [
        Expanded(
          child: _paperOptionCard(
            size: '58 mm',
            description: 'Standard portable',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _paperOptionCard(
            size: '80 mm',
            description: 'Desktop receipt',
          ),
        ),
      ],
    );
  }

  Widget _paperOptionCard({
    required String size,
    required String description,
  }) {
    final selected = _paperSize == size;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isProcessing ? null : () => setState(() => _paperSize = size),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF111111) : const Color(0xFFE5E5E5),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: size == '58 mm' ? 56 : 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? const Color(0xFF111111) : const Color(0xFFD4D4D8), width: selected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: size == '58 mm' ? 24 : 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    size.replaceAll(' ', ''),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              size,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
            ),
            const SizedBox(height: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF111111) : Colors.white,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: const Color(0xFFD4D4D8)),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isProcessing
            ? null
            : () async {
                setState(() => _isProcessing = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('paper_size', _paperSize);
                  await prefs.setDouble('print_font_size', _printFontSize);
                  await PrinterService.instance.initPreferences();
                  _showSnackBar('Printer & Font Settings saved!');
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Save Printer & Font Settings',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _switch(bool value, {required Color activeColor}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? activeColor : const Color(0xFFE4E4E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Future<void> _scanBluetooth() async {
    setState(() {
      _isScanning = true;
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
      } else if (!_connected) {
        // Auto-connect to last saved printer MAC address if available in scanned list
        final prefs = await SharedPreferences.getInstance();
        final lastMac = prefs.getString('printer_mac');
        if (lastMac != null && lastMac.isNotEmpty) {
          final target = devices.where((d) => d.address == lastMac).firstOrNull;
          if (target != null) {
            _connectDevice(target);
          }
        }
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
                backgroundColor: const Color(0xFF111111), foregroundColor: Colors.white),
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

