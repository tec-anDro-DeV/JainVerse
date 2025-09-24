import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/CountryModel.dart';

class CountryDropdownWithSearch extends StatefulWidget {
  final Country? value;
  final Function(Country?) onChanged;
  final List<Country> countries;
  final bool enabled;
  final String hintText;

  const CountryDropdownWithSearch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.countries,
    this.enabled = true,
    this.hintText = 'Select Country',
  });

  @override
  State<CountryDropdownWithSearch> createState() =>
      _CountryDropdownWithSearchState();
}

class _CountryDropdownWithSearchState extends State<CountryDropdownWithSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Country> _filteredCountries = [];
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countries;
    _searchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterCountries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCountries =
          widget.countries.where((country) {
            return country.nicename.toLowerCase().contains(query) ||
                country.name.toLowerCase().contains(query) ||
                country.iso.toLowerCase().contains(query);
          }).toList();
    });
  }

  void _openDropdown() {
    if (!widget.enabled) return;

    setState(() {
      _isDropdownOpen = true;
      _searchController.clear();
      _filteredCountries = widget.countries;
    });

    _showCountryDialog();
  }

  void _showCountryDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                width: MediaQuery.of(context).size.width * 0.9,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Country',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _isDropdownOpen = false;
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey.shade600,
                            size: 24.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Search Field
                    Container(
                      height: 50.h,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16.sp,
                            fontFamily: 'Poppins',
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setDialogState(() {
                                        _filteredCountries = widget.countries;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade600,
                                      size: 20.sp,
                                    ),
                                  )
                                  : null,
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            _filterCountries();
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Results Count
                    if (_searchController.text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_filteredCountries.length} result${_filteredCountries.length != 1 ? 's' : ''} found',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                    // Country List
                    Expanded(
                      child:
                          _filteredCountries.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48.sp,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No countries found',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'Try adjusting your search',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.grey.shade500,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: _filteredCountries.length,
                                itemBuilder: (context, index) {
                                  final country = _filteredCountries[index];
                                  final isSelected =
                                      widget.value?.id == country.id;

                                  return InkWell(
                                    onTap: () {
                                      widget.onChanged(country);
                                      Navigator.of(context).pop();
                                      setState(() {
                                        _isDropdownOpen = false;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 12.h,
                                      ),
                                      margin: EdgeInsets.only(bottom: 2.h),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? Colors.blue.shade50
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Flag placeholder (you can replace with actual flag widget)
                                          Container(
                                            width: 24.w,
                                            height: 16.h,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(2.r),
                                            ),
                                            child: Center(
                                              child: Text(
                                                country.iso,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  country.nicename,
                                                  style: TextStyle(
                                                    fontSize: 16.sp,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                    color:
                                                        isSelected
                                                            ? Colors
                                                                .blue
                                                                .shade700
                                                            : Colors.black87,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                if (country.phonecode > 0)
                                                  Text(
                                                    '+${country.phonecode}',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.blue.shade600,
                                              size: 20.sp,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _isDropdownOpen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openDropdown,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: widget.enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color:
                _isDropdownOpen ? Colors.blue.shade400 : Colors.grey.shade300,
            width: _isDropdownOpen ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.public, color: Colors.grey.shade600, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child:
                  widget.value != null
                      ? Row(
                        children: [
                          // Flag placeholder
                          Container(
                            width: 20.w,
                            height: 14.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Center(
                              child: Text(
                                widget.value!.iso,
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              widget.value!.nicename,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                      : Text(
                        widget.hintText,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade500,
                          fontFamily: 'Poppins',
                        ),
                      ),
            ),
            Icon(
              _isDropdownOpen
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey.shade600,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}
