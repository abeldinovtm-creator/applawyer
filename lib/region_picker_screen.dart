import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'region_data.dart';
import 'region_translations.dart';

class RegionPickerScreen extends StatefulWidget {
  final String? selectedRegion;

  const RegionPickerScreen({Key? key, this.selectedRegion}) : super(key: key);

  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  String? _selectedOblast;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<String> _filteredOblasts(String lang) {
    if (_searchQuery.isEmpty) return kKazakhstanRegions.keys.toList();
    final q = _searchQuery.toLowerCase();
    return kKazakhstanRegions.keys
        .where((oblast) {
          if (oblast.toLowerCase().contains(q)) return true;
          if (translateRegion(oblast, lang).toLowerCase().contains(q)) return true;
          final cities = kKazakhstanRegions[oblast] ?? [];
          return cities.any((c) =>
              c.toLowerCase().contains(q) ||
              translateRegion(c, lang).toLowerCase().contains(q));
        })
        .toList();
  }

  List<String> _filteredCities(String lang) {
    if (_selectedOblast == null) return [];
    final cities = kKazakhstanRegions[_selectedOblast] ?? [];
    if (_searchQuery.isEmpty) return cities;
    return cities.where((c) =>
        c.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        translateRegion(c, lang).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _selectRegion(String region) {
    Navigator.pop(context, region);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final oblasts = _filteredOblasts(lang);
    final cities = _filteredCities(lang);
    final isShowingCities = _selectedOblast != null && kKazakhstanRegions[_selectedOblast]!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedOblast != null
              ? translateRegion(_selectedOblast!, lang)
              : 'region_picker.title'.tr(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedOblast != null) {
              setState(() => _selectedOblast = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'Все регионы'),
            child: Text(
              'region_picker.reset'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== ПОИСК =====
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'region_picker.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ===== ОНЛАЙН ВАРИАНТ =====
          if (_selectedOblast == null && _searchQuery.isEmpty)
            InkWell(
              onTap: () => _selectRegion('Онлайн (любой регион)'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.public, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'region_picker.online'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // ===== ЗАГОЛОВОК СПИСКА =====
          if (!isShowingCities || _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'region_picker.all_regions'.tr(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            ),

          // ===== СПИСОК =====
          Expanded(
            child: ListView.separated(
              itemCount: isShowingCities && _searchQuery.isEmpty
                  ? cities.length
                  : oblasts.where((o) => o != 'Онлайн (любой регион)' && o != 'Все регионы').length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                if (isShowingCities && _searchQuery.isEmpty) {
                  final city = cities[index];
                  return ListTile(
                    title: Text(translateRegion(city, lang), style: const TextStyle(fontSize: 16)),
                    trailing: widget.selectedRegion == city
                        ? const Icon(Icons.check, color: Colors.red)
                        : null,
                    onTap: () => _selectRegion(city),
                  );
                } else {
                  final filteredOblasts = oblasts
                      .where((o) => o != 'Онлайн (любой регион)' && o != 'Все регионы')
                      .toList();
                  final oblast = filteredOblasts[index];
                  final hasCities = (kKazakhstanRegions[oblast] ?? []).isNotEmpty;

                  return ListTile(
                    title: Text(translateRegion(oblast, lang), style: const TextStyle(fontSize: 16)),
                    trailing: hasCities && _searchQuery.isEmpty
                        ? const Icon(Icons.chevron_right, color: Colors.grey)
                        : widget.selectedRegion == oblast
                            ? const Icon(Icons.check, color: Colors.red)
                            : null,
                    onTap: () {
                      if (hasCities && _searchQuery.isEmpty) {
                        setState(() => _selectedOblast = oblast);
                      } else {
                        _selectRegion(oblast);
                      }
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
