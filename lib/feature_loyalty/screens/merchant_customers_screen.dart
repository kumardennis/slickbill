import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_dashboard_model.dart';
import 'package:slickbill/feature_loyalty/models/merchant_customer_link_model.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_insights_repo.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_customer_row.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_insights_kpi_row.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class MerchantCustomersScreen extends HookWidget {
  const MerchantCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => MerchantInsightsRepo());
    final dashboard = useState<MerchantDashboardModel?>(null);
    final customers = useState<List<MerchantCustomerLinkModel>>([]);
    final isLoading = useState(true);
    final error = useState<String?>(null);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final results = await Future.wait([
          repo.getDashboard(),
          repo.listCustomers(),
        ]);
        dashboard.value = results[0] as MerchantDashboardModel;
        customers.value = results[1] as List<MerchantCustomerLinkModel>;
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
        title: 'hd_MerchantCustomers'.tr,
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
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Text(
                        'lbl_MerchantCustomersHint'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.darkGray,
                            ),
                      ),
                      const SizedBox(height: 16),
                      MerchantInsightsKpiRow(
                        dashboard: dashboard.value ?? MerchantDashboardModel.empty,
                      ),
                      const SizedBox(height: 20),
                      if (customers.value.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'lbl_NoMerchantCustomersYet'.tr,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.darkGray,
                                ),
                          ),
                        )
                      else
                        ...customers.value.map(
                          (c) => MerchantCustomerRow(customer: c),
                        ),
                    ],
                  ),
      ),
    );
  }
}
