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
    final NavigationController navigationController =
        Get.find(); // Initialize controller

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

          // final text = await platformPDFExtract.invokeMethod(
          //     'extractTextFromPdf', {'pdfBytes': result.files.single.bytes});

          // print(text);

          pdfBytes.value = bytes;
          await getFileData(bytes);
        }
      } else {
        print('cncelled');
      }
    }

    Future analyzeText() async {
      if (analyzeTextController.text != '') {
        print(analyzeTextController.text);

        await getExtractedDataFromText(analyzeTextController.text);
      } else {
        print('cncelled');
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

    return (Scaffold(
      appBar: CustomAppbar(title: 'hd_CreateASlickbill'.tr, appbarIcon: null),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.all(20),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.blue)),
                    onPressed: pickFile,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'btn_UploadPDF'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.blue),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        FaIcon(FontAwesomeIcons.upload,
                            color: Theme.of(context).colorScheme.blue)
                      ],
                    ),
                  ),
                ),
                Text(
                  'OR',
                  style: TextStyle(color: Theme.of(context).colorScheme.gray),
                ),
                const SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      SizedBox(
                        child: TextField(
                          decoration: InputDecoration(
                              filled: true,
                              hintText: 'lbl_PasteText'.tr,
                              hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.gray),
                              fillColor: Theme.of(context).colorScheme.light),
                          controller: analyzeTextController,
                          keyboardType: TextInputType.multiline,
                          minLines: 3,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.all(20),
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.blue)),
                        onPressed: analyzeText,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'btn_AnalyzeText'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.blue),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            FaIcon(FontAwesomeIcons.pencil,
                                color: Theme.of(context).colorScheme.blue)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pdfBytes.value != null
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      height: 300,
                      width: 250,
                      color: Colors.blue,
                      child: SfPdfViewer.memory(
                        pdfBytes.value!,
                      ),
                    ),
                  )
                : const SizedBox(),
            isLoading.value
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        Text('inf_AnalyzingPDF'.tr)
                      ],
                    )),
                  )
                : const SizedBox(),
            InputField(
              controller: originalInvoiceNoController,
              label: 'lbl_OriginalInvoiceNo'.tr,
            ),
            InputField(
              controller: senderNameController,
              label: 'lbl_SenderName'.tr,
            ),
            Column(
              children: [
                InputField(
                  controller: ibanController,
                  label: 'lbl_SenderIban'.tr,
                ),
                extractedData.value != null &&
                        extractedData.value?.iban != null &&
                        extractedData.value?.iban.first.bankName != ''
                    ? Wrap(
                        children: extractedData.value?.iban.map((iban) {
                          int idx = extractedData.value!.iban.indexOf(iban);
                          return (TextButton(
                              style: TextButton.styleFrom(
                                  backgroundColor:
                                      idx == selectedIbanIndex.value
                                          ? Theme.of(context).colorScheme.blue
                                          : Theme.of(context).colorScheme.dark),
                              onPressed: () {
                                selectedIbanIndex.value = idx;

                                ibanController.text = IbanExtractor.extractIban(
                                        extractedData.value!.iban[idx].iban) ??
                                    '-';
                              },
                              child: Text(
                                iban.bankName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: idx == selectedIbanIndex.value
                                            ? Theme.of(context)
                                                .colorScheme
                                                .light
                                            : Theme.of(context)
                                                .colorScheme
                                                .light),
                              )));
                        }).toList() as List<Widget>,
                      )
                    : const SizedBox()
              ],
            ),
            InputField(
              controller: amountController,
              label: 'lbl_Amount'.tr,
            ),
            InputField(
              controller: descriptionController,
              label: 'lbl_Description'.tr,
            ),
            InputField(
              controller: dueDateController,
              label: 'lbl_DueDate'.tr,
            ),
            InputField(
              controller: referenceNumberController,
              label: 'lbl_ReferenceNumber'.tr,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Wrap(
                spacing: 5.0,
                runSpacing: 5.0,
                children: Constants().categories.map(
                  (item) {
                    return ChoiceChip(
                      backgroundColor: Theme.of(context).colorScheme.gray,
                      selectedColor: Theme.of(context).colorScheme.blue,
                      label: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      selected: category.value == item,
                      onSelected: (bool selected) {
                        category.value = item;
                      },
                    );
                  },
                ).toList(),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 100,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: createInvoice,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'btn_AddSlickBill'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.squarePlus,
                            color: Theme.of(context).colorScheme.light,
                          )
                        ],
                      ),
                    )),
              ),
            )
          ],
        ),
      ),
    ));
  }
}
