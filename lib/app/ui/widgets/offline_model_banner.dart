import 'package:flutter/material.dart';
import 'package:sub3/app/services/gguf_model_service.dart';

class OfflineModelBanner extends StatelessWidget {
  const OfflineModelBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = GgufModelService.instance;
    if (!GgufModelService.isOnDeviceSupported) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final downloading = svc.state == GgufRuntimeState.downloading;
        final missing = svc.state == GgufRuntimeState.missing;
        final ready = svc.state == GgufRuntimeState.ready;
        final loaded = svc.state == GgufRuntimeState.loaded;
        final loading = svc.state == GgufRuntimeState.loading;
        final errored = svc.state == GgufRuntimeState.error;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      loaded
                          ? Icons.offline_pin
                          : Icons.memory_outlined,
                      color: loaded ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        GgufModelService.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      loaded ? 'Offline' : 'Android',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  svc.statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: errored ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
                if (downloading) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: svc.bytesTotal == null ? null : svc.progress,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    svc.bytesTotal == null
                        ? GgufModelService.formatBytes(svc.bytesReceived)
                        : '${GgufModelService.formatBytes(svc.bytesReceived)} / ${GgufModelService.formatBytes(svc.bytesTotal!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (missing || errored)
                      FilledButton.icon(
                        onPressed: svc.isBusy
                            ? null
                            : () => _run(context, () => svc.download()),
                        icon: const Icon(Icons.download),
                        label: const Text('Baixar (~462 MB)'),
                      ),
                    if (downloading)
                      OutlinedButton(
                        onPressed: svc.cancelDownload,
                        child: const Text('Cancelar'),
                      ),
                    if (ready)
                      FilledButton.icon(
                        onPressed: svc.isBusy
                            ? null
                            : () => _run(context, () => svc.ensureLoaded()),
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text('Carregar modelo'),
                      ),
                    if (loaded)
                      OutlinedButton.icon(
                        onPressed: () => svc.unload(),
                        icon: const Icon(Icons.eject_outlined),
                        label: const Text('Descarregar da RAM'),
                      ),
                    if (ready || loaded || errored)
                      TextButton(
                        onPressed: svc.isBusy
                            ? null
                            : () => _run(
                                  context,
                                  () => svc.download(force: true),
                                ),
                        child: const Text('Baixar de novo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
