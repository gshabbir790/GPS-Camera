import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/stamp_data.dart';
import '../services/support_service.dart';

/// ڈویلپر سے رابطہ / فیڈ بیک (چیٹ کی طرح)
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _input = TextEditingController();
  final _contact = TextEditingController();
  final _scroll = ScrollController();
  List<SupportMsg> _msgs = [];
  bool _loading = true, _failed = false, _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SupportService.getContact().then((v) {
      if (mounted) _contact.text = v;
    });
    _load(first: true);
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _contact.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    final list = await SupportService.fetch();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list == null) {
        _failed = true;
      } else {
        _failed = false;
        final grew = list.length != _msgs.length;
        _msgs = list;
        if (grew || first) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
        }
      }
    });
    if (list != null) SupportService.markRead();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await SupportService.saveContact(_contact.text);
    final err = await SupportService.send(text, _contact.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err == null) {
      _input.clear();
      _load(first: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('Could not send: $err', 'پیغام نہیں جا سکا: $err'))));
    }
  }

  Future<void> _test() async {
    final r = await SupportService.test();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('Server connection', 'سرور سے رابطہ')),
        content: Text(r),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  String _time(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    return '${StampData.p2(l.day)}/${StampData.p2(l.month)} ${StampData.clock(l)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('Contact developer', 'ڈویلپر سے رابطہ')),
        actions: [
          IconButton(
              tooltip: S.t('Connection test', 'رابطے کی جانچ'),
              icon: const Icon(Icons.network_check),
              onPressed: _test),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFFFF4CC),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            S.t('Write your problem, question or suggestion. The developer will reply here.',
                'اپنا مسئلہ، سوال یا تجویز لکھیں۔ ڈویلپر کا جواب یہیں آئے گا۔'),
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_failed && _msgs.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          S.t('Could not reach the server. Check your internet.',
                              'سرور سے رابطہ نہیں ہو سکا۔ انٹرنیٹ چیک کریں۔'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (context, i) {
                        final m = _msgs[i];
                        final mine = m.from == 'user';
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: mine ? const Color(0xFFFFE08A) : const Color(0xFFE8EAF2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(S.t('Developer', 'ڈویلپر'),
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold)),
                                SelectableText(m.text),
                                const SizedBox(height: 2),
                                Text(_time(m.at),
                                    style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _contact,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  hintText: S.t('Your name / WhatsApp (optional)', 'آپ کا نام / واٹس ایپ (اختیاری)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: S.t('Type your message...', 'اپنا پیغام لکھیں...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _sending
                    ? const SizedBox(
                        width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
