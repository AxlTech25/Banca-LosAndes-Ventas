import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/credit_pipeline_repository.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';

class SolicitudChatView extends StatefulWidget {
  const SolicitudChatView({
    super.key,
    required this.session,
    required this.solicitudId,
    required this.clienteId,
    this.expedienteNumber,
    this.clientName,
  });

  final AuthSession session;
  final String solicitudId;
  final String clienteId;
  final String? expedienteNumber;
  final String? clientName;

  static Future<void> open(
    BuildContext context, {
    required AuthSession session,
    required String solicitudId,
    required String clienteId,
    String? expedienteNumber,
    String? clientName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SolicitudChatView(
          session: session,
          solicitudId: solicitudId,
          clienteId: clienteId,
          expedienteNumber: expedienteNumber,
          clientName: clientName,
        ),
      ),
    );
  }

  @override
  State<SolicitudChatView> createState() => _SolicitudChatViewState();
}

class _SolicitudChatViewState extends State<SolicitudChatView> {
  SolicitudChatViewModel? _viewModel;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final viewModel = SolicitudChatViewModel(
      repository: CreditPipelineRepository(
        client: Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
      solicitudId: widget.solicitudId,
      clienteId: widget.clienteId,
    )..addListener(_onChanged);

    if (!mounted) {
      viewModel.dispose();
      return;
    }

    setState(() => _viewModel = viewModel);
    viewModel.startListening();
    await viewModel.load();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final viewModel = _viewModel;
    if (viewModel == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final ok = await viewModel.send(text);
    if (!mounted) return;
    if (ok) {
      _messageController.clear();
      _scrollToBottom();
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage!)),
      );
    }
  }

  String get _title {
    if (widget.expedienteNumber != null) {
      return widget.expedienteNumber!;
    }
    return 'Chat';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: const TextStyle(fontSize: 16)),
            if (widget.clientName != null)
              Text(
                widget.clientName!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMessageList(viewModel)),
                if (!viewModel.chatNoDisponible) _buildComposer(viewModel),
              ],
            ),
    );
  }

  Widget _buildMessageList(SolicitudChatViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.chatNoDisponible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chat no configurado',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                viewModel.errorMessage ??
                    'Ejecuta la migracion 008_fase4_pagos_firma_chat_buro.sql '
                    'en Supabase.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Inicia la conversacion con el cliente sobre esta solicitud.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.mensajes.length,
      itemBuilder: (context, index) {
        return _MessageBubble(mensaje: viewModel.mensajes[index]);
      },
    );
  }

  Widget _buildComposer(SolicitudChatViewModel viewModel) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLength: 500,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje al cliente...',
                    hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: viewModel.isSending ? null : _send,
                icon: viewModel.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.mensaje});

  final SolicitudMensaje mensaje;

  @override
  Widget build(BuildContext context) {
    final esPropio = mensaje.esPropio;
    final createdAt = mensaje.createdAt;

    return Align(
      alignment: esPropio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: esPropio
              ? AppColors.primaryContainer.withValues(alpha: 0.25)
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esPropio)
              const Text(
                'Cliente',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              mensaje.contenido,
              style: const TextStyle(color: AppColors.onSurface),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(createdAt),
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $h:$m';
  }
}
