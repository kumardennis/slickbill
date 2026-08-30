import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/customer_merchant_relationship_model.dart';
import 'package:slickbill/feature_loyalty/repos/customer_relationships_repo.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_merchant_relationship_row.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class CustomerMyMerchantsScreen extends HookWidget {
  const CustomerMyMerchantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => CustomerRelationshipsRepo());
    final relationships = useState<List<CustomerMerchantRelationshipModel>>([]);
    final isLoading = useState(true);
    final error = useState<String?>(null);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        relationships.value = await repo.listMerchantRelationships();
      } catch (e) {
        error.value = e is String ? e : e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      appBar: CustomAppbar(
        title: 'hd_MyMerchants'.tr,
        appbarIcon: null,
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: isLoading.value
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : error.value != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        error.value!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: load,
                        child: Text('btn_Retry'.tr),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Text(
                        'lbl_MyMerchantsHint'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.darkGray,
                            ),
                      ),
                      const SizedBox(height: 16),
                      if (relationships.value.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            'lbl_NoMyMerchantsYet'.tr,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.darkGray,
                                ),
                          ),
                        )
                      else
                        ...relationships.value.map(
                          (relationship) => CustomerMerchantRelationshipRow(
                            relationship: relationship,
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
