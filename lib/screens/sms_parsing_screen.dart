import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../utils/cms.dart';
import '../viewmodels/sms_parsing_view_model.dart';
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
            title: Text(CMS.sms_parsing['new_category_title']!),
            content: TextField(
              controller: catController,
              decoration: InputDecoration(
                hintText: CMS.sms_parsing['category_hint']!,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (catController.text.isNotEmpty) {
                    await _viewModel.addNewCategory(catController.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add"),
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
            SnackBar(content: Text(CMS.sms_parsing['success_message']!)),
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
      appBar: AppBar(title: Text(CMS.sms_parsing['title']!)),
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
                    CMS.sms_parsing['step_1_title']!,
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

                  // 2. Body Tokens (Visual Selection)
                  Text(
                    CMS.sms_parsing['step_2_title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CMS.sms_parsing['step_2_subtitle']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 8,
                      children: List.generate(_viewModel.bodyTokens.length, (
                        index,
                      ) {
                        Color bgColor = Colors.transparent;
                        Color textColor = Colors.black87;
                        FontWeight fontWeight = FontWeight.normal;

                        if (index == _viewModel.selectedAmountIndex) {
                          bgColor = Colors.green;
                          textColor = Colors.white;
                          fontWeight = FontWeight.bold;
                        } else if (_viewModel.prefixStart != null &&
                            _viewModel.prefixEnd != null &&
                            index >= _viewModel.prefixStart! &&
                            index <= _viewModel.prefixEnd!) {
                          bgColor = Colors.blue;
                          textColor = Colors.white;
                          fontWeight = FontWeight.bold;
                        } else if (_viewModel.suffixStart != null &&
                            _viewModel.suffixEnd != null &&
                            index >= _viewModel.suffixStart! &&
                            index <= _viewModel.suffixEnd!) {
                          bgColor = Colors.blue;
                          textColor = Colors.white;
                          fontWeight = FontWeight.bold;
                        } else if (_viewModel.prefixEnd != null &&
                            _viewModel.selectedAmountIndex != null &&
                            index > _viewModel.prefixEnd! &&
                            index < _viewModel.selectedAmountIndex!) {
                          bgColor = Colors.blue.shade50;
                        } else if (_viewModel.suffixStart != null &&
                            _viewModel.selectedAmountIndex != null &&
                            index > _viewModel.selectedAmountIndex! &&
                            index < _viewModel.suffixStart!) {
                          bgColor = Colors.blue.shade50;
                        }

                        return InkWell(
                          onTap: () => _viewModel.handleTokenTap(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  (bgColor == Colors.transparent)
                                      ? Border.all(color: Colors.grey.shade300)
                                      : null,
                            ),
                            child: Text(
                              _viewModel.bodyTokens[index],
                              style: TextStyle(
                                color: textColor,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 8),
                  if (_viewModel.generatedRegex.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade200,
                      child: Text(
                        "${CMS.sms_parsing['regex_preview']!}${_viewModel.generatedRegex}",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  if (_viewModel.selectedAmountIndex != null) ...[
                    Text(
                      CMS.sms_parsing['step_3_title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(CMS.sms_parsing['debit_label']!),
                          selected: _viewModel.transactionType == 'debit',
                          selectedColor: Colors.red.shade100,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.transactionType == 'debit'
                                    ? Colors.red
                                    : Colors.black,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              _viewModel.setTransactionType('debit');
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text(CMS.sms_parsing['credit_label']!),
                          selected: _viewModel.transactionType == 'credit',
                          selectedColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.transactionType == 'credit'
                                    ? Colors.green
                                    : Colors.black,
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
                        labelText: CMS.sms_parsing['pattern_name_label']!,
                        helperText: CMS.sms_parsing['pattern_name_helper']!,
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
                                  CMS.sms_parsing['default_category_label']!,
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
                                CMS.sms_parsing['save_pattern_btn']!,
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
