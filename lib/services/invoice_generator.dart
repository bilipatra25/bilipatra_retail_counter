/*
import 'dart:html' as html; // Web only
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/product.dart';
import '../models/user.dart';
*/
/*class InvoiceGenerator {
  static pw.ImageProvider? _logoImage;
  static pw.Font? _font;
  static pw.ImageProvider? _cachedLogo;

  static Future<void> preloadAssets() async {
    if (_cachedLogo == null) {
      _cachedLogo = await imageFromAssetBundle('logo_min.png');
    }
  }
  static Future<void> init() async {
    if (_logoImage == null) {
      _logoImage = await imageFromAssetBundle('logo_min.png');
    }
    if (_font == null) {
      _font = await fontFromAssetBundle('assets/fonts/NotoSans-Regular.ttf');
    }
  }

  static Future<void> generateInvoicePdf(UserModel user, List<ProductModel> products) async {
    await init(); // Ensure assets are loaded
    await preloadAssets(); // Make sure logo is preloaded
    final image = _cachedLogo!;

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy – hh:mm a').format(now);
    final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';
    final total = products.fold(0.0, (sum, p) => sum + (p.price * p.quantity));
    final ttf = await fontFromAssetBundle('assets/fonts/NotoSans-Regular.ttf');
    // final image = await imageFromAssetBundle('logo_min.png');


    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with logo and title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(height: 60, width: 60, child: pw.Image(image)),
                pw.Text(
                  'Invoice',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              'Bilipatra Retail Counter',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Customer Details:', style: pw.TextStyle(fontSize: 18)),
            pw.Text('Name: ${user.name}'),
            pw.Text('Phone: ${user.number}'),
            pw.Text('Address: ${user.address}'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Order Summary:',
              style: pw.TextStyle(fontSize: 18, font: ttf),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Product', 'Qty', 'Price (₹)', 'Total (₹)'],
              data:
              products
                  .map((p) => [p.name,
                p.quantity.toString(),
                p.price.toStringAsFixed(2),
                (p.quantity * p.price).toStringAsFixed(2),])
                  .toList(),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf),
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: ₹ ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
              ),
            ),
          ],
        ),
      ),
    );


    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}*//*


class InvoiceGenerator {
  static Future<void> generateInvoicePdf(
      UserModel user,
      List<ProductModel> products,
      ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy – hh:mm a').format(now);
    final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';

    final total = products.fold(0.0, (sum, p) => sum + (p.price * p.quantity));

    // Load logo and custom font
    final image = await imageFromAssetBundle('logo_min.png');
    final ttf = await fontFromAssetBundle('assets/fonts/NotoSans-Regular.ttf');

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo and title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(height: 60, width: 60, child: pw.Image(image)),
                  pw.Text(
                    'Invoice',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      font: ttf,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Invoice number & date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: $invoiceNumber', style: pw.TextStyle(font: ttf)),
                  pw.Text('Date: $formattedDate', style: pw.TextStyle(font: ttf)),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer Info
              pw.Text(
                'Customer Information',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Name: ${user.name}', style: pw.TextStyle(font: ttf)),
              pw.Text('Phone: ${user.number}', style: pw.TextStyle(font: ttf)),
              pw.Text('Address: ${user.address}', style: pw.TextStyle(font: ttf)),
              pw.SizedBox(height: 20),

              // Order Table
              pw.Text(
                'Order Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Product', 'Qty', 'Price (₹)', 'Total (₹)'],
                headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(font: ttf),
                cellAlignment: pw.Alignment.centerLeft,
                data: products
                    .map(
                      (p) => [
                    p.name,
                    p.quantity.toString(),
                    p.price.toStringAsFixed(2),
                    (p.quantity * p.price).toStringAsFixed(2),
                  ],
                )
                    .toList(),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ₹ ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Payment Terms
              pw.Text(
                'Payment Details & Terms',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Mode of Payment: Cash / UPI / Card', style: pw.TextStyle(font: ttf)),
              pw.Text('Thank you for shopping with us.', style: pw.TextStyle(font: ttf)),
              pw.Text('Goods once sold will not be taken back.', style: pw.TextStyle(font: ttf)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static Future<Uint8List> generatePdfBytes(
    UserModel user,
    List<ProductModel> products,
  ) async {
    final pdf = pw.Document();
    double total = products.fold(0, (sum, p) => sum + p.price);
    final ttf = await fontFromAssetBundle('assets/fonts/NotoSans-Regular.ttf');

    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Bilipatra Retail Counter',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Customer Details:', style: pw.TextStyle(fontSize: 18)),
                pw.Text('Name: ${user.name}'),
                pw.Text('Phone: ${user.number}'),
                pw.Text('Address: ${user.address}'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Order Summary:',
                  style: pw.TextStyle(fontSize: 18, font: ttf),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Product', 'Price (₹)'],
                  data:
                      products
                          .map((p) => [p.name, p.price.toStringAsFixed(2)])
                          .toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total: ₹ ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: ttf,
                    ),
                  ),
                ),
              ],
            ),
      ),
    );

    return pdf.save();
  }

  static Future<void> downloadAndSharePdf(
    UserModel user,
    List<ProductModel> products,
  ) async {
    final bytes = await generatePdfBytes(user, products);
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute("download", "invoice.pdf")
          ..click();

    html.Url.revokeObjectUrl(url);
  }
}

class InvoiceGeneratorEzo {
  static Future<void> generateInvoicePdf(UserModel user,
      List<ProductModel> products,) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(now);
    final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';
    final total = products.fold(0.0, (sum, p) => sum + (p.price * p.quantity));

    final image = await imageFromAssetBundle('logo_min.png');
    final ttf = await fontFromAssetBundle('assets/fonts/NotoSans-Regular.ttf');
    final rowHeight = 14.0; // each product row approx height
    final baseHeight = 320.0; // static content (logo + header + footer + spacing)
    final estimatedHeight = baseHeight + (products.length * rowHeight);

    pdf.addPage(
      pw.Page(pageFormat: PdfPageFormat(135, estimatedHeight),
        // ~56.7mm width
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Logo and title
            pw.Center(child: pw.Column(children: [
              pw.Container(height: 30, width: 30, child: pw.Image(image)),
              pw.SizedBox(height: 2),
              pw.Text('INVOICE', style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, font: ttf,),),
            ],),),
            pw.SizedBox(height: 4),
            pw.Divider(),

            // Invoice info
            pw.Text('Invoice #: $invoiceNumber',
              style: pw.TextStyle(fontSize: 7, font: ttf),),
            pw.Text('Date: $formattedDate',
              style: pw.TextStyle(fontSize: 7, font: ttf),),
            pw.SizedBox(height: 4),

            // Customer details
            pw.Text('Customer Info', style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, font: ttf,),),
            pw.Text('Name: ${user.name}',
              style: pw.TextStyle(fontSize: 7, font: ttf),),
            pw.Text('Phone: ${user.number}',
              style: pw.TextStyle(fontSize: 7, font: ttf),),
            pw.Text('Address: ${user.address}',
              style: pw.TextStyle(fontSize: 7, font: ttf),),
            pw.SizedBox(height: 4),

            // Product list
            pw.Text('Order Summary', style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, font: ttf,),),
            pw.SizedBox(height: 2),
            pw.Table.fromTextArray(
              headers: ['Item', 'Qty', 'Rate', 'Amt'],
              data: products.map((p) {
                return [
                  p.name.length > 10 ? p.name.substring(0, 10) + '...' : p.name,
                  p.quantity.toString(),
                  p.price.toStringAsFixed(2),
                  (p.quantity * p.price).toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 7, fontWeight: pw.FontWeight.bold, font: ttf,),
              cellStyle: pw.TextStyle(fontSize: 7, font: ttf),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.3),
              },
              border: null,),
            pw.SizedBox(height: 4),
            pw.Divider(),

            // Total
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total: ', style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, font: ttf,),),
                pw.Text('₹ ${total.toStringAsFixed(2)}', style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, font: ttf,),),
              ],),
            pw.SizedBox(height: 6),

            // Footer
            pw.Center(child: pw.Column(children: [
              pw.Text('Payment: Cash / UPI / Card',
                style: pw.TextStyle(fontSize: 7, font: ttf),),
              pw.Text('Thanks for your purchase!',
                style: pw.TextStyle(fontSize: 7, font: ttf),),
              pw.Text('No exchange or return.',
                style: pw.TextStyle(fontSize: 7, font: ttf),),
            ],),),
          ],);
        },),);

    await Printing.layoutPdf(format: PdfPageFormat.roll57,
      onLayout: (PdfPageFormat format) async => pdf.save(),);
  }
}
*/
