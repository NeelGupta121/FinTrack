import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investments')),
      body: const Center(child: Text('Holdings will appear here')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/investments/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddInvestmentScreen extends StatelessWidget {
  const AddInvestmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Holding')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Symbol / Fund Name')),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(labelText: 'Buy Price (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.pop(), child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
