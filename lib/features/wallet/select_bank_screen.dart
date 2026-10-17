import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/top_bar.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// B5 · Select bank (38:20): the banks as Paystack lists them, searchable by
/// name; the saved one says so. A pick opens Add a bank account for it
/// (483:22323); once that saves, this page goes too and pops true, back to
/// whatever opened it (the Bank account sheet, a failed withdrawal). The
/// search field and the first rows settle with the push (spec 1.3).
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

  Future<void> _pick(Bank bank) async {
    final saved = await context.push<bool>(addBankPath(bank.code));
    if (saved == true && mounted) {
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(bankAccountPath);
      }
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
                    onBack: () => leaveWallet(context),
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
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(IqSpace.s4),
                          sliver: _BankCard(
                            count: banks.length,
                            row: (i) {
                              final bank = banks[i];
                              return StaggerItem(
                                index: i + 1,
                                child: IqListRow(
                                  key: ValueKey(bank.code),
                                  label: bank.name,
                                  description: bank.code == saved?.bankCode
                                      ? 'Saved · ${saved!.holder}'
                                      : '',
                                  showDescription: bank.code == saved?.bankCode,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banks in one hairline card, built as they scroll into view: the
/// list runs to hundreds of banks, and building them all with the page
/// stuttered its push.
class _BankCard extends StatelessWidget {
  const _BankCard({required this.count, required this.row});

  final int count;
  final Widget Function(int i) row;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);
    return DecoratedSliver(
      decoration: BoxDecoration(color: IqColors.card, borderRadius: corners),
      sliver: DecoratedSliver(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: corners,
          border: Border.all(color: IqColors.line),
        ),
        // A Container's border insets its child; this card's does too.
        sliver: SliverPadding(
          padding: const EdgeInsets.all(1),
          sliver: SliverList.builder(
            itemCount: count,
            itemBuilder: (context, i) => i > 0 && i < count - 1
                ? row(i)
                : ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: i == 0 ? corners.topLeft : Radius.zero,
                      bottom: i == count - 1 ? corners.bottomLeft : Radius.zero,
                    ),
                    child: row(i),
                  ),
          ),
        ),
      ),
    );
  }
}
