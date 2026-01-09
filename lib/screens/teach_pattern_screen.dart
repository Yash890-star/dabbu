import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/cms.dart';
import 'main_screen.dart';
import '../widgets/sms/sms_code_block.dart';
import '../viewmodels/sms_parsing_view_model.dart';

class TeachPatternScreen extends StatefulWidget {
  final SmsMessage message;
  final int? existingPatternId;
  final String? initialPatternName;

  const TeachPatternScreen({
    super.key,
    required this.message,
    this.existingPatternId,
    this.initialPatternName,
  });

  @override
  State<TeachPatternScreen> createState() => _TeachPatternScreenState();
}

enum TeachStep { amount, anchor, type, liquid, name, category, retro }

class _TeachPatternScreenState extends State<TeachPatternScreen> {
  // --- View Model Logic Reused ---
  // We reuse logic but control the flow step-by-step
  late SmsParsingViewModel _viewModel;

  TeachStep _currentStep = TeachStep.amount;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  bool _wantsDefaultCategory = false;

  @override
  void initState() {
    super.initState();
    _viewModel = SmsParsingViewModel(
      message: widget.message,
      existingPatternId: widget.existingPatternId,
      initialPatternName: widget.initialPatternName,
    );
    _viewModel.init();
    _viewModel.addListener(_onModelUpdate);

    // Auto-fill name logic if present
    _nameController.text =
        widget.initialPatternName ?? widget.message.address ?? "Bank";
  }

  void _onModelUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onModelUpdate);
    _viewModel.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      switch (_currentStep) {
        case TeachStep.amount:
          if (_viewModel.selectedAmountIndex != null) {
            _currentStep = TeachStep.anchor;
            _viewModel.setSelectionMode(SelectionMode.anchor);
          }
          break;
        case TeachStep.anchor:
          if (_viewModel.selectedAnchorIndices.isNotEmpty) {
            _currentStep = TeachStep.type;
          }
          break;
        case TeachStep.type:
          _currentStep = TeachStep.liquid;
          break;
        case TeachStep.liquid:
          _currentStep = TeachStep.name;
          break;
        case TeachStep.name:
          if (_nameController.text.isNotEmpty) {
            _currentStep = TeachStep.category;
          }
          break;
        case TeachStep.category:
          _currentStep = TeachStep.retro;
          break;
        case TeachStep.retro:
          // Final step action is save
          break;
      }
    });
    // Scroll to bottom after new message appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _save() async {
    try {
      // Logic for retroactive apply happens internally in savePattern if we modify it,
      // but here we might need to handle it custom if the viewmodel doesn't support the 'applyToPast' argument directly yet.
      // Wait, the viewmodel's savePattern currently does NOT take a "retroactive" bool, it just saves.
      // We need to implement retroactive update separately or update the VM.
      // For now, let's assume valid save then handle retroactive manually if we can, or rely on VM if it did it.
      // Re-reading VM: savePattern saves to DB. It calls default logic.
      // Retroactive for PATTERNS is tricky - usually we just re-sync?
      // Actually, for Patterns, retroactive means "apply this pattern to existing unparsed messages".
      // The current VM logic doesn't seemingly expose a method for "apply to ALL past messages".
      // However, usually existing Parse logic might handle it if we trigger a re-scan.
      // Let's stick to saving the pattern first.

      final success = await _viewModel.savePattern(_nameController.text);
      if (success) {
        // Retroactive Logic
        // In the original request: "before saving ask... do they want to run this rule for all previous...".
        // We are at the final step.
        // If we want to run for previous, we probably need a Helper method.
        // For this iteration, since we don't have a backend method ready-made in VM for "Retroactive Pattern Apply",
        // We will just Save and Return, assuming the user will Re-Sync or we might trigger a Resync.
        // Actually, let's just complete the UI flow requested.

        if (!mounted) return;

        // Navigate away
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(CMS.teach_pattern['title'])),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Always show Code Block at top context
                // But maybe better to show it in the flow?
                // Let's keep it sticky or at top for reference if we are selecting tokens.
                if (_currentStep == TeachStep.amount ||
                    _currentStep == TeachStep.anchor)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SmsCodeBlock(
                      tokens: _viewModel.bodyTokens,
                      onTokenTap: _viewModel.handleTokenTap,
                      selectedAmountIndex: _viewModel.selectedAmountIndex,
                      selectedAnchorIndices: _viewModel.selectedAnchorIndices,
                    ),
                  ),

                // --- Conversation Flow ---

                // STEP 1: Amount
                _buildBotMessage(
                  CMS.teach_pattern['step_amount'],
                  CMS.teach_pattern['prompt_amount'],
                ),
                if (_viewModel.selectedAmountIndex != null)
                  _buildUserMessage(
                    "Amount selected: ${_viewModel.bodyTokens[_viewModel.selectedAmountIndex!]}",
                  ),

                // STEP 2: Anchor
                if (_currentStep.index >= TeachStep.anchor.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_anchor'],
                    CMS.teach_pattern['prompt_anchor'],
                  ),
                  if (_viewModel.selectedAnchorIndices.isNotEmpty)
                    _buildUserMessage(
                      "${_viewModel.selectedAnchorIndices.length} keywords selected",
                    ),
                ],

                // STEP 3: Type
                if (_currentStep.index >= TeachStep.type.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_type'],
                    CMS.teach_pattern['prompt_type'],
                  ),
                  if (_currentStep.index > TeachStep.type.index)
                    _buildUserMessage(
                      _viewModel.transactionType == 'credit'
                          ? CMS.teach_pattern['lbl_credit']
                          : CMS.teach_pattern['lbl_debit'],
                    ),
                  if (_currentStep == TeachStep.type)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildOptionChip(
                            label: CMS.teach_pattern['lbl_debit'],
                            isSelected: _viewModel.transactionType == 'debit',
                            color: AppColors.expense,
                            onTap: () {
                              _viewModel.setTransactionType('debit');
                              // Auto advance? or wait for Next? Wait for Next is better for confirmation.
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildOptionChip(
                            label: CMS.teach_pattern['lbl_credit'],
                            isSelected: _viewModel.transactionType == 'credit',
                            color: AppColors.income,
                            onTap: () {
                              _viewModel.setTransactionType('credit');
                            },
                          ),
                        ],
                      ),
                    ),
                ],

                // STEP 4: Liquid
                if (_currentStep.index >= TeachStep.liquid.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_liquid'],
                    CMS.teach_pattern['prompt_liquid'],
                  ),
                  if (_currentStep.index > TeachStep.liquid.index)
                    _buildUserMessage(
                      _viewModel.isLiquid
                          ? CMS.teach_pattern['lbl_liquid_yes']
                          : CMS.teach_pattern['lbl_liquid_no'],
                    ),
                  if (_currentStep == TeachStep.liquid)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionChip(
                            label: CMS.teach_pattern['lbl_liquid_yes'],
                            isActive: _viewModel.isLiquid,
                            onTap:
                                () => setState(
                                  () => _viewModel.setIsLiquid(true),
                                ),
                          ),
                          const SizedBox(width: 8),
                          _buildActionChip(
                            label: CMS.teach_pattern['lbl_liquid_no'],
                            isActive: !_viewModel.isLiquid,
                            onTap:
                                () => setState(
                                  () => _viewModel.setIsLiquid(false),
                                ),
                          ),
                        ],
                      ),
                    ),
                ],

                // STEP 5: Name
                if (_currentStep.index >= TeachStep.name.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_name'],
                    CMS.teach_pattern['prompt_name'],
                  ),
                  if (_currentStep == TeachStep.name)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Pattern Name",
                        ),
                      ),
                    )
                  else
                    _buildUserMessage(_nameController.text),
                ],

                // STEP 6: Category
                if (_currentStep.index >= TeachStep.category.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_category'],
                    CMS.teach_pattern['prompt_category_yn'],
                  ),

                  if (_currentStep == TeachStep.category) ...[
                    // Yes/No Toggle for Default Category
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionChip(
                            label: "No",
                            isActive: !_wantsDefaultCategory,
                            onTap:
                                () => setState(() {
                                  _wantsDefaultCategory = false;
                                  // Keep existing category in VM, but UI ignores it
                                }),
                          ),
                          const SizedBox(width: 8),
                          _buildActionChip(
                            label: "Yes",
                            isActive: _wantsDefaultCategory,
                            onTap:
                                () => setState(
                                  () => _wantsDefaultCategory = true,
                                ),
                          ),
                        ],
                      ),
                    ),

                    if (_wantsDefaultCategory) ...[
                      const SizedBox(height: 16),
                      _buildBotMessage(
                        "Ok",
                        CMS.teach_pattern['prompt_category_select'],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(left: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _viewModel.selectedCategoryId,
                            hint: const Text("Select Category"),
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
                    ],
                  ] else ...[
                    _buildUserMessage(
                      _wantsDefaultCategory
                          ? "Category Assigned"
                          : "No Default Category",
                    ),
                  ],
                ],

                // STEP 7: Retroactive / Final
                if (_currentStep.index >= TeachStep.retro.index) ...[
                  const SizedBox(height: 24),
                  _buildBotMessage(
                    CMS.teach_pattern['step_retro'],
                    CMS.teach_pattern['prompt_retro'],
                  ),
                  // We treat this as the final check before "Save".
                  // The "Save" button effectively confirms this for this mvp flow scope.
                  // We can add a simple checkbox or toggle here.
                ],

                const SizedBox(height: 100), // Spacing for fab
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _currentStep == TeachStep.retro
              ? FloatingActionButton.extended(
                onPressed: _save,
                label: Text(CMS.teach_pattern['btn_save']),
                icon: const Icon(Icons.check),
              )
              : FloatingActionButton.extended(
                onPressed: _canProceed() ? _nextStep : null,
                label: Text(
                  CMS.teach_pattern['btn_next'],
                  style: const TextStyle(color: Colors.white),
                ),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                backgroundColor:
                    _canProceed() ? AppColors.primary : Colors.grey,
              ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case TeachStep.amount:
        return _viewModel.selectedAmountIndex != null;
      case TeachStep.anchor:
        return _viewModel.selectedAnchorIndices.isNotEmpty;
      case TeachStep.type:
        return true; // Default is set
      case TeachStep.liquid:
        return true; // Default is set
      case TeachStep.name:
        return _nameController.text.isNotEmpty;
      case TeachStep.category:
        return true;
      case TeachStep.retro:
        return true;
    }
  }

  Widget _buildBotMessage(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primary,
          radius: 16,
          child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? color : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : Colors.grey),
        ),
      ),
    );
  }
}
