import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants/strings_ar.dart';
import '../models/bill.dart';

class PdfService {
  pw.Font? _regular;
  pw.Font? _bold;

  bool _isValidTtf(ByteData data) {
    if (data.lengthInBytes < 4) return false;
    final b0 = data.getUint8(0);
    final b1 = data.getUint8(1);
    final b2 = data.getUint8(2);
    final b3 = data.getUint8(3);
    // TrueType outline fonts start with 0x00010000
    if (b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00) return true;
    // OpenType with CFF outlines: "OTTO"
    if (b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F) return true;
    return false;
  }

  Future<pw.Font> _loadBundledFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    if (!_isValidTtf(data)) {
      throw const FormatException('Invalid TTF font asset');
    }
    return pw.Font.ttf(data);
  }

  Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;

    try {
      _regular = await _loadBundledFont('assets/fonts/Cairo-Regular.ttf');
      _bold = await _loadBundledFont('assets/fonts/Cairo-Bold.ttf');
    } catch (_) {
      // Bundled fonts missing or corrupt — download from Google Fonts
      _regular = await PdfGoogleFonts.cairoRegular();
      _bold = await PdfGoogleFonts.cairoBold();
    }
  }

  Future<void> printBill(Bill bill) async {
    final doc = await _buildDocument(bill);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<pw.Document> buildDocumentForFormat(Bill bill) async {
    return _buildDocument(bill);
  }

  Future<void> shareBill(Bill bill) async {
    final doc = await _buildDocument(bill);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'bill_${bill.billNumber}.pdf',
    );
  }

  Future<pw.Document> _buildDocument(Bill bill) async {
    await _ensureFonts();
    final arabicRegular = _regular!;
    final arabicBold = _bold!;

    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final numberFormat = NumberFormat('#,##0.##', 'ar');
    final currency = bill.currencyLabel;

    final baseStyle = pw.TextStyle(font: arabicRegular);
    final boldStyle = pw.TextStyle(font: arabicBold, fontWeight: pw.FontWeight.bold);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: arabicRegular, bold: arabicBold),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      StringsAr.factoryName,
                      style: boldStyle.copyWith(fontSize: 22),
                    ),
                    if (StringsAr.factoryPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${StringsAr.phone}: ${StringsAr.factoryPhone}',
                        style: baseStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${StringsAr.billNumber}: #${bill.billNumber}',
                    style: baseStyle,
                  ),
                  pw.Text(
                    '${StringsAr.date}: ${dateFormat.format(bill.createdAt)}',
                    style: baseStyle,
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${StringsAr.customerName}: ${bill.customerName ?? ''}',
                style: baseStyle,
              ),
              if (bill.customerPhone?.isNotEmpty == true)
                pw.Text(
                  '${StringsAr.phone}: ${bill.customerPhone}',
                  style: baseStyle,
                ),
              if (bill.customerAddress?.isNotEmpty == true)
                pw.Text(
                  '${StringsAr.address}: ${bill.customerAddress}',
                  style: baseStyle,
                ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  StringsAr.itemName,
                  StringsAr.quantity,
                  StringsAr.unitPrice,
                  StringsAr.total,
                ],
                data: bill.items
                    .map(
                      (item) => [
                        item.itemName,
                        numberFormat.format(item.quantity),
                        '${numberFormat.format(item.unitSellPrice)} $currency',
                        '${numberFormat.format(item.totalSell)} $currency',
                      ],
                    )
                    .toList(),
                headerStyle: boldStyle,
                cellStyle: baseStyle,
                headerAlignment: pw.Alignment.centerRight,
                cellAlignment: pw.Alignment.centerRight,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 32,
              ),
              pw.SizedBox(height: 16),
              if (bill.discount > 0) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '${StringsAr.subtotal}: ${numberFormat.format(bill.subtotal)} $currency',
                    style: baseStyle.copyWith(fontSize: 14),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '${StringsAr.discount}: -${numberFormat.format(bill.discount)} $currency',
                    style: baseStyle.copyWith(fontSize: 14),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  '${StringsAr.total}: ${numberFormat.format(bill.total)} $currency',
                  style: boldStyle.copyWith(fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  '${StringsAr.amountPaid}: ${numberFormat.format(bill.amountPaid)} $currency',
                  style: baseStyle.copyWith(fontSize: 13),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  '${StringsAr.amountRemaining}: ${numberFormat.format(bill.amountRemaining)} $currency',
                  style: boldStyle.copyWith(fontSize: 13),
                ),
              ),
              if (bill.payments.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  StringsAr.billPayments,
                  style: boldStyle.copyWith(fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: [
                    StringsAr.paymentDate,
                    StringsAr.amount,
                    StringsAr.notes,
                  ],
                  data: (List<BillPayment>.from(bill.payments)
                        ..sort(
                          (a, b) => a.paymentDate.compareTo(b.paymentDate),
                        ))
                      .map(
                        (payment) => [
                          dateFormat.format(payment.paymentDate),
                          '${numberFormat.format(payment.amount)} $currency',
                          payment.notes ?? '—',
                        ],
                      )
                      .toList(),
                  headerStyle: boldStyle,
                  cellStyle: baseStyle,
                  headerAlignment: pw.Alignment.centerRight,
                  cellAlignment: pw.Alignment.centerRight,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellHeight: 28,
                ),
              ],
              pw.SizedBox(height: 24),
              _signaturePlaceholder(baseStyle, boldStyle),
            ],
          );
        },
      ),
    );

    return doc;
  }

  pw.Widget _signaturePlaceholder(
    pw.TextStyle baseStyle,
    pw.TextStyle boldStyle,
  ) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 240,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              StringsAr.sellerSignature,
              style: boldStyle.copyWith(fontSize: 13),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: 240,
              height: 72,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 1),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              StringsAr.signHere,
              style: baseStyle.copyWith(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final pdfService = PdfService();
