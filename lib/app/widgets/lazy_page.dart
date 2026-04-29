import 'package:flutter/material.dart';

class LazyPage extends StatefulWidget {
  const LazyPage({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  @override
  State<LazyPage> createState() => _LazyPageState();
}

class _LazyPageState extends State<LazyPage> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _LazyLoadError(error: snapshot.error!);
          }
          return widget.builder(context);
        }
        return const _LazyLoadSpinner();
      },
    );
  }
}

class _LazyLoadSpinner extends StatelessWidget {
  const _LazyLoadSpinner();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LazyLoadError extends StatelessWidget {
  const _LazyLoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('页面加载失败', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
