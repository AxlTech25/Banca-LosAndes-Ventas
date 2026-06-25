import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/auth_session.dart';
import '../data/credit_pipeline_repository.dart';
import '../models/pipeline_models.dart';
import '../viewmodels/pipeline_view_models.dart';
import 'credit_request_detail_view.dart';
import 'stored_credit_document_gallery.dart';

class DocumentsHubView extends StatefulWidget {
  const DocumentsHubView({super.key, required this.session});

  final AuthSession session;

  @override
  State<DocumentsHubView> createState() => _DocumentsHubViewState();
}

class _DocumentsHubViewState extends State<DocumentsHubView> {
  DocumentsHubViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final viewModel = DocumentsHubViewModel(
      repository: CreditPipelineRepository(
        client: Supabase.instance.client,
        advisorId: widget.session.advisorId,
        preferences: preferences,
      ),
    )..addListener(_onChanged);
    if (!mounted) {
      viewModel.dispose();
      return;
    }
    setState(() => _viewModel = viewModel);
    await viewModel.load();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Documentos de solicitudes'),
      ),
      body: viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: viewModel.documents.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Aun no hay documentos de solicitudes enviadas.',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: viewModel.documents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final document = viewModel.documents[index];
                        return _DocumentListTile(
                          document: document,
                          onOpenRequest: () => CreditRequestDetailView.open(
                            context,
                            session: widget.session,
                            solicitudId: document.solicitudId,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _DocumentListTile extends StatelessWidget {
  const _DocumentListTile({
    required this.document,
    required this.onOpenRequest,
  });

  final StoredCreditDocument document;
  final VoidCallback onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenRequest,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => StoredCreditDocumentGallery.open(
                context,
                documents: [document],
              ),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CreditDocumentThumbnail(url: document.storageUrl),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.typeLabel,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    document.clientName,
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    document.expedienteNumber,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => StoredCreditDocumentGallery.open(
                context,
                documents: [document],
              ),
              icon: const Icon(
                Icons.zoom_in,
                color: AppColors.onSurfaceVariant,
              ),
              tooltip: 'Ampliar documento',
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
