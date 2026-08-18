import 'package:slickbill/feature_send/models/receiver_user_model.dart';

class DirectShareDraft {
  DirectShareDraft({
    required this.receiver,
    required this.description,
    required this.referenceNo,
    required this.category,
  });

  final ReceiverUserModel receiver;
  final String description;
  final String referenceNo;
  final String category;
}
