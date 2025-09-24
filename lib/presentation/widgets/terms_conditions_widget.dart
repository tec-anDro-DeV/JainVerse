import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class TermsAndConditionsWidget extends StatelessWidget {
  final bool isChecked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTermsTap;

  const TermsAndConditionsWidget({
    super.key,
    required this.isChecked,
    required this.onChanged,
    required this.onTermsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 2),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            height: 39,
            width: MediaQuery.of(context).size.width - 25,
            child: CheckboxListTile(
              tileColor: appColors().colorText,
              selectedTileColor: appColors().colorText,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I\'ve read and accept the',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.6,
                  color: appColors().colorText,
                ),
              ),
              value: isChecked,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: appColors().primaryColorApp,
              checkColor: Colors.white,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onTermsTap,
                child: Text(
                  "Terms of use",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.5,
                    color: appColors().primaryColorApp,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
