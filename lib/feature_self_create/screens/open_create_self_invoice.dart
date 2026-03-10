import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_self_create/utils/IbanExtractor.dart';
import 'package:slickbill/feature_self_create/utils/create_invoices_class.dart';
import 'package:slickbill/feature_self_create/utils/files_class.dart';
import 'package:slickbill/shared_utils/shared_files_class.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart';
import '../../feature_navigation/getx_controllers/navigation_controller.dart';
import '../models/extracted_invoice_data_model.dart';
import '../widgets/input_field.dart';

class OpenAndCreateSelfInvoice extends HookWidget {
  const OpenAndCreateSelfInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.find();

    FilesClass filesClass = FilesClass();
    SharedFilesClass sharedFilesClass = SharedFilesClass();
    CreateInvoicesClass createInvoicesClass = CreateInvoicesClass();

    var pdfPath = useState<String?>(null);
    var pdfBytes = useState<Uint8List?>(null);

    var category = useState<String>(Constants().categories.last);

    var senderNameController = useTextEditingController();
    var descriptionController = useTextEditingController();
    var amountController = useTextEditingController();
    var dueDateController = useTextEditingController();
    var referenceNumberController = useTextEditingController();
    var ibanController = useTextEditingController();
    var originalInvoiceNoController = useTextEditingController();

    var analyzeTextController = useTextEditingController();

    var selectedIbanIndex = useState<int>(0);

    var extractedData = useState<ExtractedInvoiceDataModel?>(null);

    const platformPDFBytes =
        const MethodChannel('com.example.slickbill/getPdfBytes');

    final isLoading = useState<bool>(false);

    Future getFileData(Uint8List? fileBytes, [String? text]) async {
      isLoading.value = true;

      var convertedText =
          await sharedFilesClass.convertPdfToText(fileBytes, text);
      var data = await filesClass.uploadTextToExtractData(convertedText);

      if (data != null) {
        originalInvoiceNoController.text = data.invoiceNo;
        senderNameController.text = data.merchantName;
        ibanController.text =
            IbanExtractor.extractIban(data.iban.first.iban) ?? '-';
        descriptionController.text = data.description;
        amountController.text = data.totalAmount.toString();
        dueDateController.text = data.dueDate;
        referenceNumberController.text = data.referenceNumber;
        extractedData.value = data;
        category.value = data.category;
      }

      analyzeTextController.text = '';

      isLoading.value = false;
    }

    Future getExtractedDataFromText(String? text) async {
      isLoading.value = true;
      var data = await filesClass.uploadTextToExtractData(text);

      if (data != null) {
        originalInvoiceNoController.text = data.invoiceNo;
        senderNameController.text = data.merchantName;
        ibanController.text =
            IbanExtractor.extractIban(data.iban.first.iban) ?? '-';
        descriptionController.text = data.description;
        amountController.text = data.totalAmount.toString();
        dueDateController.text = data.dueDate;
        referenceNumberController.text = data.referenceNumber;
        extractedData.value = data;

        if (data.dueDate == '') {
          final today = DateTime.now();
          final sevenDaysFromNow = today.add(const Duration(days: 7));

          dueDateController.text =
              DateFormat('yyyy-MM-dd').format(sevenDaysFromNow);
        }
      }

      analyzeTextController.text = '';

      isLoading.value = false;
    }

    Future pickFile() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        print(result.files.single.bytes);

        if (kIsWeb) {
          pdfBytes.value = result.files.single.bytes;
          await getFileData(result.files.single.bytes);
        } else {
          pdfPath.value = result.files.single.path;
          var bytes = await File(result.files.single.path!).readAsBytes();
          pdfBytes.value = bytes;
          await getFileData(bytes);
        }
      } else {
        print('cancelled');
      }
    }

    Future analyzeText() async {
      if (analyzeTextController.text != '') {
        print(analyzeTextController.text);
        await getExtractedDataFromText(analyzeTextController.text);
      } else {
        print('cancelled');
      }
    }

    Future<Uint8List?> getFilePath() async {
      try {
        final Uint8List? result =
            await platformPDFBytes.invokeMethod('getPdfBytes');
        print('FLUTTERBYTES $result');

        if (result != null) {
          await getFileData(result);
          return result;
        } else {
          return null;
        }
      } on PlatformException catch (e) {
        print("Failed to get file path: '${e.message}'.");
        return null;
      } catch (e) {
        print("Unexpected error: $e");
        return null;
      }
    }

    Future createInvoice() async {
      await createInvoicesClass.createPrivateSelfInvoice(
          originalInvoiceNoController.text,
          senderNameController.text,
          ibanController.text,
          descriptionController.text,
          amountController.text,
          dueDateController.text,
          referenceNumberController.text,
          category.value);

      navigationController.changeIndex(0);
    }

    useEffect(() {
      late AppLifecycleListener listener;

      listener = AppLifecycleListener(
        onResume: () {
          print('App resumed, checking for new intents');
          getFilePath().then((value) {
            if (value != null) {
              pdfBytes.value = value;
            }
          }).catchError((error) {});
        },
        onShow: () {
          print('App shown, checking for new intents');
          getFilePath().then((value) {
            if (value != null) {
              pdfBytes.value = value;
            }
          }).catchError((error) {});
        },
      );
      getFilePath().then((value) {
        if (value != null) {
          pdfBytes.value = value;
        }
      }).catchError((error) {});

      return () {
        listener.dispose();
      };
    }, []);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      appBar: CustomAppbar(title: 'hd_CreateASlickbill'.tr, appbarIcon: null),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Upload Section - Modern Card Design
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.blue.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Upload PDF Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: pickFile,
                      icon: FaIcon(FontAwesomeIcons.filePdf, size: 20),
                      label: Text(
                        'btn_UploadPDF'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.blue,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.blue,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // OR Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .gray
                              .withOpacity(0.3),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.darkGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .gray
                              .withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Paste Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            Theme.of(context).colorScheme.gray.withOpacity(0.3),
                      ),
                    ),
                    child: TextField(
                      controller: analyzeTextController,
                      maxLines: 4,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.dark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'lbl_PasteText'.tr,
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.gray,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Analyze Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: isLoading.value ? null : analyzeText,
                      icon: isLoading.value
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : FaIcon(FontAwesomeIcons.wandMagicSparkles,
                              size: 18),
                      label: Text(
                        isLoading.value
                            ? 'inf_AnalyzingPDF'.tr
                            : 'btn_AnalyzeText'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ PDF Preview (if available)
            if (pdfBytes.value != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).colorScheme.gray.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.picture_as_pdf,
                            color: Theme.of(context).colorScheme.blue),
                        SizedBox(width: 8),
                        Text(
                          'PDF Preview',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .gray
                              .withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SfPdfViewer.memory(pdfBytes.value!),
                      ),
                    ),
                  ],
                ),
              ),

            if (pdfBytes.value != null) SizedBox(height: 20),

            // ✅ Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Text(
                    'Invoice Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.dark,
                        ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fill in the invoice information below',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.darkGray,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Form Fields
                  InputField(
                    icon: Icons.numbers,
                    label: 'lbl_OriginalInvoiceNo'.tr,
                    controller: originalInvoiceNoController,
                  ),

                  InputField(
                    icon: Icons.person_outline,
                    label: 'lbl_SenderName'.tr,
                    controller: senderNameController,
                  ),

                  // IBAN Field with Bank Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InputField(
                        icon: Icons.account_balance,
                        label: 'lbl_SenderIban'.tr,
                        controller: ibanController,
                      ),
                      if (extractedData.value != null &&
                          extractedData.value?.iban != null &&
                          extractedData.value?.iban.first.bankName != '')
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: extractedData.value!.iban.map((iban) {
                              int idx = extractedData.value!.iban.indexOf(iban);
                              bool isSelected = idx == selectedIbanIndex.value;
                              return ActionChip(
                                label: Text(
                                  iban.bankName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.dark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.blue
                                    : Theme.of(context).colorScheme.light,
                                side: BorderSide(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.blue
                                      : Theme.of(context)
                                          .colorScheme
                                          .gray
                                          .withOpacity(0.3),
                                ),
                                onPressed: () {
                                  selectedIbanIndex.value = idx;
                                  ibanController.text =
                                      IbanExtractor.extractIban(extractedData
                                              .value!.iban[idx].iban) ??
                                          '-';
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),

                  InputField(
                    icon: Icons.euro,
                    label: 'lbl_Amount'.tr,
                    controller: amountController,
                    type: TextInputType.numberWithOptions(decimal: true),
                  ),

                  InputField(
                    icon: Icons.description,
                    label: 'lbl_Description'.tr,
                    controller: descriptionController,
                  ),

                  InputField(
                    icon: Icons.calendar_today,
                    label: 'lbl_DueDate'.tr,
                    controller: dueDateController,
                    type: TextInputType.datetime,
                  ),

                  InputField(
                    icon: Icons.tag,
                    label: 'lbl_ReferenceNumber'.tr,
                    controller: referenceNumberController,
                  ),

                  SizedBox(height: 24),

                  // Category Section
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.dark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Constants().categories.map((item) {
                      bool isSelected = category.value == item;
                      return ChoiceChip(
                        label: Text(
                          item,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.blue,
                        backgroundColor: Theme.of(context).colorScheme.light,
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.blue
                              : Theme.of(context)
                                  .colorScheme
                                  .gray
                                  .withOpacity(0.3),
                        ),
                        onSelected: (bool selected) {
                          category.value = item;
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 40),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: createInvoice,
                      icon: FaIcon(FontAwesomeIcons.plus, size: 18),
                      label: Text(
                        'btn_AddSlickBill'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
