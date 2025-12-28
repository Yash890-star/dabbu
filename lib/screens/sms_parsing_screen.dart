import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../utils/app_colors.dart';
import '../utils/cms.dart';
import '../viewmodels/sms_parsing_view_model.dart';
import '../widgets/sms/sms_code_block.dart';
import '../widgets/sms/selection_tab.dart';
import 'main_screen.dart';

class SmsParsingScreen extends StatefulWidget {
  final SmsMessage message;
  final int? existingPatternId; // For "Edit Pattern" mode
  final String? initialPatternName;
  final int? initialCategoryId;

  const SmsParsingScreen({
    super.key,
    required this.message,
    this.existingPatternId,
    this.initialPatternName,
    this.initialCategoryId,
  });

  @override
  State<SmsParsingScreen> createState() => _SmsParsingScreenState();
}

class _SmsParsingScreenState extends State<SmsParsingScreen> {
  late SmsParsingViewModel _viewModel;
  final TextEditingController _patternNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = SmsParsingViewModel(
      message: widget.message,
      existingPatternId: widget.existingPatternId,
      initialPatternName: widget.initialPatternName,
      initialCategoryId: widget.initialCategoryId,
    );
    _viewModel.init();

    _patternNameController.text =
        widget.initialPatternName ?? widget.message.address ?? "Bank";
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _patternNameController.dispose();
    super.dispose();
  }

  Future<void> _addNewCategory() async {
    TextEditingController catController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(CMS.smsParsing['new_category_title']!),
            content: TextField(
              controller: catController,
              decoration: InputDecoration(
                hintText: CMS.smsParsing['category_hint']!,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(CMS.common['cancel']!),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (catController.text.isNotEmpty) {
                    await _viewModel.addNewCategory(catController.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: Text(CMS.common['add']!),
              ),
            ],
          ),
    );
  }

  Future<void> _savePatternAndContinue() async {
    try {
      final success = await _viewModel.savePattern(_patternNameController.text);
      if (success) {
        if (!mounted) return;
        if (widget.existingPatternId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CMS.smsParsing['success_message']!)),
          );
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains("Exception:")) {
        msg = msg.replaceAll("Exception: ", "");
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(CMS.smsParsing['title']!)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sender ID
                  Text(
                    CMS.smsParsing['step_1_title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        _viewModel.senderTokens.map((token) {
                          final isSelected =
                              token == _viewModel.selectedSenderToken;
                          return ChoiceChip(
                            label: Text(token),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _viewModel.setSelectedSenderToken(token);
                              }
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 2. Message Body & Parsing
                  Text(
                    CMS.smsParsing['step_2_title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // CHIP SELECTOR (For Fields)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectionTab(
                            label: "Amount",
                            isSelected:
                                _viewModel.selectionMode ==
                                SelectionMode.amount,
                            activeColor: Colors.green,
                            onTap:
                                () => _viewModel.setSelectionMode(
                                  SelectionMode.amount,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SelectionTab(
                            label: "Anchor Text",
                            isSelected:
                                _viewModel.selectionMode ==
                                SelectionMode.anchor,
                            activeColor: Colors.blue,
                            onTap:
                                () => _viewModel.setSelectionMode(
                                  SelectionMode.anchor,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    _viewModel.selectionMode == SelectionMode.amount
                        ? "Tap the word that represents the transaction amount."
                        : "Tap distinct words before/after the amount to create a stable pattern.",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // CODE BLOCK
                  SmsCodeBlock(
                    tokens: _viewModel.bodyTokens,
                    onTokenTap: _viewModel.handleTokenTap,
                    selectedAmountIndex: _viewModel.selectedAmountIndex,
                    prefixStart: _viewModel.prefixStart,
                    prefixEnd: _viewModel.prefixEnd,
                    suffixStart: _viewModel.suffixStart,
                    suffixEnd: _viewModel.suffixEnd,
                  ),

                  const SizedBox(height: 8),
                  if (_viewModel.generatedRegex.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${CMS.smsParsing['regex_preview']!}${_viewModel.generatedRegex}",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  if (_viewModel.selectedAmountIndex != null) ...[
                    Text(
                      CMS.smsParsing['step_3_title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(CMS.smsParsing['debit_label']!),
                          selected: _viewModel.transactionType == 'debit',
                          selectedColor: AppColors.expense.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.expense,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.transactionType == 'debit'
                                    ? AppColors.expense
                                    : Theme.of(context).colorScheme.onSurface,
                            fontWeight:
                                _viewModel.transactionType == 'debit'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              _viewModel.setTransactionType('debit');
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text(CMS.smsParsing['credit_label']!),
                          selected: _viewModel.transactionType == 'credit',
                          selectedColor: AppColors.income.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.income,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.transactionType == 'credit'
                                    ? AppColors.income
                                    : Theme.of(context).colorScheme.onSurface,
                            fontWeight:
                                _viewModel.transactionType == 'credit'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              _viewModel.setTransactionType('credit');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _patternNameController,
                      decoration: InputDecoration(
                        labelText: CMS.smsParsing['pattern_name_label']!,
                        helperText: CMS.smsParsing['pattern_name_helper']!,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText:
                                  CMS.smsParsing['default_category_label']!,
                              border: const OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _viewModel.selectedCategoryId,
                                isDense: true,
                                items:
                                    _viewModel.categories.map((cat) {
                                      return DropdownMenuItem<int>(
                                        value: cat['id'],
                                        child: Text(cat['name']),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _viewModel.setSelectedCategoryId(val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                            size: 30,
                          ),
                          onPressed: _addNewCategory,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed:
                          _viewModel.isLoading ? null : _savePatternAndContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade600,
                      ),
                      child:
                          _viewModel.isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                CMS.smsParsing['save_pattern_btn']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
