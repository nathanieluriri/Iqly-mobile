import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/top_bar.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// B5 · Select bank (38:20): the banks as Paystack lists them, searchable by
/// name; the saved one says so. A pick goes back to the Withdraw sheet with
/// that bank; opened on its own (Check bank details on a failed
/// withdrawal), it opens the sheet for it. The search field and the first
/// rows settle with the push (spec 1.3).
class SelectBankScreen extends ConsumerStatefulWidget {
  const SelectBankScreen({super.key});

  @override
  ConsumerState<SelectBankScreen> createState() => _SelectBankScreenState();
}

class _SelectBankScreenState extends ConsumerState<SelectBankScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(Bank bank) {
    if (context.canPop()) {
      context.pop(bank);
    } else {
      context.go(withdrawLocation(bankCode: bank.code));
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.wallet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final saved = data?.savedBank;
    final query = _query.trim().toLowerCase();
    final banks = [
      for (final bank in data?.banks ?? const <Bank>[])
        if (bank.name.toLowerCase().contains(query)) bank,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Stagger(
              move: StaggerMove.settle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IqTopBar(
                    variant: IqTopBarVariant.page,
                    title: 'Select bank',
                    onBack: _back,
                  ),
                  StaggerItem(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      child: IqField(
                        label: 'Search',
                        value: 'Bank name',
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (text) => setState(() => _query = text),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: banks.length,
                      itemBuilder: (context, i) {
                        final bank = banks[i];
                        final isSaved = bank.code == saved?.bankCode;
                        return StaggerItem(
                          index: i + 1,
                          child: IqListRow(
                            key: ValueKey(bank.code),
                            label: bank.name,
                            description: isSaved
                                ? 'Saved · ${saved!.accountName}'
                                : '',
                            showDescription: isSaved,
                            icon: IqIcons.bank,
                            divider: i < banks.length - 1,
                            onTap: () => _pick(bank),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
