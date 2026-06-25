import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../models/supervision_models.dart';

class ProductivityPdfService {
  const ProductivityPdfService._();

  static Future<void> shareReport(AgencyProductivityReport report) async {
    final doc = pw.Document();
    final monthLabel = _formatMonth(report.month);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
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
                'Reporte de productividad — $monthLabel',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Asesor',
                  'Codigo',
                  'Enviadas',
                  'Aprobadas',
                  'Desembolsadas',
                  'Monto desembolsado',
                  'Tasa',
                ],
                data: report.rows
                    .map(
                      (row) => [
                        row.advisor.displayName,
                        row.advisor.employeeCode,
                        row.submittedCount.toString(),
                        row.approvedCount.toString(),
                        row.disbursedCount.toString(),
                        formatCurrency(row.disbursedAmount),
                        '${row.conversionPercent}%',
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Totales: ${report.totalSubmitted} enviadas · '
                '${report.totalDisbursed} desembolsadas · '
                '${formatCurrency(report.totalDisbursedAmount)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Documento generado desde App Fuerza de Ventas.',
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
      filename: 'productividad_$monthLabel.pdf',
    );
  }

  static String _formatMonth(DateTime month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${months[month.month - 1]}_${month.year}';
  }
}
