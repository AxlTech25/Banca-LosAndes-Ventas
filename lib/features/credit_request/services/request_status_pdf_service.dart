import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../models/pipeline_models.dart';

class RequestStatusPdfService {
  const RequestStatusPdfService._();

  static Future<void> shareStatusSheet(SubmittedCreditRequest request) async {
    final doc = pw.Document();
    final updated = request.updatedAt ?? request.createdAt;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Banco Los Andes',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Estado de solicitud de credito',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _row('Expediente', request.expedienteNumber),
              _row('Cliente', request.clientName),
              _row('Documento', maskDocument(request.documentNumber)),
              _row('Monto solicitado', formatCurrency(request.requestedAmount)),
              _row('Plazo', '${request.termMonths} meses'),
              _row('Estado actual', request.status.label),
              if (request.approvedAmount != null)
                _row(
                  'Monto aprobado',
                  formatCurrency(request.approvedAmount!),
                ),
              if (request.rejectionReason != null &&
                  request.rejectionReason!.isNotEmpty)
                _row('Motivo', request.rejectionReason!),
              _row('Actualizado', _formatDate(updated)),
              pw.Spacer(),
              pw.Text(
                'Codigo de seguimiento: ${request.expedienteNumber}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Documento informativo generado desde App Fuerza de Ventas.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${request.expedienteNumber}_estado.pdf',
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
