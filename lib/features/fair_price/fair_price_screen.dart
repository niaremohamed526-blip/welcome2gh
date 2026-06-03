import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';

class FairPriceScreen extends StatefulWidget {
  const FairPriceScreen({super.key});

  @override
  State<FairPriceScreen> createState() => _FairPriceScreenState();
}

class _FairPriceScreenState extends State<FairPriceScreen> {
  List<FairPrice> _prices = [];
  bool _loading = true;
  String _filter = 'All';
  final _filters = ['All', 'taxi', 'trotro', 'restaurant', 'market_item'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.instance.getFairPrices(serviceType: _filter == 'All' ? null : _filter);
      if (mounted) setState(() { _prices = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('FAIR PRICES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.yellow),
            onPressed: () async {
              final ok = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.navyCard,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => const _ReportPriceSheet(),
              );
              if (ok == true) _load();
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((f) {
                final active = f == _filter;
                return GestureDetector(
                  onTap: () { setState(() => _filter = f); _load(); },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                    child: Text(f.toUpperCase(), style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
              : _prices.isEmpty
                  ? Center(child: Text('No prices reported yet.', style: TextStyle(color: AppColors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _prices.length,
                      itemBuilder: (_, i) {
                        final p = _prices[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                              child: Icon(_iconFor(p.serviceType), color: AppColors.yellow, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.itemName ?? '${p.routeFrom ?? ''} → ${p.routeTo ?? ''}', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(p.serviceType.toUpperCase(), style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('GHS ${p.amountGhs.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w800, fontSize: 16)),
                              if (p.verified) const Padding(padding: EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.verified_rounded, color: AppColors.green, size: 12), SizedBox(width: 3), Text('VERIFIED', style: TextStyle(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w700))])),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'taxi': return Icons.local_taxi_rounded;
      case 'trotro': return Icons.directions_bus_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'market_item': return Icons.shopping_bag_rounded;
      default: return Icons.attach_money_rounded;
    }
  }
}

class _ReportPriceSheet extends StatefulWidget {
  const _ReportPriceSheet();

  @override
  State<_ReportPriceSheet> createState() => _ReportPriceSheetState();
}

class _ReportPriceSheetState extends State<_ReportPriceSheet> {
  String _service = 'taxi';
  final _item = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _item.dispose();
    _from.dispose();
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount'), backgroundColor: AppColors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.reportFairPrice(
        serviceType: _service,
        itemName: _item.text.trim().isEmpty ? null : _item.text.trim(),
        routeFrom: _from.text.trim().isEmpty ? null : _from.text.trim(),
        routeTo: _to.text.trim().isEmpty ? null : _to.text.trim(),
        amountGhs: amt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price reported! Thanks for helping.'), backgroundColor: AppColors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRoute = _service == 'taxi' || _service == 'trotro';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('REPORT A PRICE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text('Help others avoid scams', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Row(children: ['taxi', 'trotro', 'restaurant', 'market_item'].map((s) {
            final active = s == _service;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _service = s),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navy, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                child: Center(child: Text(s.toUpperCase(), style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700))),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
          if (isRoute) ...[
            Row(children: [
              Expanded(child: TextField(controller: _from, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'From'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _to, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'To'))),
            ]),
          ] else
            TextField(controller: _item, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Item name (e.g. plate of jollof)')),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(prefixText: 'GHS ', prefixStyle: TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700), hintText: 'Amount'),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                : const Text('SUBMIT REPORT'),
          )),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
