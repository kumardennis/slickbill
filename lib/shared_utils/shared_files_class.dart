import 'package:syncfusion_flutter_pdf/pdf.dart';

class SharedFilesClass {
  Future<String?> convertPdfToText(fileBytes, [incomingText]) async {
    try {
      PdfDocument document = PdfDocument(inputBytes: fileBytes);
//Extract the text from page 1.
      String text = incomingText ??
          PdfTextExtractor(document).extractText(startPageIndex: 0);

      //Create a new instance of the PdfTextExtractor.
      PdfTextExtractor extractor = PdfTextExtractor(document);

//Extract all the text from a particular page.
      List<TextLine> result = extractor.extractTextLines(startPageIndex: 0);

//Dispose the document.
      document.dispose();

      List<String> joinedTextList = [];

      result.forEach(
        (element) {
          joinedTextList.add(element.text);
        },
      );

      String joinedText = (joinedTextList.join('\n'));

      return joinedText;
    } catch (err) {
      print(err);
      return null;
    }
  }
}
