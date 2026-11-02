import 'package:joint_expenses/features/statement_import/domain/pdf_tokens.dart';

PdfLayoutLine layoutLine(String text, {int page = 1, double y = 500}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return PdfLayoutLine(
    page: page,
    y: y,
    tokens: [
      for (var i = 0; i < words.length; i++)
        PdfTextToken(page: page, x: i * 12.0, y: y, text: words[i]),
    ],
  );
}

List<PdfLayoutLine> bpiSampleLayout() {
  var y = 700.0;
  PdfLayoutLine next(String text, {int page = 0}) {
    y -= 10;
    return layoutLine(text, page: page, y: y);
  }

  return [
    next('BPI Statement of Account'),
    next('STATEMENT DATE SEPTEMBER 21, 2026'),
    next('PAT RIVERA'),
    next('PAYMENT DUE DATE OCTOBER 12, 2026'),
    next('CREDIT LIMIT 700,000.00'),
    next('TOTAL AMOUNT DUE 215,487.61'),
    next('MINIMUM AMOUNT DUE 888.54'),
    next('Unbilled Installment Amount 240,720.63'),
    next('Please use your customer number when paying your'),
    next('BPI SIGNATURE CARD', page: 2),
    next('Transaction Post Date Description Amount', page: 2),
    next('100001-1-00-1111111 - PAT RIVERA', page: 2),
    next('Installment Amortization:', page: 2),
    next('September 21 September 21 Shopee Ph - Ecipp Zero : 08/24 701.00', page: 2),
    next('September 21 September 21 Shopee Ph - Ecipp Zero : 13/24 1,866.25', page: 2),
    next('September 21 September 21 Executive Optical-Sm Ceb : 05/06 2,761.67', page: 2),
    next('September 21 September 21 Gintell-Sm Cebu Nra : 08/12 2,500.00', page: 2),
    next('September 21 September 21 Istore-Ayala Central Blo : 10/24 3,457.50', page: 2),
    next('Installment Purchase:', page: 2),
    next('September 2 September 2 Sm Appliance Center 15,000.00', page: 2),
    next('September 5 September 7 Payment - Thank You -166,394.69', page: 2),
    next('August 24 August 24 Reversal-Finance Charges -4,100.50', page: 2),
    next('August 24 August 26 Shopee Ph Mandaluyong 1,016.00', page: 2),
    next('September 11 September 11 Cursor, Ai Powered Ide Cursor.Com US', page: 2),
    next('U.S. Dollar 20.00 1,276.65', page: 2),
    next('September 10 September 11 Atmosphere Restaurant Cebu City 9,706.43', page: 2),
    next('Previous Balance 166,394.69', page: 2),
    next('Ending Balance 215,487.61', page: 2),
    next('100001-1-00-2222222 - ALEX CRUZ', page: 3),
    next('Installment Amortization:', page: 3),
    next('September 21 September 21 Aerophone Ent-Ayala Cebu : 02/06 1,666.50', page: 3),
    next('September 21 September 21 Ace Hardware-Sm Cebu : 06/06 2,159.55', page: 3),
    next('September 21 September 21 The Loop-Ayala Central B : 09/24 479.17', page: 3),
    next('September 21 September 21 The Loop-Ayala Central B : 08/24 999.17', page: 3),
    next('September 21 September 21 The Loop-Ayala Central B : 08/24 3,490.63', page: 3),
    next('September 21 September 21 Digital Village-Sm Cebu : 09/24 1,366.25', page: 3),
    next('September 21 September 21 Echo Appliance Center : 02/06 876.67', page: 3),
    next('September 21 September 21 Istore-Stall246 Ayala Ce : 09/24 2,541.25', page: 3),
    next('August 25 August 27 Netflix.Com Singapore 625.19', page: 3),
    next('Installment Balance Summary', page: 4),
    next('Transaction Last Payment Description Purchase Amount Remaining', page: 4),
    next('090925 082127 Shopee Ph - Ecipp Zero 44,790.00 20,528.75', page: 4),
    next('113025 112127 Istore-Ayala Central Blo 82,980.00 48,405.00', page: 4),
    next('020226 012128 Shopee Ph - Ecipp Zero 16,824.00 11,216.00', page: 4),
    next('020826 012127 Gintell-Sm Cebu Nra 30,000.00 10,000.00', page: 5),
    next('050926 102126 Executive Optical-Sm Ceb 16,570.00 2,761.65', page: 5),
    next('111225 012128 The Loop-Ayala Central B 23,980.00 15,986.64', page: 5),
    next('111825 012128 The Loop-Ayala Central B 83,775.00 55,849.96', page: 5),
    next('122125 122127 Digital Village-Sm Cebu 32,790.00 20,493.75', page: 5),
    next('122525 122127 Istore-Stall246 Ayala Ce 60,990.00 38,118.75', page: 5),
    next('010726 122127 The Loop-Ayala Central B 11,500.00 7,187.47', page: 5),
    next('072026 012127 Echo Appliance Center 5,260.00 3,506.66', page: 5),
    next('080226 012127 Aerophone Ent-Ayala Cebu 9,999.00 6,666.00', page: 5),
    next('Total 240,720.63', page: 5),
  ];
}
