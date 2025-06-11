import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

import '../../../../core/services/geocoding_service.dart';

class LocationSearchBar extends StatefulWidget {
  final Function(double longitude, double latitude, String placeName)? onLocationSelected;
  final double? userLongitude;
  final double? userLatitude;

  const LocationSearchBar({
    super.key,
    this.onLocationSelected,
    this.userLongitude,
    this.userLatitude,
  });

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<AddressSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Délai pour permettre la sélection d'une suggestion
      Future.delayed(Duration(milliseconds: 200), () {
        _removeOverlay();
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await GeocodingService.searchAddress(
        value,
        longitude: widget.userLongitude,
        latitude: widget.userLatitude,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 5,
        width: size.width,
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  spreadRadius: 2,
                  blurRadius: 30,
                  offset: Offset(0, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SquircleContainer(
                            radius: 20,
                            padding: EdgeInsets.all(8),
                            color: Colors.grey.shade100,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedLocation01,
                              size: 25,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          12.w,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.placeName.split(',').first,
                                  style: context.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (suggestion.placeName.contains(',')) ...[
                                  2.h,
                                  Text(
                                    suggestion.placeName.split(',').skip(1).join(',').trim(),
                                    style: context.bodySmall?.copyWith(
                                      fontSize: 14,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    _searchController.text = suggestion.placeName.split(',').first;
    _removeOverlay();
    _focusNode.unfocus();
    
    widget.onLocationSelected?.call(
      suggestion.center[0],
      suggestion.center[1],
      suggestion.placeName,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _suggestions = [];
    _removeOverlay();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            spreadRadius: 2,
            blurRadius: 30,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.solidRoundedSearch01,
            size: 22,
            color: Colors.white38,
          ),
          12.w,
          Expanded(
            child: TextFormField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              style: context.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              // onTapOutside: (event) {
              //   FocusScope.of(context).unfocus();
              // },
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Entrer une destination",
                hintStyle: context.bodySmall?.copyWith(
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                  fontSize: 17,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (_isLoading) ...[
            8.w,
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ] else if (_searchController.text.isNotEmpty) ...[
            8.w,
            GestureDetector(
              onTap: _clearSearch,
              child: HugeIcon(
                icon: HugeIcons.solidRoundedCancelCircle,
                size: 25,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}